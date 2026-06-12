package com.example.no_sus

import android.database.ContentObserver
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SECURITY_CHANNEL = "co.nosus.app/security"
    private val SCREENSHOT_CHANNEL = "co.nosus.app/screenshot"

    private var screenshotObserver: ContentObserver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots and screen recordings — content appears black
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel: toggle FLAG_SECURE from Dart ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecure" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    "disableSecure" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── EventChannel: push screenshot/recording events to Dart ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    startScreenshotObserver()
                }

                override fun onCancel(arguments: Any?) {
                    stopScreenshotObserver()
                    eventSink = null
                }
            })
    }

    private fun startScreenshotObserver() {
        val handler = Handler(Looper.getMainLooper())

        screenshotObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                uri ?: return
                try {
                    // Resolve the file path to check if it's a screenshot/recording
                    val cursor = contentResolver.query(
                        uri,
                        arrayOf(MediaStore.MediaColumns.DATA, MediaStore.MediaColumns.DISPLAY_NAME),
                        null, null, null
                    )
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val pathIndex = it.getColumnIndex(MediaStore.MediaColumns.DATA)
                            val nameIndex = it.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                            val path = if (pathIndex >= 0) it.getString(pathIndex)?.lowercase() ?: "" else ""
                            val name = if (nameIndex >= 0) it.getString(nameIndex)?.lowercase() ?: "" else ""

                            val isScreenshot = path.contains("screenshot") || name.contains("screenshot")
                            val isRecording = path.contains("screenrecord") || name.contains("screenrecord") ||
                                              path.contains("screen_record") || name.contains("screen_record")

                            if (isScreenshot || isRecording) {
                                eventSink?.success(if (isRecording) "recording" else "screenshot")
                            }
                        }
                    }
                } catch (_: Exception) { /* Ignore permission or cursor errors */ }
            }
        }

        // Watch Images (screenshots) and Videos (screen recordings)
        contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, screenshotObserver!!
        )
        contentResolver.registerContentObserver(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, screenshotObserver!!
        )
    }

    private fun stopScreenshotObserver() {
        screenshotObserver?.let { contentResolver.unregisterContentObserver(it) }
        screenshotObserver = null
    }

    override fun onDestroy() {
        stopScreenshotObserver()
        super.onDestroy()
    }
}
