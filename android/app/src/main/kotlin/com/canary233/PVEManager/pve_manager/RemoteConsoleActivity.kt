package com.canary233.PVEManager.pve_manager

import android.annotation.SuppressLint
import android.app.Activity
import android.net.http.SslError
import android.os.Bundle
import android.os.Message
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.SslErrorHandler
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

class RemoteConsoleActivity : Activity() {
    private val webViews = mutableListOf<WebView>()
    private lateinit var content: FrameLayout
    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var errorText: TextView
    private var ignoreCertificateErrors = false
    private lateinit var loadFailedTemplate: String
    private lateinit var unknownErrorMessage: String
    private lateinit var certificateErrorMessage: String
    private lateinit var errorHint: String

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Console"
        val url = intent.getStringExtra(EXTRA_URL) ?: ""
        val authCookie = intent.getStringExtra(EXTRA_AUTH_COOKIE) ?: ""
        loadFailedTemplate =
            intent.getStringExtra(EXTRA_LOAD_FAILED_TEMPLATE)
                ?: "Console failed to load: {description}"
        unknownErrorMessage =
            intent.getStringExtra(EXTRA_UNKNOWN_ERROR_MESSAGE) ?: "Unknown error"
        certificateErrorMessage =
            intent.getStringExtra(EXTRA_CERTIFICATE_ERROR_MESSAGE)
                ?: "Console certificate verification failed."
        errorHint =
            intent.getStringExtra(EXTRA_ERROR_HINT)
                ?: "Tap the title bar to return, or use the system back button."
        ignoreCertificateErrors =
            intent.getBooleanExtra(EXTRA_IGNORE_CERTIFICATE_ERRORS, false)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xff000000.toInt())
        }
        val toolbar = TextView(this).apply {
            text = title
            setTextColor(0xffffffff.toInt())
            textSize = 18f
            gravity = Gravity.CENTER_VERTICAL
            setPadding(36, 0, 36, 0)
            setBackgroundColor(0xff202124.toInt())
            setOnClickListener { finish() }
        }
        progressBar = ProgressBar(
            this,
            null,
            android.R.attr.progressBarStyleHorizontal
        ).apply {
            max = 100
            visibility = View.VISIBLE
        }
        content = FrameLayout(this)
        webView = createConsoleWebView()
        webViews.add(webView)
        errorText = TextView(this).apply {
            visibility = View.GONE
            gravity = Gravity.CENTER
            textSize = 15f
            setTextColor(0xffffffff.toInt())
            setPadding(48, 48, 48, 48)
            setBackgroundColor(0xff202124.toInt())
        }

        content.addView(
            webView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        content.addView(
            errorText,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        root.addView(
            toolbar,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56)
            )
        )
        root.addView(
            progressBar,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(3)
            )
        )
        root.addView(
            content,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        )
        setContentView(root)

        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            setAcceptThirdPartyCookies(webView, true)
            setCookie(url, "PVEAuthCookie=$authCookie; Path=/; Secure") {
                flush()
                runOnUiThread {
                    webView.loadUrl(url)
                }
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun createConsoleWebView(): WebView {
        return WebView(this).apply {
            settings.apply {
                javaScriptEnabled = true
                javaScriptCanOpenWindowsAutomatically = true
                setSupportMultipleWindows(true)
                domStorageEnabled = true
                databaseEnabled = true
                loadsImagesAutomatically = true
                useWideViewPort = true
                loadWithOverviewMode = true
                builtInZoomControls = true
                displayZoomControls = false
                cacheMode = WebSettings.LOAD_DEFAULT
                mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                textZoom = 100
            }
            isFocusable = true
            isFocusableInTouchMode = true
            requestFocus()
            webChromeClient = consoleChromeClient()
            webViewClient = consoleWebViewClient()
        }
    }

    private fun consoleChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progressBar.progress = newProgress
                progressBar.visibility = if (newProgress in 1..99) {
                    View.VISIBLE
                } else {
                    View.GONE
                }
            }

            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                val popup = createConsoleWebView()
                CookieManager.getInstance().setAcceptThirdPartyCookies(popup, true)
                attachWebView(popup)
                val transport = resultMsg?.obj as? WebView.WebViewTransport
                    ?: return false
                transport.webView = popup
                resultMsg.sendToTarget()
                return true
            }

            override fun onCloseWindow(window: WebView?) {
                if (window != null) {
                    detachWebView(window)
                }
            }
        }
    }

    private fun consoleWebViewClient(): WebViewClient {
        return object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                errorText.visibility = View.GONE
                progressBar.visibility = View.VISIBLE
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                if (request?.isForMainFrame != true) {
                    return
                }
                val description = error?.description?.toString() ?: unknownErrorMessage
                showError(loadFailedTemplate.replace("{description}", description))
            }

            override fun onReceivedSslError(
                view: WebView?,
                handler: SslErrorHandler?,
                error: SslError?
            ) {
                if (ignoreCertificateErrors) {
                    handler?.proceed()
                    return
                }

                handler?.cancel()
                showError(certificateErrorMessage)
            }
        }
    }

    private fun attachWebView(next: WebView) {
        webViews.lastOrNull()?.visibility = View.GONE
        webViews.add(next)
        webView = next
        val errorIndex = content.indexOfChild(errorText).takeIf { it >= 0 } ?: content.childCount
        content.addView(
            next,
            errorIndex,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        next.visibility = View.VISIBLE
        next.requestFocus()
    }

    private fun detachWebView(target: WebView) {
        if (!webViews.remove(target)) {
            return
        }
        content.removeView(target)
        target.destroy()
        val previous = webViews.lastOrNull()
        if (previous != null) {
            webView = previous
            previous.visibility = View.VISIBLE
            previous.requestFocus()
        }
    }

    override fun onBackPressed() {
        if (this::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else if (webViews.size > 1) {
            detachWebView(webView)
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        for (view in webViews.toList()) {
            content.removeView(view)
            view.destroy()
        }
        webViews.clear()
        super.onDestroy()
    }

    private fun showError(message: String) {
        errorText.text = "$message\n\n$errorHint"
        errorText.visibility = View.VISIBLE
        progressBar.visibility = View.GONE
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_URL = "url"
        const val EXTRA_COOKIE_DOMAIN = "cookieDomain"
        const val EXTRA_AUTH_COOKIE = "authCookie"
        const val EXTRA_IGNORE_CERTIFICATE_ERRORS = "ignoreCertificateErrors"
        const val EXTRA_LOAD_FAILED_TEMPLATE = "loadFailedTemplate"
        const val EXTRA_UNKNOWN_ERROR_MESSAGE = "unknownErrorMessage"
        const val EXTRA_CERTIFICATE_ERROR_MESSAGE = "certificateErrorMessage"
        const val EXTRA_ERROR_HINT = "errorHint"
    }
}
