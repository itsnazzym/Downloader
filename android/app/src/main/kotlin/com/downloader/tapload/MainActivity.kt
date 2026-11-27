package com.downloader.tapload

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionsChannel = "tapload/permissions"
    private val permissionsRequestCode = 901
    private var pendingPermissionsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EnginePlugin.register(this, flutterEngine)
        SharePlugin.register(flutterEngine)
        SnifferPlugin.register(flutterEngine)
        SharePlugin.handleIntent(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannel)
            .setMethodCallHandler(::handlePermissionsCall)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        SharePlugin.handleIntent(intent)
    }

    private fun handlePermissionsCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "ensureRuntimePermissions") {
            result.notImplemented()
            return
        }

        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            permissions.add(Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(null)
            return
        }

        pendingPermissionsResult = result
        ActivityCompat.requestPermissions(this, missing.toTypedArray(), permissionsRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionsRequestCode) {
            pendingPermissionsResult?.success(null)
            pendingPermissionsResult = null
        }
    }
}
