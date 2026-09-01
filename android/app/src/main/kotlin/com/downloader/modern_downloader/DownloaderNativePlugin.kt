package com.downloader.modern_downloader

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class DownloaderNativePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    companion object {
        const val METHOD_CHANNEL = "modern_downloader/native"
        const val EVENT_CHANNEL = "modern_downloader/ytdlp_events"

        @Volatile
        var pendingShareText: String? = null
    }

    private lateinit var appContext: Context
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeIds = ConcurrentHashMap.newKeySet<String>()
    private val sinkLock = Any()
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        synchronized(sinkLock) {
            eventSink = null
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        synchronized(sinkLock) {
            eventSink = events
        }
    }

    override fun onCancel(arguments: Any?) {
        synchronized(sinkLock) {
            eventSink = null
        }
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "initEngine" ->
                executor.execute {
                    try {
                        YoutubeDL.getInstance().init(appContext)
                        FFmpeg.getInstance().init(appContext)
                        Aria2c.getInstance().init(appContext)
                        succeed(result, true)
                    } catch (error: Exception) {
                        fail(result, "init_failed", error.message)
                    }
                }
            "updateYtDlp" ->
                executor.execute {
                    try {
                        val status =
                            YoutubeDL.getInstance().updateYoutubeDL(
                                appContext,
                                YoutubeDL.UpdateChannel.STABLE,
                            )
                        succeed(result, status?.toString() ?: "ok")
                    } catch (error: Exception) {
                        fail(result, "update_failed", error.message)
                    }
                }
            "probe" -> {
                val args = call.argument<List<String>>("args") ?: emptyList()
                executor.execute {
                    try {
                        val response = YoutubeDL.getInstance().execute(requestFromArgs(args))
                        succeed(result, response.out)
                    } catch (error: Exception) {
                        fail(result, "probe_failed", error.message)
                    }
                }
            }
            "download" -> {
                val id = call.argument<String>("id")
                val args = call.argument<List<String>>("args") ?: emptyList()
                if (id.isNullOrBlank()) {
                    result.error("bad_args", "id required", null)
                    return
                }
                executor.execute {
                    try {
                        activeIds.add(id)
                        val response =
                            YoutubeDL.getInstance().execute(requestFromArgs(args), id) { progress, eta, line ->
                                emit(
                                    mapOf(
                                        "id" to id,
                                        "type" to "line",
                                        "line" to (line ?: ""),
                                        "progress" to progress.toDouble(),
                                        "eta" to eta,
                                    ),
                                )
                            }
                        emit(
                            mapOf(
                                "id" to id,
                                "type" to "done",
                                "out" to response.out,
                                "exitCode" to response.exitCode,
                            ),
                        )
                        succeed(result, true)
                    } catch (error: Exception) {
                        emit(
                            mapOf(
                                "id" to id,
                                "type" to "error",
                                "message" to (error.message ?: "download failed"),
                            ),
                        )
                        fail(result, "download_failed", error.message)
                    } finally {
                        activeIds.remove(id)
                    }
                }
            }
            "cancel" -> {
                val id = call.argument<String>("id")
                if (id.isNullOrBlank()) {
                    result.error("bad_args", "id required", null)
                    return
                }
                executor.execute {
                    try {
                        YoutubeDL.getInstance().destroyProcessById(id)
                        succeed(result, true)
                    } catch (error: Exception) {
                        fail(result, "cancel_failed", error.message)
                    }
                }
            }
            "defaultOutputFolder" -> {
                try {
                    result.success(AndroidStorage.defaultOutputFolder(appContext))
                } catch (error: Exception) {
                    result.error("storage", error.message, null)
                }
            }
            "getInitialShare" -> {
                val text = pendingShareText
                pendingShareText = null
                result.success(text)
            }
            "openPath" -> {
                val path = call.argument<String>("path")
                val reveal = call.argument<Boolean>("reveal") ?: false
                if (path.isNullOrBlank()) {
                    result.error("bad_args", "path required", null)
                    return
                }
                try {
                    openPath(path, reveal)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("open_failed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requestFromArgs(args: List<String>): YoutubeDLRequest {
        val urls =
            args.filter { argument ->
                argument.startsWith("http://") || argument.startsWith("https://")
            }
        val request =
            if (urls.isNotEmpty()) {
                YoutubeDLRequest(urls)
            } else {
                YoutubeDLRequest(emptyList())
            }
        val commands =
            args.filterNot { argument ->
                argument.startsWith("http://") || argument.startsWith("https://")
            }
        if (commands.isNotEmpty()) {
            request.addCommands(commands)
        }
        return request
    }

    private fun openPath(
        path: String,
        reveal: Boolean,
    ) {
        val file = File(path)
        val target =
            if (reveal && file.isFile) {
                file.parentFile ?: file
            } else {
                file
            }
        val existing = if (target.exists()) target else file
        val uri =
            FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.fileprovider",
                existing,
            )
        val extension = existing.extension.lowercase()
        val mime =
            if (existing.isDirectory) {
                "*/*"
            } else {
                MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
            }
        val view =
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        val chooser = Intent.createChooser(view, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(chooser)
    }

    private fun emit(payload: Map<String, Any?>) {
        mainHandler.post {
            synchronized(sinkLock) {
                eventSink?.success(payload)
            }
        }
    }

    private fun succeed(
        result: MethodChannel.Result,
        value: Any?,
    ) {
        mainHandler.post { result.success(value) }
    }

    private fun fail(
        result: MethodChannel.Result,
        code: String,
        message: String?,
    ) {
        mainHandler.post { result.error(code, message, null) }
    }
}
