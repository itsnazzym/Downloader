package com.downloader.modern_downloader

import android.content.Context
import android.os.Environment
import android.webkit.CookieManager
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class EnginePlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private val executor = Executors.newCachedThreadPool()
    private var eventSink: EventChannel.EventSink? = null
    private val running = ConcurrentHashMap<String, Boolean>()

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "init" -> {
                executor.execute {
                    try {
                        YoutubeDL.getInstance().init(context)
                        FFmpeg.getInstance().init(context)
                        Aria2c.getInstance().init(context)
                        mainResult(result) { it.success(null) }
                    } catch (e: Exception) {
                        mainResult(result) {
                            it.error("init_failed", e.message, null)
                        }
                    }
                }
            }
            "defaultOutputDir" -> {
                try {
                    result.success(resolveOutputDir().absolutePath)
                } catch (e: Exception) {
                    result.error("output_dir", e.message, null)
                }
            }
            "webViewCookies" -> {
                val url = call.argument<String>("url") ?: ""
                result.success(CookieManager.getInstance().getCookie(url))
            }
            "updateYtDlp" -> {
                executor.execute {
                    try {
                        val status =
                            YoutubeDL.getInstance().updateYoutubeDL(
                                context,
                                YoutubeDL.UpdateChannel.STABLE,
                            )
                        mainResult(result) { it.success(status?.toString() ?: "updated") }
                    } catch (e: Exception) {
                        mainResult(result) {
                            it.error("update_failed", e.message, null)
                        }
                    }
                }
            }
            "run" -> {
                val executable = call.argument<String>("executable") ?: "yt-dlp"
                val arguments = call.argument<List<String>>("arguments") ?: emptyList()
                executor.execute {
                    try {
                        val response = executeBinary(executable, arguments, null, null)
                        mainResult(result) {
                            it.success(
                                mapOf(
                                    "pid" to 0,
                                    "exitCode" to response.first,
                                    "stdout" to response.second,
                                    "stderr" to response.third,
                                ),
                            )
                        }
                    } catch (e: Exception) {
                        mainResult(result) {
                            it.success(
                                mapOf(
                                    "pid" to 0,
                                    "exitCode" to 1,
                                    "stdout" to "",
                                    "stderr" to (e.message ?: e.toString()),
                                ),
                            )
                        }
                    }
                }
            }
            "start" -> {
                val processId = call.argument<String>("processId") ?: return
                val executable = call.argument<String>("executable") ?: "yt-dlp"
                val arguments = call.argument<List<String>>("arguments") ?: emptyList()
                running[processId] = true
                result.success(null)
                executor.execute {
                    try {
                        val response =
                            executeBinary(executable, arguments, processId) { line ->
                                emit(
                                    mapOf(
                                        "processId" to processId,
                                        "stream" to "stdout",
                                        "data" to line,
                                    ),
                                )
                            }
                        emit(
                            mapOf(
                                "processId" to processId,
                                "stream" to "exit",
                                "code" to response.first,
                            ),
                        )
                    } catch (e: Exception) {
                        emit(
                            mapOf(
                                "processId" to processId,
                                "stream" to "stderr",
                                "data" to (e.message ?: e.toString()),
                            ),
                        )
                        emit(
                            mapOf(
                                "processId" to processId,
                                "stream" to "exit",
                                "code" to 1,
                            ),
                        )
                    } finally {
                        running.remove(processId)
                    }
                }
            }
            "kill" -> {
                val processId = call.argument<String>("processId")
                if (processId != null) {
                    try {
                        YoutubeDL.getInstance().destroyProcessById(processId)
                    } catch (_: Exception) {
                    }
                    running.remove(processId)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun executeBinary(
        executable: String,
        arguments: List<String>,
        processId: String?,
        onLine: ((String) -> Unit)?,
    ): Triple<Int, String, String> {
        val name = executable.lowercase()
        if (name.startsWith("ffmpeg") || name.startsWith("ffprobe")) {
            if (arguments.isEmpty() || arguments.contains("-version") || arguments.contains("--version")) {
                return Triple(0, "ffmpeg (android bundle)", "")
            }
        }
        if (name.startsWith("aria2") &&
            (arguments.isEmpty() || arguments.contains("--version"))
        ) {
            return Triple(0, "aria2c (android bundle)", "")
        }

        val request = YoutubeDLRequest(ArrayList<String>())
        request.addCommands(ArrayList(arguments))
        val callback: ((Float, Long, String) -> Unit)? =
            if (onLine == null) {
                null
            } else {
                { _, _, line -> onLine(line) }
            }
        val response = YoutubeDL.getInstance().execute(request, processId, callback)
        return Triple(response.exitCode, response.out ?: "", response.err ?: "")
    }

    private fun resolveOutputDir(): File {
        val publicDir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val preferred = File(publicDir, "ModernDownloader")
        if (!preferred.exists()) {
            preferred.mkdirs()
        }
        if (preferred.exists() && preferred.canWrite()) {
            return preferred
        }
        val fallback = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        if (fallback != null) {
            if (!fallback.exists()) fallback.mkdirs()
            return fallback
        }
        return context.filesDir
    }

    private fun emit(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        context.mainExecutor.execute { sink.success(payload) }
    }

    private fun mainResult(
        result: MethodChannel.Result,
        block: (MethodChannel.Result) -> Unit,
    ) {
        context.mainExecutor.execute { block(result) }
    }

    companion object {
        fun register(
            context: Context,
            engine: FlutterEngine,
        ) {
            val plugin = EnginePlugin(context.applicationContext)
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.modern_downloader/engine",
            ).setMethodCallHandler(plugin)
            EventChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.modern_downloader/engineEvents",
            ).setStreamHandler(plugin)
        }
    }
}
