package io.nosus.app

import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val SECURITY_CHANNEL = "co.nosus.app/security"
    private val SCREENSHOT_CHANNEL = "co.nosus.app/screenshot"
    private val SHARE_CHANNEL = "co.nosus.app/share"

    private var screenshotObserver: ContentObserver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null
    private var sharedData: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots and screen recordings — content appears black
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (savedInstanceState == null) {
            handleIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
        handleIntent(intent)
        sendSharedDataToFlutter()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    result.success(sharedData)
                    sharedData = null
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    } else {
                        result.error("BAD_ARGS", "Missing url parameter", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

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

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if ((Intent.ACTION_SEND == action || Intent.ACTION_SEND_MULTIPLE == action) && type != null) {
            if (type.startsWith("text/")) {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    ?: intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                if (text != null) {
                    val trimmed = text.trim()
                    val isUrl = trimmed.startsWith("http://") || trimmed.startsWith("https://")
                    sharedData = mapOf(
                        "type" to if (isUrl) "url" else "text",
                        "data" to trimmed,
                        "name" to null
                    )
                }
            } else {
                val uris = if (Intent.ACTION_SEND_MULTIPLE == action) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    }
                } else {
                    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    }
                    if (uri != null) arrayListOf(uri) else null
                }

                val uri = uris?.firstOrNull()
                if (uri != null) {
                    val resolved = saveUriToCache(uri, type)
                    if (resolved != null) {
                        sharedData = mapOf(
                            "type" to if (type.startsWith("image/")) "image" else "pdf",
                            "data" to resolved.absolutePath,
                            "name" to resolved.name
                        )
                    }
                }
            }
        }
    }

    private fun saveUriToCache(uri: Uri, mimeType: String): File? {
        try {
            var fileName = "shared_file_${System.currentTimeMillis()}"
            val extension = when {
                mimeType.startsWith("image/") -> {
                    val ext = mimeType.substringAfter("/", "")
                    if (ext.isNotEmpty()) ext else "png"
                }
                mimeType == "application/pdf" -> "pdf"
                else -> "bin"
            }

            val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        val name = cursor.getString(index)
                        if (!name.isNullOrEmpty()) {
                            fileName = name
                        }
                    }
                }
            }

            if (!fileName.contains(".")) {
                fileName = "$fileName.$extension"
            }

            val cacheFile = File(cacheDir, fileName)
            contentResolver.openInputStream(uri)?.use { inputStream ->
                FileOutputStream(cacheFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            return cacheFile
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun sendSharedDataToFlutter() {
        sharedData?.let {
            methodChannel?.invokeMethod("onShareReceived", it)
            sharedData = null
        }
    }
}
