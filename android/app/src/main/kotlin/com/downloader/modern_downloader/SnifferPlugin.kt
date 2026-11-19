package com.downloader.modern_downloader

import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Build
import android.os.Message
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SafeBrowsingResponse
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

/**
 * Records the media addresses a page requests (manifests and media files),
 * including those loaded from iframes or by the media element itself, which
 * JavaScript hooks cannot see. Dart reads the list and lets the user download
 * what the page really plays, with the session of the in-app browser.
 *
 * The page's own WebViewClient is kept and every callback is forwarded to it,
 * so navigation keeps working exactly as before.
 */
class SnifferPlugin(private val engine: FlutterEngine) : MethodChannel.MethodCallHandler {
    private val lock = Any()
    private val entries = ArrayList<Map<String, Any?>>()
    private val seen = HashSet<String>()

    @Volatile private var page: String = ""
    @Volatile private var userAgent: String = ""

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                val id = call.argument<Number>("id")?.toLong()
                if (id == null) {
                    result.success(false)
                    return
                }
                result.success(attach(id))
            }
            "streams" -> result.success(snapshot())
            "clear" -> {
                clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun attach(id: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        @Suppress("DEPRECATION")
        val webView = WebViewFlutterAndroidExternalApi.getWebView(engine, id) ?: return false
        val current = webView.webViewClient
        if (current is SniffingClient) return true
        userAgent = webView.settings.userAgentString ?: ""
        page = webView.url ?: ""
        webView.webViewClient = SniffingClient(current, this)
        return true
    }

    private fun snapshot(): List<Map<String, Any?>> = synchronized(lock) { ArrayList(entries) }

    private fun clear() = synchronized(lock) {
        entries.clear()
        seen.clear()
    }

    fun onPage(url: String?) {
        if (url.isNullOrEmpty()) return
        // A new document: what was sniffed for the previous one is stale.
        if (url != page) {
            page = url
            clear()
        }
    }

    fun record(url: String, headers: Map<String, String>?) {
        if (!isInteresting(url)) return
        synchronized(lock) {
            if (!seen.add(url)) return
            if (entries.size >= MAX_ENTRIES) {
                val dropped = entries.removeAt(0)
                seen.remove(dropped["url"] as String)
            }
            entries.add(
                mapOf(
                    "url" to url,
                    "ts" to System.currentTimeMillis(),
                    "page" to page,
                    "referer" to (headers?.get("Referer") ?: headers?.get("referer")),
                    "origin" to (headers?.get("Origin") ?: headers?.get("origin")),
                    "userAgent" to (headers?.get("User-Agent") ?: userAgent),
                ),
            )
        }
    }

    /** Cheap pre-filter; Dart does the real classification and ranking. */
    private fun isInteresting(url: String): Boolean {
        if (!url.startsWith("http")) return false
        val path = url.substringBefore('?').substringBefore('#').lowercase()
        val ext = path.substringAfterLast('.', "")
        if (ext in SEGMENT_EXTENSIONS) return false
        if (ext in MEDIA_EXTENSIONS) return true
        return path.contains(".m3u8") || path.contains(".mpd") ||
            path.endsWith("/manifest") || path.contains(".ism/manifest") ||
            path.endsWith("/playlist.json") || path.endsWith("/master.json")
    }

    companion object {
        private const val MAX_ENTRIES = 300
        private val MEDIA_EXTENSIONS = setOf(
            "m3u8", "mpd", "mp4", "webm", "m4v", "mov", "mkv", "mp3", "m4a", "ogg", "opus", "flac",
        )
        private val SEGMENT_EXTENSIONS = setOf(
            "ts", "m4s", "m4f", "cmfv", "cmfa", "aac", "vtt", "srt", "jpg", "jpeg", "png", "gif",
            "webp", "svg", "css", "js", "json", "woff", "woff2", "ico",
        )

        fun register(engine: FlutterEngine) {
            val plugin = SnifferPlugin(engine)
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "com.downloader.modern_downloader/sniffer",
            ).setMethodCallHandler(plugin)
        }
    }
}

/** Forwards every callback to [inner]; only records requests on the way. */
@Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
private class SniffingClient(
    private val inner: WebViewClient,
    private val sniffer: SnifferPlugin,
) : WebViewClient() {
    override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
        if (request != null) {
            try {
                sniffer.record(request.url.toString(), request.requestHeaders)
            } catch (_: Exception) {
            }
        }
        return inner.shouldInterceptRequest(view, request)
    }

    override fun onLoadResource(view: WebView?, url: String?) {
        if (url != null) {
            try {
                sniffer.record(url, null)
            } catch (_: Exception) {
            }
        }
        inner.onLoadResource(view, url)
    }

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        sniffer.onPage(url)
        inner.onPageStarted(view, url, favicon)
    }

    override fun onPageFinished(view: WebView?, url: String?) = inner.onPageFinished(view, url)

    override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
        sniffer.onPage(url)
        inner.doUpdateVisitedHistory(view, url, isReload)
    }

    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean =
        inner.shouldOverrideUrlLoading(view, request)

    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
        inner.shouldOverrideUrlLoading(view, url)

    override fun shouldInterceptRequest(view: WebView?, url: String?): WebResourceResponse? =
        inner.shouldInterceptRequest(view, url)

    override fun onPageCommitVisible(view: WebView?, url: String?) = inner.onPageCommitVisible(view, url)

    override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) =
        inner.onReceivedError(view, request, error)

    override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) =
        inner.onReceivedError(view, errorCode, description, failingUrl)

    override fun onReceivedHttpError(
        view: WebView?,
        request: WebResourceRequest?,
        errorResponse: WebResourceResponse?,
    ) = inner.onReceivedHttpError(view, request, errorResponse)

    override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) =
        inner.onReceivedSslError(view, handler, error)

    override fun onReceivedClientCertRequest(view: WebView?, request: ClientCertRequest?) =
        inner.onReceivedClientCertRequest(view, request)

    override fun onReceivedHttpAuthRequest(
        view: WebView?,
        handler: HttpAuthHandler?,
        host: String?,
        realm: String?,
    ) = inner.onReceivedHttpAuthRequest(view, handler, host, realm)

    override fun onReceivedLoginRequest(view: WebView?, realm: String?, account: String?, args: String?) =
        inner.onReceivedLoginRequest(view, realm, account, args)

    override fun onFormResubmission(view: WebView?, dontResend: Message?, resend: Message?) =
        inner.onFormResubmission(view, dontResend, resend)

    override fun onTooManyRedirects(view: WebView?, cancelMsg: Message?, continueMsg: Message?) =
        inner.onTooManyRedirects(view, cancelMsg, continueMsg)

    override fun onScaleChanged(view: WebView?, oldScale: Float, newScale: Float) =
        inner.onScaleChanged(view, oldScale, newScale)

    override fun shouldOverrideKeyEvent(view: WebView?, event: KeyEvent?): Boolean =
        inner.shouldOverrideKeyEvent(view, event)

    override fun onUnhandledKeyEvent(view: WebView?, event: KeyEvent?) =
        inner.onUnhandledKeyEvent(view, event)

    override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean =
        inner.onRenderProcessGone(view, detail)

    override fun onSafeBrowsingHit(
        view: WebView?,
        request: WebResourceRequest?,
        threatType: Int,
        callback: SafeBrowsingResponse?,
    ) = inner.onSafeBrowsingHit(view, request, threatType, callback)
}
