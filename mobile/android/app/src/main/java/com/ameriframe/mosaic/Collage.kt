package com.ameriframe.mosaic

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.io.File
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.*

object NativeGeometry {
    init { System.loadLibrary("mosaic") }
    external fun frame(id: String, count: Int, width: Double, height: Double, gap: Double): DoubleArray
    external fun catalog(): Array<String>
    val layouts: List<Layout> by lazy { catalog().toList().chunked(4).map { Layout(it[0], it[1], it[2], it[3]) } }
}
data class Layout(val id: String, val category: String, val vi: String, val en: String)
data class Photo(val bitmap: Bitmap, val id: String = UUID.randomUUID().toString(), val x: Float = .5f, val y: Float = .5f, val zoom: Float = 1f)
data class Cell(val path: Path, val box: RectF)
data class Geometry(val cells: List<Cell>, val gap: Float)
data class Collage(
    val photos: List<Photo> = emptyList(), val layout: String = "grid", val ratio: Double = 1.0,
    val border: Float = 24f, val color: Int = Color.WHITE
) {
    val outputWidth get() = if (ratio >= 1) 3840 else (3840 * ratio).roundToInt()
    val outputHeight get() = if (ratio >= 1) (3840 / ratio).roundToInt() else 3840
    fun geometry(width: Float, height: Float): Geometry {
        val values = NativeGeometry.frame(layout, max(1, photos.size), outputWidth.toDouble(), outputHeight.toDouble(), border.toDouble())
        val cells = mutableListOf<Cell>(); var offset = 1
        while (offset < values.size) {
            val count = values[offset++].toInt(); val path = Path()
            repeat(count) { i ->
                val x = values[offset++].toFloat() * width / outputWidth; val y = values[offset++].toFloat() * height / outputHeight
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close(); val box = RectF(); path.computeBounds(box, true); cells += Cell(path, box)
        }
        return Geometry(cells, values[0].toFloat() * width / outputWidth)
    }
    fun placement(photo: Photo, box: RectF): RectF {
        val scale = max(box.width() / photo.bitmap.width, box.height() / photo.bitmap.height) * photo.zoom
        val width = photo.bitmap.width * scale; val height = photo.bitmap.height * scale
        val x = box.left - (width - box.width()) * photo.x; val y = box.top - (height - box.height()) * photo.y
        return RectF(x, y, x + width, y + height)
    }
    fun draw(canvas: Canvas, width: Float, height: Float, selected: Int = -1, geometry: Geometry = geometry(width, height)) {
        canvas.drawColor(color)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        geometry.cells.forEachIndexed { index, cell ->
            photos.getOrNull(index)?.let { photo ->
                canvas.save(); canvas.clipPath(cell.path)
                canvas.drawBitmap(photo.bitmap, null, placement(photo, cell.box), paint); canvas.restore()
                if (index == selected) {
                    val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 4f; color = Color.WHITE }
                    canvas.drawPath(cell.path, outline)
                    outline.color = Color.BLACK; outline.strokeWidth = 2f; outline.pathEffect = android.graphics.DashPathEffect(floatArrayOf(6f, 5f), 0f)
                    canvas.drawPath(cell.path, outline)
                }
            }
        }
    }
    fun export(context: Context, png: Boolean): File {
        val bitmap = Bitmap.createBitmap(outputWidth, outputHeight, Bitmap.Config.ARGB_8888)
        try {
            draw(Canvas(bitmap), outputWidth.toFloat(), outputHeight.toFloat())
            val directory = File(context.cacheDir, "exports").apply { mkdirs() }
            directory.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86_400_000 }?.forEach { it.delete() }
            val file = File(directory, "mosaic-${UUID.randomUUID()}.${if (png) "png" else "jpg"}")
            try {
                file.outputStream().use { check(bitmap.compress(if (png) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG, 96, it)) }
            } catch (e: Exception) { file.delete(); throw e }
            return file
        } finally { bitmap.recycle() }
    }
}

class EditorModel : ViewModel() {
    var collage by mutableStateOf(Collage()); private set
    var selected by mutableIntStateOf(0)
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    var exportFile by mutableStateOf<File?>(null)
    fun update(value: Collage) { if (!busy) collage = value }
    fun resetCrops(value: Collage = collage) { update(value.copy(photos = value.photos.map { it.copy(x = .5f, y = .5f, zoom = 1f) })) }
    fun crop(transform: (Photo) -> Photo) { update(collage.copy(photos = collage.photos.mapIndexed { i, p -> if (i == selected) transform(p) else p })) }
    fun remove() {
        if (busy) return
        resetCrops(collage.copy(photos = collage.photos.filterIndexed { i, _ -> i != selected }))
        selected = selected.coerceAtMost(collage.photos.lastIndex).coerceAtLeast(0)
    }
    fun move(delta: Int) {
        val target = selected + delta
        if (busy || target !in collage.photos.indices) return
        val photos = collage.photos.toMutableList(); java.util.Collections.swap(photos, selected, target)
        update(collage.copy(photos = photos)); selected = target
    }
    fun load(context: Context, uris: List<Uri>, vi: Boolean) {
        if (busy || uris.isEmpty()) return
        busy = true
        viewModelScope.launch {
            try {
                val start = collage.photos.size
                val maxPixels = 24_000_000.0 / min(24, start + uris.size)
                for (index in collage.photos.indices) {
                    val photo = collage.photos[index]
                    val bitmap = withContext(Dispatchers.Default) {
                        val pixels = photo.bitmap.width.toDouble() * photo.bitmap.height
                        if (pixels <= maxPixels) photo.bitmap else {
                            val scale = sqrt(maxPixels / pixels)
                            Bitmap.createScaledBitmap(photo.bitmap, max(1, (photo.bitmap.width * scale).toInt()), max(1, (photo.bitmap.height * scale).toInt()), true)
                        }
                    }
                    collage = collage.copy(photos = collage.photos.mapIndexed { i, p -> if (i == index) p.copy(bitmap = bitmap) else p })
                }
                val result = withContext(Dispatchers.IO) {
                    var failed = 0
                    val photos = uris.take(24 - start).mapNotNull { uri ->
                        try { Photo(decode(context, uri, maxPixels)) } catch (_: Exception) { failed++; null }
                    }
                    photos to failed
                }
                collage = collage.copy(photos = (collage.photos + result.first).map { it.copy(x = .5f, y = .5f, zoom = 1f) })
                if (result.first.isNotEmpty()) selected = start
                if (result.second > 0) error = if (vi) "Không đọc được ${result.second} ảnh. Tối đa 30 MB/ảnh." else "Could not read ${result.second} photos. Maximum 30 MB per photo."
            } catch (_: OutOfMemoryError) {
                error = if (vi) "Thiếu bộ nhớ. Hãy xóa bớt ảnh rồi thử lại." else "Not enough memory. Remove some photos and try again."
            } finally { busy = false }
        }
    }
    fun export(context: Context, png: Boolean, vi: Boolean) {
        if (busy || collage.photos.isEmpty()) return
        busy = true; val snapshot = collage
        viewModelScope.launch {
            try { exportFile = withContext(Dispatchers.Default) { snapshot.export(context, png) } }
            catch (_: Exception) { error = if (vi) "Không thể xuất ảnh. Hãy thử lại." else "Could not export. Please try again." }
            catch (_: OutOfMemoryError) { error = if (vi) "Thiếu bộ nhớ để xuất ảnh. Hãy xóa bớt ảnh." else "Not enough memory to export. Remove some photos." }
            finally { busy = false }
        }
    }
    internal fun decode(context: Context, uri: Uri, maxPixels: Double): Bitmap {
        // Copy with a hard byte cap; provider-reported length may be absent or untrustworthy.
        val file = File.createTempFile("mosaic-import-", null, context.cacheDir)
        try {
            context.contentResolver.openInputStream(uri).use { input ->
                requireNotNull(input)
                file.outputStream().use { output ->
                    val buffer = ByteArray(16 * 1024); var total = 0
                    while (true) {
                        val count = input.read(buffer); if (count < 0) break
                        total += count; require(total <= 30 * 1024 * 1024)
                        output.write(buffer, 0, count)
                    }
                    require(total > 0)
                }
            }
            return ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
                val w = info.size.width; val h = info.size.height
                val scale = minOf(1.0, 3840.0 / max(w,h), sqrt(maxPixels / (w.toDouble() * h)))
                decoder.setTargetSize(max(1,(w*scale).toInt()), max(1,(h*scale).toInt()))
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                decoder.setTargetColorSpace(android.graphics.ColorSpace.get(android.graphics.ColorSpace.Named.SRGB))
            }
        } finally { file.delete() }
    }
}
