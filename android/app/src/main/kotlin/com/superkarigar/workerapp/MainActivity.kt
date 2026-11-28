package com.superkarigar.workerapp

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val pdfWorker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Draws the pages of a PDF as PNGs, so the AI resume builder can show
        // its live preview inside the app instead of only a link to open it.
        // Android's own PdfRenderer: no extra package.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "superkarigar/pdf_pages")
            .setMethodCallHandler { call, result ->
                if (call.method != "render") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val width = call.argument<Int>("width") ?: 1080
                val maxPages = call.argument<Int>("maxPages") ?: 3
                if (path == null) {
                    result.error("bad_args", "path is required", null)
                    return@setMethodCallHandler
                }
                pdfWorker.execute {
                    try {
                        val pages = renderPages(File(path), width, maxPages)
                        runOnUiThread { result.success(pages) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("render_failed", e.message, null) }
                    }
                }
            }
    }

    private fun renderPages(file: File, width: Int, maxPages: Int): List<ByteArray> {
        val pages = mutableListOf<ByteArray>()
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { renderer ->
                for (index in 0 until minOf(renderer.pageCount, maxPages)) {
                    renderer.openPage(index).use { page ->
                        val height = (width.toFloat() * page.height / page.width).toInt()
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        // PdfRenderer leaves the page transparent; paper is white.
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                        bitmap.recycle()
                        pages.add(out.toByteArray())
                    }
                }
            }
        }
        return pages
    }
}
