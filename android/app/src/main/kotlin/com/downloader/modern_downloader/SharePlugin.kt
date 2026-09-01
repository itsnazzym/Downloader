package com.downloader.modern_downloader

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SharePlugin :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var pendingText: String? = null

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "takeInitialSharedText" -> {
                val text = pendingText
                pendingText = null
                result.success(text)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        eventSink = events
        val text = pendingText
        if (text != null) {
            pendingText = null
            events?.success(text)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun handleIntent(intent: Intent?) {
        val text = extractSharedText(intent) ?: return
        val sink = eventSink
        if (sink != null) {
            sink.success(text)
        } else {
            pendingText = text
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action == Intent.ACTION_SEND) {
            val extra = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!extra.isNullOrBlank()) return extra
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (uri != null) return uri.toString()
        }
        if (action == Intent.ACTION_VIEW) {
            val data = intent.dataString
            if (!data.isNullOrBlank()) return data
        }
        return null
    }

    companion object {
        @Volatile
        var instance: SharePlugin? = null
            private set

        fun register(engine: FlutterEngine): SharePlugin {
            val plugin = SharePlugin()
            instance = plugin
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.modern_downloader/share",
            ).setMethodCallHandler(plugin)
            EventChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.modern_downloader/shareEvents",
            ).setStreamHandler(plugin)
            return plugin
        }

        fun handleIntent(intent: Intent?) {
            instance?.handleIntent(intent)
        }
    }
}
