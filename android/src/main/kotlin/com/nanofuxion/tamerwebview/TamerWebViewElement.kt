package com.nanofuxion.tamerwebview

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import com.lynx.react.bridge.Callback
import com.lynx.react.bridge.ReadableMap
import com.lynx.tasm.behavior.LynxContext
import com.lynx.tasm.behavior.LynxProp
import com.lynx.tasm.behavior.LynxUIMethod
import com.lynx.tasm.behavior.LynxUIMethodConstants
import com.lynx.tasm.behavior.ui.LynxUI
import com.lynx.tasm.event.LynxCustomEvent
import org.json.JSONObject

private const val BRIDGE_NAME = "ReactNativeWebView"
private const val DEFAULT_UA =
    "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 " +
    "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

// Injected on every page to expose window.ReactNativeWebView.postMessage on browsers that
// don't natively have the WebMessageListener channel.
private const val BRIDGE_INJECT = """
(function() {
  if (window.ReactNativeWebView && window.ReactNativeWebView._tamerBridgeInstalled) return;
  var nativeBridge = window.$BRIDGE_NAME;
  window.ReactNativeWebView = {
    _tamerBridgeInstalled: true,
    postMessage: function(data) {
      nativeBridge.postMessage(String(data));
    }
  };
})();
"""

class TamerWebViewElement(context: LynxContext) : LynxUI<FrameLayout>(context) {

    private lateinit var webView: WebView
    private var uri: String = ""
    private var html: String = ""
    private var baseUrl: String = ""
    private var injectedJs: String? = null
    private var injectedJsBeforeLoad: String? = null
    private var javaScriptEnabled: Boolean = true
    private var messagingEnabled: Boolean = true
    private var userAgent: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // --- Event helpers ---

    private fun emitEvent(name: String, detail: Map<String, Any?>) {
        val event = LynxCustomEvent(getSign(), name)
        for ((k, v) in detail) {
            when (v) {
                is String  -> event.addDetail(k, v)
                is Boolean -> event.addDetail(k, v)
                is Int     -> event.addDetail(k, v)
                is Long    -> event.addDetail(k, v)
                is Double  -> event.addDetail(k, v)
                null       -> {}
                else       -> event.addDetail(k, v.toString())
            }
        }
        lynxContext.eventEmitter.sendCustomEvent(event)
    }

    // Called from the JS→native bridge on the WebView thread; re-post to main for Lynx event emission.
    fun dispatchMessageFromPage(message: String) {
        mainHandler.post {
            emitEvent("message", mapOf("data" to message))
        }
    }

    // --- View creation ---

    @SuppressLint("SetJavaScriptEnabled", "RequiresFeature")
    override fun createView(context: Context): FrameLayout {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true)
        }

        val container = FrameLayout(context)
        webView = WebView(context).apply {
            settings.apply {
                javaScriptEnabled = this@TamerWebViewElement.javaScriptEnabled
                domStorageEnabled = true
                builtInZoomControls = true
                displayZoomControls = false
                setSupportMultipleWindows(false)
                allowFileAccess = false
                @Suppress("DEPRECATION")
                allowFileAccessFromFileURLs = false
                @Suppress("DEPRECATION")
                allowUniversalAccessFromFileURLs = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                }
                userAgentString = userAgent ?: DEFAULT_UA
            }
            webViewClient = TamerWebViewClient()
            webChromeClient = WebChromeClient()
            setBackgroundColor(Color.TRANSPARENT)
        }

        if (messagingEnabled) {
            setupBridge()
        }

        container.addView(
            webView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        return container
    }

    @SuppressLint("RequiresFeature")
    private fun setupBridge() {
        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.addWebMessageListener(
                webView,
                BRIDGE_NAME,
                setOf("*"),
                object : WebViewCompat.WebMessageListener {
                    override fun onPostMessage(
                        view: android.webkit.WebView,
                        message: WebMessageCompat,
                        sourceOrigin: android.net.Uri,
                        isMainFrame: Boolean,
                        replyProxy: androidx.webkit.JavaScriptReplyProxy
                    ) {
                        dispatchMessageFromPage(message.data ?: "")
                    }
                }
            )
        } else {
            webView.addJavascriptInterface(TamerWebBridge(this), BRIDGE_NAME)
        }
    }

    // --- Content loading ---

    private fun applyContent() {
        if (!::webView.isInitialized) return
        when {
            uri.isNotEmpty() -> webView.loadUrl(uri)
            html.isNotEmpty() -> {
                val base = baseUrl.takeIf { it.isNotEmpty() }
                webView.loadDataWithBaseURL(base, html, "text/html", "utf-8", null)
            }
        }
    }

    // --- WebViewClient ---

    private inner class TamerWebViewClient : WebViewClient() {

        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
            super.onPageStarted(view, url, favicon)
            val w = view ?: return
            // Inject bridge polyfill first so pages can call postMessage during load
            if (messagingEnabled &&
                !WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
                w.evaluateJavascript(BRIDGE_INJECT, null)
            }
            val before = injectedJsBeforeLoad
            if (!before.isNullOrEmpty()) {
                w.evaluateJavascript("(function(){\n$before\n})();", null)
            }
        }

        override fun onPageFinished(view: WebView?, url: String?) {
            super.onPageFinished(view, url)
            val w = view ?: return
            val inj = injectedJs
            if (!inj.isNullOrEmpty()) {
                w.evaluateJavascript("(function(){\n$inj\n})();", null)
            }
            emitEvent(
                "load",
                mapOf(
                    "url"          to (w.url?.toString() ?: ""),
                    "title"        to (w.title ?: ""),
                    "loading"      to false,
                    "canGoBack"    to w.canGoBack(),
                    "canGoForward" to w.canGoForward()
                )
            )
        }

        override fun onReceivedError(
            view: WebView?,
            request: WebResourceRequest?,
            error: WebResourceError?
        ) {
            super.onReceivedError(view, request, error)
            if (request?.isForMainFrame != true) return
            emitEvent(
                "error",
                mapOf(
                    "description" to (error?.description?.toString() ?: "unknown"),
                    "code"        to (error?.errorCode ?: -1)
                )
            )
        }
    }

    // --- Props ---

    @LynxProp(name = "uri")
    fun setUri(value: String) {
        uri = value
        applyContent()
    }

    @LynxProp(name = "html")
    fun setHtml(value: String) {
        html = value
        applyContent()
    }

    @LynxProp(name = "baseUrl")
    fun setBaseUrl(value: String) {
        baseUrl = value
        applyContent()
    }

    @LynxProp(name = "injectedJavaScript")
    fun setInjectedJavaScript(value: String) {
        injectedJs = value.ifEmpty { null }
    }

    @LynxProp(name = "injectedJavaScriptBeforeContentLoaded")
    fun setInjectedJavaScriptBeforeContentLoaded(value: String) {
        injectedJsBeforeLoad = value.ifEmpty { null }
    }

    @LynxProp(name = "javaScriptEnabled")
    fun setJavaScriptEnabled(value: Boolean) {
        javaScriptEnabled = value
        if (::webView.isInitialized) {
            webView.settings.javaScriptEnabled = value
        }
    }

    @LynxProp(name = "messagingEnabled")
    fun setMessagingEnabled(value: Boolean) {
        messagingEnabled = value
    }

    @LynxProp(name = "userAgent")
    fun setUserAgent(value: String) {
        userAgent = value.ifEmpty { null }
        if (::webView.isInitialized) {
            webView.settings.userAgentString = userAgent ?: DEFAULT_UA
        }
    }

    // --- Layout ---

    override fun onLayoutUpdated() {
        super.onLayoutUpdated()
        val pt = mPaddingTop + mBorderTopWidth
        val pb = mPaddingBottom + mBorderBottomWidth
        val pl = mPaddingLeft + mBorderLeftWidth
        val pr = mPaddingRight + mBorderRightWidth
        mView.setPadding(pl, pt, pr, pb)
        if (::webView.isInitialized) webView.requestLayout()
    }

    // --- UI Methods ---

    @LynxUIMethod
    fun reload(params: ReadableMap?, callback: Callback) {
        mainHandler.post { webView.reload(); callback.invoke(LynxUIMethodConstants.SUCCESS) }
    }

    @LynxUIMethod
    fun goBack(params: ReadableMap?, callback: Callback) {
        mainHandler.post {
            if (webView.canGoBack()) webView.goBack()
            callback.invoke(LynxUIMethodConstants.SUCCESS)
        }
    }

    @LynxUIMethod
    fun goForward(params: ReadableMap?, callback: Callback) {
        mainHandler.post {
            if (webView.canGoForward()) webView.goForward()
            callback.invoke(LynxUIMethodConstants.SUCCESS)
        }
    }

    /** Inject and execute arbitrary JS at any time. */
    @LynxUIMethod
    fun injectJavaScript(params: ReadableMap?, callback: Callback) {
        val script = params?.getString("script")
        if (script.isNullOrEmpty()) {
            callback.invoke(LynxUIMethodConstants.PARAM_INVALID, "missing script")
            return
        }
        mainHandler.post {
            webView.evaluateJavascript(script) { _ ->
                callback.invoke(LynxUIMethodConstants.SUCCESS)
            }
        }
    }

    /** Send a message to the page — the page receives it as a `message` event on `window`. */
    @LynxUIMethod
    fun postMessage(params: ReadableMap?, callback: Callback) {
        val data = params?.getString("data")
        if (data == null) {
            callback.invoke(LynxUIMethodConstants.PARAM_INVALID, "missing data")
            return
        }
        val escaped = JSONObject.quote(data)
        val script = """
            (function() {
              var data = $escaped;
              try {
                window.dispatchEvent(new MessageEvent('message', { data: data }));
              } catch(e) {
                var evt = document.createEvent('MessageEvent');
                evt.initMessageEvent('message', true, true, data, '', '', window, null);
                window.dispatchEvent(evt);
              }
            })();
        """.trimIndent()
        mainHandler.post {
            webView.evaluateJavascript(script, null)
            callback.invoke(LynxUIMethodConstants.SUCCESS)
        }
    }

    @LynxUIMethod
    fun loadUrl(params: ReadableMap?, callback: Callback) {
        val url = params?.getString("url")
        if (url.isNullOrEmpty()) {
            callback.invoke(LynxUIMethodConstants.PARAM_INVALID, "missing url")
            return
        }
        mainHandler.post { webView.loadUrl(url); callback.invoke(LynxUIMethodConstants.SUCCESS) }
    }

    @LynxUIMethod
    fun stopLoading(params: ReadableMap?, callback: Callback) {
        mainHandler.post { webView.stopLoading(); callback.invoke(LynxUIMethodConstants.SUCCESS) }
    }
}

private class TamerWebBridge(private val element: TamerWebViewElement) {
    @JavascriptInterface
    fun postMessage(message: String) {
        element.dispatchMessageFromPage(message)
    }
}
