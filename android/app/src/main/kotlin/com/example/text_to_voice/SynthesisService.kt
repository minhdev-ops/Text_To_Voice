package com.example.text_to_voice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Keeps speech generation alive while the app is not in front.
 *
 * ## Why this is hand-written instead of a package
 *
 * `flutter_background_service` is the usual answer, but it ships **no license at
 * all** — no LICENSE file, nothing declared in its pubspec. Absent a license that
 * means all rights reserved, so it cannot be shipped in a product. This file is
 * this project's own code and carries no such dependency.
 *
 * ## Why it is enough
 *
 * The expensive part of generation is Dart: the ONNX autoregressive decoder runs
 * in a worker isolate inside this app's process. Android only reclaims a process
 * that holds no foreground service, so promoting this process with
 * `startForeground` is what keeps that isolate running — there is no second
 * engine, no isolate hand-off, and nothing to re-bootstrap after a restart.
 *
 * ## What it does *not* promise
 *
 * A foreground service survives the app being backgrounded or closed with the
 * Back button. It cannot survive the user force-stopping the app or some
 * manufacturers' battery managers killing it. That limit is why generation is
 * resumable through the `tts_audio` cache rather than treated as one
 * all-or-nothing job: whatever the process manages to finish is kept, and the
 * rest continues next time.
 */
class SynthesisService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Stop the *work*, not just the notification: the Dart side keeps the
            // audio it has already produced, and the run resumes from the cache.
            onStopRequested?.invoke()
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent == null) {
            // A sticky restart after the process died: there is no Dart run left
            // behind this service, and promoting it would post an orphan
            // "Đang tạo audio" notification plus a 6-hour wake lock with
            // nothing generating anything.
            stopSelf()
            return START_NOT_STICKY
        }

        val done = intent.getIntExtra(EXTRA_DONE, 0)
        val total = intent.getIntExtra(EXTRA_TOTAL, 0)

        // Promote before doing anything slow, or Android kills the process
        // between `startForegroundService` and the first `startForeground`.
        startInForeground(this, done, total)
        acquireWakeLock(this)

        // START_STICKY: if the process is reclaimed anyway, bring it back so Dart
        // can resume from the cache rather than losing the run entirely.
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The user swiped the app out of the recent-apps list. That is not the
        // same as asking to stop, so the run continues — START_STICKY plus a live
        // foreground service is what carries it past this.
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        releaseWakeLock()
        // `onStopRequested` is deliberately **not** cleared here. It is owned by
        // MainActivity, which arms it once per engine: clearing it here (as this
        // did) meant the notification's Stop button worked for the first run of
        // the app and silently did nothing for every run after it — the service
        // stopped but Dart never learned it should.
        super.onDestroy()
    }

    companion object {
        const val CHANNEL_ID = "synthesis"
        const val NOTIFICATION_ID = 4201
        const val ACTION_STOP = "com.example.text_to_voice.STOP_SYNTHESIS"
        const val EXTRA_DONE = "done"
        const val EXTRA_TOTAL = "total"

        /**
         * Generous ceiling: a 500-page document can legitimately take hours, and
         * this lock exists to survive the screen going off, not to defend against a
         * runaway. The Dart side cancels explicitly.
         */
        const val MAX_WAKE_LOCK_MS = 6L * 60L * 60L * 1000L

        /**
         * Set by Dart so the notification's Stop button can reach it.
         *
         * A static is the honest choice here and nowhere else in this app: the
         * notification is built by the OS-owned service while the work is done in
         * a Dart isolate, and those two Android components share no instance.
         */
        @Volatile
        var onStopRequested: (() -> Unit)? = null

        @Volatile
        private var wakeLock: PowerManager.WakeLock? = null

        fun start(context: Context, done: Int, total: Int) {
            val intent = Intent(context, SynthesisService::class.java).apply {
                // Extras must be attached *before* the start call, or the service
                // is already running and the progress it shows would start blank.
                putExtra(EXTRA_DONE, done)
                putExtra(EXTRA_TOTAL, total)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SynthesisService::class.java))
        }

        /**
         * Repaints the progress notification.
         *
         * Static and [Context]-only so Dart can call it from anywhere without the
         * activity holding a reference to a service instance it cannot reach.
         */
        fun showProgress(context: Context, done: Int, total: Int) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(context, done, total))
        }

        /** Removes the notification, releases the wake lock and stops the service. */
        fun finish(context: Context) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
            releaseWakeLock()
            // The service itself has to go too: cancelling the notification left
            // a `dataSync` foreground service running for the rest of the app's
            // life (eating Android 15's daily dataSync budget), and a later
            // sticky restart had nothing to stop it.
            context.stopService(Intent(context, SynthesisService::class.java))
        }

        private fun startInForeground(context: Context, done: Int, total: Int) {
            val notification = buildNotification(context, done, total)
            val service = context as? Service ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                service.startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                service.startForeground(NOTIFICATION_ID, notification)
            }
        }

        private fun buildNotification(context: Context, done: Int, total: Int): Notification {
            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_IMMUTABLE,
            )

            val stop = PendingIntent.getService(
                context,
                1,
                Intent(context, SynthesisService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_IMMUTABLE,
            )

            val title =
                if (total > 0) "Đang tạo audio · $done/$total câu" else "Đang tạo audio"

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText("Có thể đóng app — vẫn tạo tiếp")
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentIntent(openApp)
                .addAction(0, "Dừng", stop)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(total, done.coerceAtMost(total), total <= 0)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        }

        /**
         * ONNX inference on a phone is long-running CPU work with the screen off, so
         * the CPU would otherwise sleep mid-sentence. Held for the life of the
         * service and released in [finish]/[onDestroy] — a leaked wake lock would
         * keep the device awake with nothing running.
         */
        private fun acquireWakeLock(context: Context) {
            if (wakeLock?.isHeld == true) return
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "TextToVoice:Synthesis")
                .apply {
                    setReferenceCounted(false)
                    acquire(MAX_WAKE_LOCK_MS)
                }
        }

        private fun releaseWakeLock() {
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
        }

        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // LOW importance: this is a progress indicator, not something to
            // interrupt someone over.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Tạo giọng nói",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Tiến trình tạo audio cho tài liệu"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }
}