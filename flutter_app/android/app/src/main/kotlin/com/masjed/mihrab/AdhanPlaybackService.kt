package com.masjed.mihrab

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import java.io.File
import kotlin.math.abs

/**
 * Plays the adhan from a foreground service.
 *
 * The alarm receiver used to start the MediaPlayer itself. Once onReceive returns, a
 * closed app has nothing keeping its process alive, so the system was free to freeze or
 * kill it and the adhan was cut short or never heard. A foreground service keeps the
 * process running until the adhan ends or the user silences it.
 */
class AdhanPlaybackService : Service() {
    companion object {
        private const val TAG = "AdhanPlaybackService"
        const val LIVE_NOTIFICATION_CHANNEL_ID = "mihrab_adhan_live"
        const val LIVE_NOTIFICATION_ID = 1009

        private const val EXTRA_PRAYER_NAME = "prayer_name"
        // The alarm and the in-app ticker both announce the same prayer: play it once
        private const val SAME_PRAYER_WINDOW_MS = 10 * 60 * 1000L

        private var instance: AdhanPlaybackService? = null
        private var lastPrayerName: String? = null
        private var lastTriggerTime = 0L
        // stop() arrived before the service came up
        private var cancelPending = false

        fun start(context: Context, prayerName: String, triggerTime: Long) {
            if (prayerName == lastPrayerName && abs(triggerTime - lastTriggerTime) < SAME_PRAYER_WINDOW_MS) {
                Log.d(TAG, "Adhan for $prayerName was already started, ignoring the duplicate")
                return
            }
            lastPrayerName = prayerName
            lastTriggerTime = triggerTime
            cancelPending = false

            // Keeps the CPU awake between the alarm broadcast returning and the service starting
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Mihrab:AdhanStartWakeLock")
                .acquire(10 * 1000L)

            val intent = Intent(context, AdhanPlaybackService::class.java)
                .putExtra(EXTRA_PRAYER_NAME, prayerName)
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (e: Exception) {
                // Android 12+ refuses a foreground service from the background when the alarm
                // was inexact (exact alarms denied): play without one rather than stay silent
                Log.w(TAG, "Foreground service refused, playing the adhan without it", e)
                val appContext = context.applicationContext
                val started = AdhanPlayer.play(appContext) {
                    notificationManager(appContext).cancel(LIVE_NOTIFICATION_ID)
                    MainActivity.channel?.invokeMethod("onAdhanCompleted", prayerName)
                }
                if (started) {
                    try {
                        notificationManager(appContext)
                            .notify(LIVE_NOTIFICATION_ID, buildLiveNotification(appContext, prayerName))
                    } catch (_: SecurityException) {}
                    MainActivity.channel?.invokeMethod("onAdhanStarted", prayerName)
                }
            }
        }

        fun stop(context: Context) {
            AdhanPlayer.stop()
            notificationManager(context).cancel(LIVE_NOTIFICATION_ID)
            val service = instance
            if (service != null) service.finish() else cancelPending = true
        }

        private fun notificationManager(context: Context) =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        private fun buildLiveNotification(context: Context, prayerName: String): Notification {
            // Create Channel for Android 8.0+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    LIVE_NOTIFICATION_CHANNEL_ID,
                    "أذان الصلاة الحي المباشر",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "تنبيه إطلاق الأذان الصوتي في الوقت الفعلي للصلاة"
                    enableVibration(true)
                    setShowBadge(true)
                    setSound(null, null) // Sound is handled by our MediaPlayer directly for full control
                }
                notificationManager(context).createNotificationChannel(channel)
            }

            // Open App Intent
            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.masjed.mihrab.OPEN_PRAYER_TIMES"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context,
                LIVE_NOTIFICATION_ID,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Silence Intent
            val silenceIntent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = AdhanAlarmManager.ACTION_SILENCE_ADHAN
            }
            val silencePendingIntent = PendingIntent.getBroadcast(
                context,
                LIVE_NOTIFICATION_ID + 1,
                silenceIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            return NotificationCompat.Builder(context, LIVE_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("حان الآن موعد أذان $prayerName 🕌")
                .setContentText("يصدح الآن أذان $prayerName في منصة محراب")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(false)
                .setOngoing(true)
                .setContentIntent(openPendingIntent)
                .setFullScreenIntent(openPendingIntent, true)
                .addAction(
                    R.drawable.bg_silence_btn,
                    "إسكات الأذان 🔇",
                    silencePendingIntent
                )
                .addAction(
                    R.drawable.bg_time_chip,
                    "فتح محراب 🕌",
                    openPendingIntent
                )
                .build()
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"

        // Must come first: a foreground service that does not show its notification
        // within seconds of being started takes the whole app down
        val notification = buildLiveNotification(this, prayerName)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    LIVE_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(LIVE_NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not enter the foreground", e)
        }

        if (intent == null || cancelPending) {
            finish()
            return START_NOT_STICKY
        }

        val started = AdhanPlayer.play(this) {
            Log.d(TAG, "Adhan playback finished")
            MainActivity.channel?.invokeMethod("onAdhanCompleted", prayerName)
            finish()
        }
        if (started) {
            // Notify Flutter Engine if app is active
            MainActivity.channel?.invokeMethod("onAdhanStarted", prayerName)
        } else {
            finish()
        }
        return START_NOT_STICKY
    }

    private fun finish() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        AdhanPlayer.stop()
        if (instance === this) instance = null
        super.onDestroy()
    }
}

/** The MediaPlayer sounding the adhan, and the wake lock held while it plays. */
private object AdhanPlayer {
    private const val TAG = "AdhanPlayer"
    // shared_preferences stores a Dart double as a string behind this prefix
    private const val FLUTTER_DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    /** Starts the selected adhan. [onFinished] runs when it ends on its own, not on [stop]. */
    fun play(context: Context, onFinished: () -> Unit): Boolean {
        stop()
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val mediaPlayer = open(context, prefs.getString("flutter.adhan_selected_sound_path", null))
        if (mediaPlayer == null) {
            Log.e(TAG, "No adhan sound could be loaded")
            return false
        }

        val volume = try {
            prefs.getString("flutter.adhan_volume", null)
                ?.removePrefix(FLUTTER_DOUBLE_PREFIX)?.toFloatOrNull()
        } catch (e: ClassCastException) {
            null
        }?.coerceIn(0.0f, 1.0f) ?: 1.0f

        return try {
            mediaPlayer.setVolume(volume, volume)
            mediaPlayer.isLooping = false
            mediaPlayer.setOnCompletionListener {
                stop()
                onFinished()
            }
            mediaPlayer.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                stop()
                onFinished()
                true
            }

            // Keep the CPU running with the screen off until the adhan ends
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Mihrab:AdhanFiringWakeLock")
                .apply { acquire(10 * 60 * 1000L) }

            mediaPlayer.start()
            player = mediaPlayer
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Adhan playback", e)
            mediaPlayer.release()
            stop()
            false
        }
    }

    fun stop() {
        try {
            player?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping active player", e)
        } finally {
            player = null
        }

        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (e: Exception) {
        } finally {
            wakeLock = null
        }
    }

    /** The downloaded sound the user picked, else the adhan bundled in the APK. */
    private fun open(context: Context, soundPath: String?): MediaPlayer? {
        if (!soundPath.isNullOrEmpty() && File(soundPath).exists()) {
            prepare { setDataSource(soundPath) }?.let { return it }
            Log.w(TAG, "Failed to load custom sound, falling back to bundled default")
        }
        return prepare {
            context.resources.openRawResourceFd(R.raw.adhan_default).use { fd ->
                setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            }
        }
    }

    private fun prepare(setSource: MediaPlayer.() -> Unit): MediaPlayer? {
        val mediaPlayer = MediaPlayer()
        return try {
            // Alarm stream, so the adhan is heard with media volume down. Only takes
            // effect when set before prepare().
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            mediaPlayer.setSource()
            mediaPlayer.prepare()
            mediaPlayer
        } catch (e: Exception) {
            Log.w(TAG, "Could not prepare the adhan sound", e)
            mediaPlayer.release()
            null
        }
    }
}
