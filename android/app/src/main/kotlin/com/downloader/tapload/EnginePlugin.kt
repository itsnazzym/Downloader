package com.downloader.tapload

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.util.Log
import android.webkit.CookieManager
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class EnginePlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var multicastLock: WifiManager.MulticastLock? = null
    private var eventSink: EventChannel.EventSink? = null
    private val running = ConcurrentHashMap<String, Boolean>()

    private fun channelFor(name: String?): YoutubeDL.UpdateChannel =
        if (name == "stable") YoutubeDL.UpdateChannel.STABLE else YoutubeDL.UpdateChannel.NIGHTLY

    private fun otherChannel(c: YoutubeDL.UpdateChannel): YoutubeDL.UpdateChannel =
        if (c == YoutubeDL.UpdateChannel.STABLE) YoutubeDL.UpdateChannel.NIGHTLY else YoutubeDL.UpdateChannel.STABLE

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "init" -> {
                val autoUpdate = call.argument<Boolean>("autoUpdate") ?: true
                val preferred = channelFor(call.argument<String>("channel"))
                executor.execute {
                    try {
                        YoutubeDL.getInstance().init(context)
                        FFmpeg.getInstance().init(context)
                        Aria2c.getInstance().init(context)
                        if (autoUpdate) {
                            try {
                                YoutubeDL.getInstance().updateYoutubeDL(
                                    context,
                                    preferred,
                                )
                            } catch (e: Exception) {
                                try {
                                    YoutubeDL.getInstance().updateYoutubeDL(
                                        context,
                                        otherChannel(preferred),
                                    )
                                } catch (_: Exception) {}
                                Log.w("EnginePlugin", "Auto-update yt-dlp on init fallback: ${e.message}")
                            }
                        }
                        mainResult(result) { it.success(null) }
                    } catch (e: Exception) {
                        mainResult(result) {
                            it.error("init_failed", e.message, null)
                        }
                    }
                }
            }
            "version" -> {
                executor.execute {
                    try {
                        val v = YoutubeDL.getInstance().version(context)
                        mainResult(result) { it.success(v ?: "unknown") }
                    } catch (e: Exception) {
                        mainResult(result) { it.success("unknown") }
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
            "diskSpace" -> {
                try {
                    val stat = StatFs(resolveOutputDir().absolutePath)
                    result.success(
                        mapOf(
                            "total" to stat.totalBytes,
                            "free" to stat.availableBytes,
                        ),
                    )
                } catch (e: Exception) {
                    result.error("disk_space", e.message, null)
                }
            }
            "webViewCookies" -> {
                val url = call.argument<String>("url") ?: ""
                result.success(CookieManager.getInstance().getCookie(url))
            }
            "isMetered" -> {
                try {
                    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                    // No active network is not "metered": nothing could download.
                    val network = cm?.activeNetwork
                    val caps = if (network != null) cm.getNetworkCapabilities(network) else null
                    result.success(
                        caps != null &&
                            !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED),
                    )
                } catch (e: Exception) {
                    result.error("metered", e.message, null)
                }
            }
            "updateYtDlp" -> {
                val preferred = channelFor(call.argument<String>("channel"))
                executor.execute {
                    try {
                        var status = try {
                            YoutubeDL.getInstance().updateYoutubeDL(
                                context,
                                preferred,
                            )
                        } catch (_: Exception) {
                            null
                        }
                        if (status == null) {
                            status = YoutubeDL.getInstance().updateYoutubeDL(
                                context,
                                otherChannel(preferred),
                            )
                        }
                        val version = try {
                            YoutubeDL.getInstance().version(context) ?: ""
                        } catch (_: Exception) {
                            ""
                        }
                        mainResult(result) {
                            it.success(status?.toString() ?: if (version.isNotEmpty()) version else "updated")
                        }
                    } catch (e: Exception) {
                        mainResult(result) {
                            it.error("update_failed", e.message, null)
                        }
                    }
                }
            }
            "viewFile" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_arg", "Path is required", null)
                    return
                }
                try {
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("not_found", "File does not exist", null)
                        return
                    }
                    val mime = call.argument<String>("mimeType") ?: resolveMimeType(file)
                    val uri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        file,
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, mime)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("view_failed", e.message, null)
                }
            }
            "shareFile" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("invalid_arg", "Path is required", null)
                    return
                }
                try {
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("not_found", "File does not exist", null)
                        return
                    }
                    val mime = call.argument<String>("mimeType") ?: resolveMimeType(file)
                    val uri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        file,
                    )
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    val chooser = Intent.createChooser(intent, "Partager").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("share_failed", e.message, null)
                }
            }
            "openUrl" -> {
                val url = call.argument<String>("url") ?: ""
                try {
                    val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("open_url_failed", e.message, null)
                }
            }
            "getVideoThumbnail" -> {
                val videoPath = call.argument<String>("videoPath") ?: ""
                val thumbnailPath = call.argument<String>("thumbnailPath") ?: ""
                executor.execute {
                    val ok = extractThumbnail(videoPath, thumbnailPath)
                    mainResult(result) {
                        if (ok) it.success(thumbnailPath) else it.success(null)
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
            "acquireMulticastLock" -> {
                try {
                    if (multicastLock == null) {
                        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        multicastLock = wifi?.createMulticastLock("TapLoadMulticast")?.apply {
                            setReferenceCounted(true)
                        }
                    }
                    multicastLock?.let {
                        if (!it.isHeld) {
                            it.acquire()
                            Log.i("EnginePlugin", "MulticastLock acquired")
                        }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    Log.w("EnginePlugin", "Failed to acquire multicast lock: ${e.message}")
                    result.success(false)
                }
            }
            "releaseMulticastLock" -> {
                try {
                    multicastLock?.let {
                        if (it.isHeld) {
                            it.release()
                            Log.i("EnginePlugin", "MulticastLock released")
                        }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    Log.w("EnginePlugin", "Failed to release multicast lock: ${e.message}")
                    result.success(false)
                }
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
            val iIndex = arguments.indexOf("-i")
            val lastArg = arguments.lastOrNull()
            if (iIndex != -1 && iIndex + 1 < arguments.size && lastArg != null && lastArg.endsWith(".jpg")) {
                val videoPath = arguments[iIndex + 1]
                val thumbSuccess = extractThumbnail(videoPath, lastArg)
                return if (thumbSuccess) {
                    Triple(0, "Thumbnail extracted natively", "")
                } else {
                    Triple(1, "", "Failed to extract thumbnail")
                }
            }
            if (arguments.isEmpty() || arguments.contains("-version") || arguments.contains("--version")) {
                return Triple(0, "ffmpeg (android bundle)", "")
            }
            if (name.startsWith("ffmpeg")) return runBundledFfmpeg(arguments)
            return Triple(0, "ffmpeg (android bundle)", "")
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

    /**
     * Runs the ffmpeg youtubedl-android ships (the one yt-dlp uses) for a
     * real job, e.g. a TikTok photo slideshow. It is libffmpeg.so in the
     * native library dir and needs its unpacked libraries on the path.
     */
    private fun runBundledFfmpeg(arguments: List<String>): Triple<Int, String, String> {
        FFmpeg.getInstance().init(context)
        val binary = File(context.applicationInfo.nativeLibraryDir, "libffmpeg.so")
        val packages = File(context.noBackupFilesDir, "youtubedl-android/packages")
        val process = ProcessBuilder(listOf(binary.absolutePath) + arguments)
            .redirectErrorStream(false)
            .apply {
                environment()["LD_LIBRARY_PATH"] = listOf(
                    File(packages, "ffmpeg/usr/lib").absolutePath,
                    File(packages, "python/usr/lib").absolutePath,
                ).joinToString(":")
            }
            .start()
        // Read stdout on its own thread so a full pipe never blocks ffmpeg.
        var out = ""
        val reader = Thread { out = process.inputStream.bufferedReader().readText() }
        reader.start()
        val err = process.errorStream.bufferedReader().readText()
        val code = process.waitFor()
        reader.join()
        return Triple(code, out, err)
    }

    private fun extractThumbnail(videoPath: String, thumbnailPath: String): Boolean {
        var retriever: MediaMetadataRetriever? = null
        try {
            val videoFile = File(videoPath)
            if (!videoFile.exists()) return false
            val thumbFile = File(thumbnailPath)
            thumbFile.parentFile?.mkdirs()

            retriever = MediaMetadataRetriever()
            retriever.setDataSource(videoPath)
            val bitmap = retriever.getFrameAtTime(2000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: retriever.frameAtTime ?: return false

            FileOutputStream(thumbFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            }
            return thumbFile.exists() && thumbFile.length() > 0
        } catch (_: Exception) {
            return false
        } finally {
            try {
                retriever?.release()
            } catch (_: Exception) {}
        }
    }

    private fun resolveMimeType(file: File): String {
        val ext = file.extension.lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        if (mime != null) return mime
        return when (ext) {
            "mp4", "m4v", "mov" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "avi" -> "video/x-msvideo"
            "mp3" -> "audio/mpeg"
            "aac", "m4a" -> "audio/aac"
            "ogg", "opus" -> "audio/ogg"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            else -> "*/*"
        }
    }

    private fun resolveOutputDir(): File {
        val publicDir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val preferred = File(publicDir, "TapLoad")
        try {
            if (!preferred.exists()) {
                preferred.mkdirs()
            }
            if (preferred.exists() && preferred.canWrite()) {
                val probe = File(preferred, ".probe_${System.currentTimeMillis()}")
                if (probe.createNewFile()) {
                    probe.delete()
                    return preferred
                }
            }
        } catch (_: Exception) {
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
        mainHandler.post { sink.success(payload) }
    }

    private fun mainResult(
        result: MethodChannel.Result,
        block: (MethodChannel.Result) -> Unit,
    ) {
        mainHandler.post { block(result) }
    }

    companion object {
        fun register(
            context: Context,
            engine: FlutterEngine,
        ) {
            val plugin = EnginePlugin(context.applicationContext)
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.tapload/engine",
            ).setMethodCallHandler(plugin)
            EventChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.tapload/engineEvents",
            ).setStreamHandler(plugin)
        }
    }
}
