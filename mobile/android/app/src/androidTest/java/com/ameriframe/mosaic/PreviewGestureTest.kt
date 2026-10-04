package com.ameriframe.mosaic

import android.graphics.Bitmap
import android.graphics.Color
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class PreviewGestureTest {
    @Test fun pinchChangesOnlyTouchedPhotoAndContinuesAsDrag() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val placed = CountDownLatch(1)
        lateinit var model: EditorModel
        var left = 0f; var top = 0f; var width = 0f; var height = 0f
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                model = EditorModel()
                val photos = listOf(Color.RED, Color.BLUE).map { color ->
                    Photo(Bitmap.createBitmap(200, 200, Bitmap.Config.ARGB_8888).apply { eraseColor(color) })
                }
                model.update(Collage(photos, layout = "columns", border = 0f))
                activity.setContent {
                    Box(Modifier.onGloballyPositioned {
                        val position = it.positionInWindow()
                        left = position.x; top = position.y; width = it.size.width.toFloat(); height = it.size.height.toFloat()
                        placed.countDown()
                    }) { Preview(model, "Collage test preview") }
                }
            }
            assertTrue("Preview laid out", placed.await(10, TimeUnit.SECONDS))
            var downTime = SystemClock.uptimeMillis()
            fun touch(action: Int, vararg points: Pair<Float, Float>) {
                val properties = points.indices.map { id -> MotionEvent.PointerProperties().apply { this.id = id; toolType = MotionEvent.TOOL_TYPE_FINGER } }.toTypedArray()
                val coordinates = points.map { (x, y) -> MotionEvent.PointerCoords().apply { this.x = left + width * x; this.y = top + height * y; pressure = 1f; size = 1f } }.toTypedArray()
                val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, points.size, properties, coordinates, 0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0)
                scenario.onActivity { it.dispatchTouchEvent(event) }
                event.recycle(); instrumentation.waitForIdleSync()
            }
            touch(MotionEvent.ACTION_DOWN, .2f to .5f)
            touch(MotionEvent.ACTION_POINTER_DOWN or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT), .2f to .5f, .3f to .5f)
            touch(MotionEvent.ACTION_MOVE, .1f to .5f, .4f to .5f)
            touch(MotionEvent.ACTION_POINTER_UP or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT), .1f to .5f, .4f to .5f)
            touch(MotionEvent.ACTION_MOVE, .08f to .55f)
            touch(MotionEvent.ACTION_UP, .08f to .55f)
            scenario.onActivity {
                assertEquals(0, model.selected)
                assertTrue("Touched photo zoomed", model.collage.photos[0].zoom > 1.5f)
                assertEquals(1f, model.collage.photos[1].zoom)
                assertTrue(model.collage.photos[0].x in 0f..1f && model.collage.photos[0].y in 0f..1f)
            }
            downTime = SystemClock.uptimeMillis()
            touch(MotionEvent.ACTION_DOWN, .1f to .5f)
            touch(MotionEvent.ACTION_POINTER_DOWN or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT), .1f to .5f, .4f to .5f)
            touch(MotionEvent.ACTION_MOVE, .24f to .5f, .26f to .5f)
            touch(MotionEvent.ACTION_POINTER_UP or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT), .24f to .5f, .26f to .5f)
            touch(MotionEvent.ACTION_UP, .24f to .5f)
            scenario.onActivity { assertEquals(1f, model.collage.photos[0].zoom); assertEquals(1f, model.collage.photos[1].zoom) }
        }
    }
}
