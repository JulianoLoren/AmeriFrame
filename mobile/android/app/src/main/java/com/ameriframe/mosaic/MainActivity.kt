package com.ameriframe.mosaic

import android.content.ClipData
import android.content.Intent
import android.graphics.Region
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { MosaicEditor() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MosaicEditor(model: EditorModel = viewModel()) {
    val context = LocalContext.current
    val preferences = remember { context.getSharedPreferences("mosaic", 0) }
    var language by rememberSaveable { mutableStateOf(preferences.getString("language", "vi") ?: "vi") }
    var theme by rememberSaveable { mutableStateOf(preferences.getString("theme", "system") ?: "system") }
    val vi = language == "vi"
    fun t(v: String, e: String) = if (vi) v else e
    var png by rememberSaveable { mutableStateOf(true) }
    var category by rememberSaveable { mutableStateOf("all") }
    var customWidth by rememberSaveable { mutableStateOf("1") }
    var customHeight by rememberSaveable { mutableStateOf("1") }
    var colorHex by rememberSaveable { mutableStateOf("FFFFFF") }
    var saving by rememberSaveable { mutableStateOf(false) }
    var copying by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val collage = model.collage
    val selectedPhoto = collage.photos.getOrNull(model.selected)
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(24)) { model.load(context.applicationContext, it, vi) }
    val savePicker = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(if (png) "image/png" else "image/jpeg")) { uri ->
        val file = model.pendingSave; model.pendingSave = null
        if (uri != null && file != null) {
            copying = true
            scope.launch {
                try {
                    withContext(Dispatchers.IO) {
                        requireNotNull(context.contentResolver.openOutputStream(uri)).use { out -> file.inputStream().use { it.copyTo(out) } }
                    }
                    android.widget.Toast.makeText(context, t("Đã lưu ảnh", "Image saved"), android.widget.Toast.LENGTH_SHORT).show()
                } catch (_: Exception) { model.error = t("Không thể lưu ảnh.", "Could not save image.") }
                finally { copying = false }
            }
        }
    }
    LaunchedEffect(model.exportFile) {
        val file = model.exportFile ?: return@LaunchedEffect
        model.exportFile = null
        try {
            if (saving) {
                model.pendingSave = file; savePicker.launch(file.name)
            } else {
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.exports", file)
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = if (file.extension == "png") "image/png" else "image/jpeg"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    clipData = ClipData.newRawUri("Mosaic", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                context.startActivity(Intent.createChooser(intent, t("Chia sẻ ảnh", "Share image")))
            }
        } catch (_: Exception) { model.error = t("Không thể mở trình chia sẻ/lưu ảnh.", "Could not open share/save dialog.") }
    }
    val dark = when (theme) { "dark" -> true; "light" -> false; else -> isSystemInDarkTheme() }
    MaterialTheme(colorScheme = if (dark) darkColorScheme() else lightColorScheme()) {
        Scaffold(topBar = {
            TopAppBar(title = { Text("Mosaic", fontWeight = FontWeight.Bold) }, actions = {
                TextButton(onClick = { language = if (vi) "en" else "vi"; preferences.edit().putString("language", language).apply() }) { Text(if (vi) "EN" else "VI") }
                var settings by remember { mutableStateOf(false) }
                Box {
                    TextButton(onClick = { settings = true }) { Text(t("Giao diện", "Theme")) }
                    DropdownMenu(expanded = settings, onDismissRequest = { settings = false }) {
                        listOf("system" to t("Hệ thống", "System"), "light" to t("Sáng", "Light"), "dark" to t("Tối", "Dark")).forEach { (id,label) ->
                            DropdownMenuItem(text = { Text(label) }, onClick = { theme = id; preferences.edit().putString("theme", id).apply(); settings = false })
                        }
                    }
                }
            })
        }) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally) {
                    Column(Modifier.widthIn(max = 760.dp).fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        Text(t("Ghép khoảnh khắc của bạn.", "Bring your moments together."), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                        Text(t("Ảnh chỉ ở trên thiết bị · Không watermark", "On-device processing · No watermark"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(t("BẢN XEM TRƯỚC", "LIVE PREVIEW"), style = MaterialTheme.typography.labelMedium)
                            Text("${collage.outputWidth} × ${collage.outputHeight}", style = MaterialTheme.typography.labelMedium)
                        }
                        if (collage.photos.isEmpty()) {
                            Column(Modifier.fillMaxWidth().height(250.dp).background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(20.dp)).padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(t("Mọi câu chuyện bắt đầu bằng một bức ảnh.", "Every story starts with a photo."), style = MaterialTheme.typography.titleLarge)
                                Spacer(Modifier.height(20.dp))
                                Button(onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text(t("Thêm ảnh", "Add photos")) }
                            }
                        } else {
                            Preview(model, t("Khung ghép ảnh. Chọn ảnh bên dưới để tinh chỉnh.", "Photo collage. Select a photo below to adjust."))
                            Text(t("Chạm để chọn · Kéo để căn ảnh · Chụm hai ngón để zoom", "Tap to select · Drag to crop · Pinch to zoom"), style = MaterialTheme.typography.bodySmall)
                        }
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("${t("Ảnh của bạn", "Your photos")} (${collage.photos.size}/24)", style = MaterialTheme.typography.titleMedium)
                            Button(enabled = !model.busy && collage.photos.size < 24, onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text(t("Thêm ảnh", "Add photos")) }
                        }
                        Text(t("Tối đa 30 MB/ảnh · Phiên chỉnh sửa không lưu sau khi đóng app", "Up to 30 MB/photo · Editing session is not saved after closing the app"), style = MaterialTheme.typography.bodySmall)
                        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            collage.photos.forEachIndexed { index, photo ->
                                Image(photo.bitmap.asImageBitmap(), "${t("Ảnh", "Photo")} ${index+1}", contentScale = ContentScale.Crop,
                                    modifier = Modifier.size(68.dp).clip(RoundedCornerShape(8.dp)).border(if (index == model.selected) 3.dp else 0.dp, MaterialTheme.colorScheme.primary, RoundedCornerShape(8.dp))
                                        .clickable { if (!model.busy) model.selected = index }.semantics { selected = index == model.selected })
                            }
                        }
                        if (selectedPhoto != null) {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(onClick = { model.move(-1) }, enabled = model.selected > 0) { Text(t("Trước", "Previous")) }
                                OutlinedButton(onClick = { model.move(1) }, enabled = model.selected < collage.photos.lastIndex) { Text(t("Sau", "Next")) }
                                TextButton(onClick = { model.remove() }) { Text(t("Xóa ảnh", "Remove"), color = MaterialTheme.colorScheme.error) }
                            }
                        }
                        SectionTitle(t("Tỷ lệ", "Ratio"))
                        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("1:1" to 1.0, "4:5" to .8, "3:2" to 1.5, "9:16" to 9.0/16, "16:9" to 16.0/9).forEach { (label, ratio) ->
                                FilterChip(selected = collage.ratio == ratio, onClick = { model.resetCrops(collage.copy(ratio = ratio)) }, label = { Text(label) })
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(customWidth, { customWidth = it }, label = { Text(t("Rộng", "Width")) }, singleLine = true, modifier = Modifier.weight(1f))
                            OutlinedTextField(customHeight, { customHeight = it }, label = { Text(t("Cao", "Height")) }, singleLine = true, modifier = Modifier.weight(1f))
                            TextButton(onClick = {
                                val w = customWidth.replace(',', '.').toDoubleOrNull(); val h = customHeight.replace(',', '.').toDoubleOrNull()
                                if (w != null && h != null && w in 1.0..100.0 && h in 1.0..100.0 && w/h in .2..5.0) model.resetCrops(collage.copy(ratio = w/h))
                                else model.error = t("Nhập hai số 1–100, tỷ lệ từ 1:5 đến 5:1.", "Enter values from 1–100, with a ratio from 1:5 to 5:1.")
                            }) { Text(t("Áp dụng", "Apply")) }
                        }
                        SectionTitle(t("Bố cục", "Layout"))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("all" to t("Tất cả", "All"), "classic" to t("Cổ điển", "Classic"), "creative" to t("Sáng tạo", "Creative")).forEach { (id,label) ->
                                FilterChip(selected = category == id, onClick = { category = id }, label = { Text(label) })
                            }
                        }
                        NativeGeometry.layouts.filter { category == "all" || it.category == category }.chunked(3).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                row.forEach { layout ->
                                    LayoutTile(layout, collage, vi, Modifier.weight(1f)) { model.resetCrops(collage.copy(layout = layout.id)) }
                                }
                                repeat(3-row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                        SectionTitle(t("Tinh chỉnh", "Adjust"))
                        if (selectedPhoto != null) {
                            Text("${t("Ảnh", "Photo")} ${model.selected + 1} · ${(selectedPhoto.zoom * 100).toInt()}%")
                            Slider(selectedPhoto.zoom, { value -> model.crop { it.copy(zoom = value) } }, valueRange = 1f..4f, modifier = Modifier.semantics { contentDescription = t("Zoom ảnh", "Photo zoom") })
                            Text(t("Vị trí ngang", "Horizontal position"))
                            Slider(selectedPhoto.x, { value -> model.crop { it.copy(x = value) } }, modifier = Modifier.semantics { contentDescription = t("Vị trí ngang", "Horizontal position") })
                            Text(t("Vị trí dọc", "Vertical position"))
                            Slider(selectedPhoto.y, { value -> model.crop { it.copy(y = value) } }, modifier = Modifier.semantics { contentDescription = t("Vị trí dọc", "Vertical position") })
                            TextButton(onClick = { model.crop { it.copy(x = .5f, y = .5f, zoom = 1f) } }) { Text(t("Đặt lại ảnh", "Reset photo")) }
                        }
                        Text("${t("Độ dày khung", "Frame thickness")}: ${collage.border.toInt()} px")
                        Slider(collage.border, { model.update(collage.copy(border = it)) }, valueRange = 0f..120f, modifier = Modifier.semantics { contentDescription = t("Độ dày khung", "Frame thickness") })
                        Text(t("Khung tự giảm độ dày khi cần để giữ đủ ảnh.", "Thickness is reduced when needed to keep all photos visible."), style = MaterialTheme.typography.bodySmall)
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(colorHex, { colorHex = it.take(7) }, label = { Text(t("Màu khung (HEX)", "Frame color (HEX)")) }, modifier = Modifier.weight(1f), singleLine = true)
                            TextButton(onClick = {
                                val hex = colorHex.removePrefix("#")
                                if (Regex("[0-9a-fA-F]{6}").matches(hex)) model.update(collage.copy(color = android.graphics.Color.parseColor("#$hex")))
                                else model.error = t("Nhập 6 ký tự HEX, ví dụ FFFFFF.", "Enter 6 HEX digits, e.g. FFFFFF.")
                            }) { Text(t("Áp dụng", "Apply")) }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            listOf("FFFFFF", "18181B", "F6F1E4", "D79E56", "748D7F", "AF7262").forEach { hex ->
                                Box(Modifier.size(36.dp).clip(RoundedCornerShape(18.dp)).background(Color(android.graphics.Color.parseColor("#$hex"))).border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(18.dp)).clickable { colorHex = hex; model.update(collage.copy(color = android.graphics.Color.parseColor("#$hex"))) }.semantics { contentDescription = "${t("Màu", "Color")} #$hex" })
                            }
                        }
                        SectionTitle(t("Xuất ảnh", "Export"))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChip(png, { png = true }, label = { Text("PNG") }); FilterChip(!png, { png = false }, label = { Text("JPG") })
                        }
                        Button(onClick = { saving = false; model.export(context.applicationContext, png, vi) }, enabled = collage.photos.isNotEmpty() && !model.busy, modifier = Modifier.fillMaxWidth()) { Text(t("Xuất và chia sẻ ảnh 4K", "Export and share 4K image")) }
                        OutlinedButton(onClick = { saving = true; model.export(context.applicationContext, png, vi) }, enabled = collage.photos.isNotEmpty() && !model.busy, modifier = Modifier.fillMaxWidth()) { Text(t("Lưu ảnh vào tệp", "Save image to file")) }
                    }
                }
                if (model.busy || copying) {
                    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .3f)).pointerInput(Unit) { awaitPointerEventScope { while (true) awaitPointerEvent().changes.forEach { it.consume() } } }, contentAlignment = Alignment.Center) {
                        Surface(shape = RoundedCornerShape(16.dp)) { Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) { CircularProgressIndicator(); Text(t("Đang xử lý…", "Processing…")) } }
                    }
                }
            }
        }
        model.error?.let { message -> AlertDialog(onDismissRequest = { model.error = null }, title = { Text(t("Thông báo", "Notice")) }, text = { Text(message) }, confirmButton = { TextButton(onClick = { model.error = null }) { Text("OK") } }) }
    }
}

@Composable
private fun SectionTitle(text: String) { HorizontalDivider(); Text(text, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold) }

@Composable
private fun LayoutTile(layout: Layout, collage: Collage, vi: Boolean, modifier: Modifier, select: () -> Unit) {
    val color = MaterialTheme.colorScheme.onSurface
    Column(modifier.clip(RoundedCornerShape(10.dp)).background(if (collage.layout == layout.id) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainer)
        .clickable(onClick = select).semantics { selected = collage.layout == layout.id }.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        val values = remember(layout.id, collage.photos.size, collage.ratio) {
            NativeGeometry.frame(layout.id, maxOf(4, collage.photos.size), collage.ratio * 100, 100.0, 2.0)
        }
        Canvas(Modifier.fillMaxWidth().height(48.dp)) {
            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                native.save(); native.scale(size.width / (collage.ratio * 100).toFloat(), size.height / 100)
                val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { this.color = android.graphics.Color.argb((color.alpha*255).toInt(), (color.red*255).toInt(), (color.green*255).toInt(), (color.blue*255).toInt()) }
                var offset = 1
                while (offset < values.size) {
                    val count = values[offset++].toInt(); val path = android.graphics.Path()
                    repeat(count) { i -> val x=values[offset++].toFloat(); val y=values[offset++].toFloat(); if(i==0)path.moveTo(x,y) else path.lineTo(x,y) }
                    path.close(); native.drawPath(path,paint)
                }
                native.restore()
            }
        }
        Text(if (vi) layout.vi else layout.en, style = MaterialTheme.typography.labelSmall, maxLines = 1)
    }
}

@Composable
internal fun Preview(model: EditorModel, label: String) {
    val collage = model.collage
    var size by remember { mutableStateOf(IntSize.Zero) }
    val geo = remember(collage.layout, collage.photos.size, collage.ratio, collage.border, size) {
        if (size.width > 0 && size.height > 0) collage.geometry(size.width.toFloat(), size.height.toFloat()) else null
    }
    fun hit(x: Float, y: Float): Int = geo?.cells?.indexOfFirst { cell ->
        val clip = Region(0,0,size.width,size.height)
        Region().apply { setPath(cell.path,clip) }.contains(x.toInt(),y.toInt())
    } ?: -1
    // Crop updates do not restart the gesture; geometry and photo identity changes do.
    Canvas(Modifier.fillMaxWidth().aspectRatio(collage.ratio.toFloat()).onSizeChanged { size = it }.semantics { contentDescription = label }
        .pointerInput(geo, collage.photos.map { it.id }, model.busy) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                val active = hit(down.position.x, down.position.y)
                if (active < 0 || model.busy) return@awaitEachGesture
                model.selected = active
                val id = model.collage.photos[active].id
                down.consume()
                do {
                    val event = awaitPointerEvent()
                    if (event.changes.any { it.isConsumed } || model.busy || model.selected != active) break
                    val current = model.collage
                    val photo = current.photos.getOrNull(active) ?: break
                    if (photo.id != id) break
                    if (event.changes.any { it.pressed && it.previousPressed }) {
                        val anchor = event.calculateCentroid(useCurrent = false)
                        val pan = event.calculatePan()
                        val zoom = event.calculateZoom()
                        model.crop { current.transformed(it, geo!!.cells[active].box, anchor.x, anchor.y, pan.x, pan.y, it.zoom * zoom) }
                    }
                    event.changes.forEach { it.consume() }
                } while (event.changes.any { it.pressed })
            }
        }) {
        geo?.let { geometry -> drawIntoCanvas { collage.draw(it.nativeCanvas, this.size.width, this.size.height, model.selected, geometry) } }
    }
}
