package com.example.text_to_voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the [SynthesisService] bridge.
 *
 * The service owns the notification and the wake lock; the only reason a
 * `MethodChannel` exists here is that Android offers no way for a service to call
 * into Dart. Progress travels Dart → Kotlin. The notification's Stop button
 * travels Kotlin → Dart: [SynthesisService] raises a static callback, and this
 * activity is what wires that callback to the live engine, because the Dart side
 * is the only thing that knows how to abandon a run without losing the audio that
 * has already been produced.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "text_to_voice/synthesis"

        /**
         * Where the notification-permission request is identified in
         * `onRequestPermissionsResult`. Any value works; 4202 matches the
         * service's notification id's family so it is greppable.
         */
        private const val NOTIFICATIONS_REQUEST = 4202

        @Volatile
        var onNotificationPermissionResult: ((Boolean) -> Unit)? = null

        /**
         * Held so the static stop callback has a way to reach Dart.
         *
         * Cleared in [onDestroy]: leaving it set would let a service that outlives
         * the screen call into an engine that is going away, which crashes rather
         * than merely failing.
         */
        @Volatile
        private var channel: MethodChannel? = null

        @Volatile
        private var appContext: Context? = null

        private fun onStopFromNotification() {
            // Called on the main thread by the service's stop action.
            channel?.invokeMethod("stopRequested", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appContext = applicationContext

        val methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = methodChannel

        // Dart owns the "stop" decision: it keeps the finished audio and lets the
        // run resume from the cache later.
        SynthesisService.onStopRequested = { onStopFromNotification() }

        methodChannel.setMethodCallHandler { call, result ->
            val context = appContext
            if (context == null) {
                result.error("no_context", "Activity chưa sẵn sàng", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "start" -> {
                    SynthesisService.start(
                        context,
                        call.argument<Int>("done") ?: 0,
                        call.argument<Int>("total") ?: 0,
                    )
                    result.success(null)
                }

                "progress" -> {
                    SynthesisService.showProgress(
                        context,
                        call.argument<Int>("done") ?: 0,
                        call.argument<Int>("total") ?: 0,
                    )
                    result.success(null)
                }

                "finished" -> {
                    SynthesisService.finish(context)
                    result.success(null)
                }

                "stop" -> {
                    SynthesisService.stop(context)
                    result.success(null)
                }

                "requestNotifications" -> {
                    result.success(requestNotifications())
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Asks for the notification permission when the platform requires one.
     *
     * A foreground service runs either way, but from API 33 its notification —
     * the only place the reader can see progress or stop a long run — is hidden
     * until the user allows it. Without this the app would generate audio
     * invisibly and offer no way out of it, which is precisely the state the
     * foreground service exists to prevent.
     *
     * Returns the current answer: `true` when notifications may be posted (or
     * the platform predates the permission), `false` while the dialog is up or
     * after a refusal. A refusal is not an error — the run continues; it is
     * only less visible.
     */
    private fun requestNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return true
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATIONS_REQUEST,
        )
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATIONS_REQUEST) return
        onNotificationPermissionResult?.invoke(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    override fun onDestroy() {
        // Progress must not keep arriving at a destroyed engine.
        channel?.setMethodCallHandler(null)
        channel = null
        SynthesisService.onStopRequested = null
        onNotificationPermissionResult = null
        super.onDestroy()
    }
}