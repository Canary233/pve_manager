package com.canary233.PVEManager.pve_manager

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pve_manager/remote_console"
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val url = call.argument<String>("url")
            val fallbackTitle = call.argument<String>("fallbackTitle") ?: "Console"
            val title = call.argument<String>("title") ?: fallbackTitle
            val cookieDomain = call.argument<String>("cookieDomain")
            val authCookie = call.argument<String>("authCookie")
            val ignoreCertificateErrors =
                call.argument<Boolean>("ignoreCertificateErrors") ?: false
            val invalidArgumentsMessage =
                call.argument<String>("invalidArgumentsMessage") ?: "Invalid console arguments."

            if (url.isNullOrBlank() || cookieDomain.isNullOrBlank() || authCookie.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", invalidArgumentsMessage, null)
                return@setMethodCallHandler
            }

            val intent = Intent(this, RemoteConsoleActivity::class.java).apply {
                putExtra(RemoteConsoleActivity.EXTRA_TITLE, title)
                putExtra(RemoteConsoleActivity.EXTRA_URL, url)
                putExtra(RemoteConsoleActivity.EXTRA_COOKIE_DOMAIN, cookieDomain)
                putExtra(RemoteConsoleActivity.EXTRA_AUTH_COOKIE, authCookie)
                putExtra(
                    RemoteConsoleActivity.EXTRA_LOAD_FAILED_TEMPLATE,
                    call.argument<String>("loadFailedTemplate")
                )
                putExtra(
                    RemoteConsoleActivity.EXTRA_UNKNOWN_ERROR_MESSAGE,
                    call.argument<String>("unknownErrorMessage")
                )
                putExtra(
                    RemoteConsoleActivity.EXTRA_CERTIFICATE_ERROR_MESSAGE,
                    call.argument<String>("certificateErrorMessage")
                )
                putExtra(RemoteConsoleActivity.EXTRA_ERROR_HINT, call.argument<String>("errorHint"))
                putExtra(
                    RemoteConsoleActivity.EXTRA_IGNORE_CERTIFICATE_ERRORS,
                    ignoreCertificateErrors
                )
            }
            startActivity(intent)
            result.success(null)
        }
    }
}
