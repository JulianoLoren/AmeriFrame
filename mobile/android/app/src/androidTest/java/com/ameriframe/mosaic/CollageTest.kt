package com.ameriframe.mosaic

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.RectF
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class CollageTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private fun photo(color: Int, width: Int = 240, height: Int = 120) = Photo(Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888).apply { eraseColor(color) })
    @Test fun allLayoutsKeep24CellsAtExtremeRatios() {
        assertEquals(36, NativeGeometry.layouts.size)
        val photos = List(24) { photo(Color.RED) }
        for (layout in NativeGeometry.layouts) for(ratio in listOf(.2, 1.0, 5.0)) {
            val collage = Collage(photos, layout.id, ratio, 120f)
            val geo = collage.geometry(collage.outputWidth.toFloat(),collage.outputHeight.toFloat())
            assertEquals(24,geo.cells.size)
            assertTrue(geo.cells.all { !it.path.isEmpty && it.box.width()>0 && it.box.height()>0 })
        }
    }
    @Test fun cropAlwaysCoversCell() {
        val collage = Collage(); val photo=photo(Color.RED); val box=RectF(23f,41f,153f,461f)
        for(zoom in listOf(1f,2f,4f)) for(x in listOf(0f,.5f,1f)) for(y in listOf(0f,.5f,1f))
            assertTrue(collage.placement(photo.copy(x=x,y=y,zoom=zoom),box).contains(box))
    }
    @Test fun pngAndJpegHave4KDimensionsAndCorrectColors() {
        val collage = Collage(listOf(photo(Color.RED),photo(Color.BLUE)),"columns",16.0/9,0f)
        for(png in listOf(true,false)) {
            val file=collage.export(context,png)
            try {
                val image=BitmapFactory.decodeFile(file.path)
                assertEquals(3840,image.width); assertEquals(2160,image.height)
                val left=image.getPixel(400,1000); val right=image.getPixel(3000,1000)
                assertTrue(Color.red(left)>240 && Color.blue(left)<15)
                assertTrue(Color.blue(right)>240 && Color.red(right)<15)
                image.recycle()
            } finally { file.delete() }
        }
    }
    @Test fun previewAndExportMatchDespiteRoundedPreviewSize() {
        val collage = Collage(listOf(photo(Color.RED),photo(Color.BLUE)), ratio=5.0)
        val preview=collage.geometry(1037f,207f); val full=collage.geometry(collage.outputWidth.toFloat(),collage.outputHeight.toFloat())
        preview.cells.zip(full.cells).forEach { (small,large) ->
            assertEquals(small.box.left/1037,large.box.left/collage.outputWidth,1e-6f)
            assertEquals(small.box.height()/207,large.box.height()/collage.outputHeight,1e-6f)
        }
    }
    @Test fun editorReordersResetsAndRemoves() {
        val model=EditorModel(); val first=photo(Color.RED).copy(zoom=4f,x=0f)
        model.update(Collage(listOf(first,photo(Color.BLUE))))
        model.move(1); assertEquals(1,model.selected); assertEquals(first.id,model.collage.photos[1].id)
        model.move(-1); model.resetCrops(); assertEquals(1f,model.collage.photos[0].zoom,0f)
        model.remove(); assertEquals(1,model.collage.photos.size); assertEquals(0,model.selected)
        model.remove(); assertTrue(model.collage.photos.isEmpty()); model.remove()
    }
    @Test fun decoderEnforcesPixelBudgetAndRejectsInvalidData() {
        val file=File.createTempFile("decoder-test", ".png",context.cacheDir)
        try {
            file.outputStream().use { photo(Color.RED,800,400).bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }
            val image=EditorModel().decode(context,Uri.fromFile(file),80_000.0)
            assertEquals(400,image.width); assertEquals(200,image.height); image.recycle()
            file.writeText("not an image")
            try { EditorModel().decode(context,Uri.fromFile(file),80_000.0); fail("Invalid image was accepted") } catch (_: android.graphics.ImageDecoder.DecodeException) { }
        } finally { file.delete() }
    }
}
