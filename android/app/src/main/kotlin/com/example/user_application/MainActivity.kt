package com.example.user_application

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "roshita/pdf_ocr_pages")
            .setMethodCallHandler { call, result ->
                if (call.method != "renderPages") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val pages = call.argument<List<Int>>("pages")
                if (path.isNullOrBlank() || pages == null) {
                    result.error("INVALID_PDF", "Missing PDF path or page numbers", null)
                    return@setMethodCallHandler
                }

                // Rendering a PDF can be slow; never block the Flutter UI thread.
                Thread {
                    try {
                        val images = renderPdfPages(File(path), pages)
                        runOnUiThread { result.success(images) }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("PDF_RENDER_FAILED", error.message, null)
                        }
                    }
                }.start()
            }
    }

    private fun renderPdfPages(pdfFile: File, pageIndices: List<Int>): List<String> {
        require(pdfFile.isFile) { "PDF file does not exist" }
        val outputDirectory = File(cacheDir, "roshita_pdf_ocr").apply { mkdirs() }
        val outputPaths = mutableListOf<String>()
        try {
            ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    pageIndices.forEach { index ->
                        require(index in 0 until renderer.pageCount) { "Invalid PDF page index" }
                        renderer.openPage(index).use { page ->
                            val scale = minOf(2f, 2200f / maxOf(page.width, page.height))
                            val width = maxOf(1, (page.width * scale).toInt())
                            val height = maxOf(1, (page.height * scale).toInt())
                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            try {
                                Canvas(bitmap).drawColor(Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val image = File.createTempFile("page_${index}_", ".png", outputDirectory)
                                outputPaths.add(image.absolutePath)
                                FileOutputStream(image).use { stream ->
                                    check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                                        "Could not encode PDF page"
                                    }
                                }
                            } finally {
                                bitmap.recycle()
                            }
                        }
                    }
                }
            }
            return outputPaths
        } catch (error: Exception) {
            outputPaths.forEach { File(it).delete() }
            throw error
        }
    }
}
