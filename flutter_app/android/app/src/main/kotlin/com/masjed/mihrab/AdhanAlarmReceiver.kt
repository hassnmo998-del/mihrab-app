package com.masjed.mihrab

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File

class AdhanAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanAlarmReceiver"
        const val LIVE_NOTIFICATION_CHANNEL_ID = "mihrab_adhan_live"
        const val LIVE_NOTIFICATION_ID = 1009

        private var activePlayer: MediaPlayer? = null
        private var activeWakeLock: PowerManager.WakeLock? = null

        fun stopAdhan(context: Context) {
            try {
                activePlayer?.let { player ->
                    if (player.isPlaying) {
                        player.stop()
                    }
                    player.release()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping active player", e)
            } finally {
                activePlayer = null
            }

            try {
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(LIVE_NOTIFICATION_ID)
            } catch (e: Exception) {}

            try {
                activeWakeLock?.let { wl ->
                    if (wl.isHeld) {
                        wl.release()
                    }
                }
            } catch (e: Exception) {} finally {
                activeWakeLock = null
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Received broadcast action: $action")

        if (action == AdhanAlarmManager.ACTION_SILENCE_ADHAN) {
            stopAdhan(context)
            MainActivity.channel?.invokeMethod("silenceAdhan", null)
            return
        }

        if (action == AdhanAlarmManager.ACTION_PRAYER_ALARM) {
            val prayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
            val triggerTime = intent.getLongExtra("trigger_time", 0L)
            handlePrayerArrival(context, prayerName, triggerTime)
        }
    }

    private fun handlePrayerArrival(context: Context, prayerName: String, triggerTime: Long) {
        // 1. Acquire WakeLock to keep CPU running while Adhan plays
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Mihrab:AdhanFiringWakeLock"
        )
        wakeLock.acquire(5 * 60 * 1000L) // 5 minutes max
        activeWakeLock = wakeLock

        // 2. Check Flutter SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val masterEnabled = prefs.getBoolean("flutter.adhan_master_enabled", false)
        val prayerEnabled = prefs.getBoolean("flutter.adhan_prayer_$prayerName", true)

        if (!masterEnabled || !prayerEnabled) {
            Log.d(TAG, "Adhan for $prayerName is disabled (master: $masterEnabled, prayer: $prayerEnabled). Skipping playback.")
            wakeLock.release()
            activeWakeLock = null
            return
        }

        // 3. Stop any existing playback
        stopAdhan(context)
        activeWakeLock = wakeLock

        // 4. Start Media Playback
        try {
            var player: MediaPlayer? = null
            val soundPath = prefs.getString("flutter.adhan_selected_sound_path", null)

            if (!soundPath.isNullOrEmpty() && File(soundPath).exists()) {
                try {
                    player = MediaPlayer().apply {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build()
                        )
                        setDataSource(soundPath)
                        prepare()
                    }
                    Log.d(TAG, "Loaded custom downloaded sound from $soundPath")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to load custom sound, falling back to bundled default", e)
                    player = null
                }
            }

            if (player == null) {
                player = MediaPlayer.create(context, R.raw.adhan_default).apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                }
                Log.d(TAG, "Loaded bundled default adhan from R.raw.adhan_default")
            }

            // Set configured volume
            val volumeDouble = try {
                prefs.getFloat("flutter.adhan_volume", 1.0f)
            } catch (e: Exception) {
                1.0f
            }.coerceIn(0.0f, 1.0f)

            player.setVolume(volumeDouble, volumeDouble)
            player.isLooping = false

            player.setOnCompletionListener {
                Log.d(TAG, "Adhan playback completed naturally")
                stopAdhan(context)
                MainActivity.channel?.invokeMethod("onAdhanCompleted", prayerName)
            }

            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                stopAdhan(context)
                true
            }

            player.start()
            activePlayer = player

            // 5. Post Heads-Up Live Firing Notification
            postLiveFiringNotification(context, prayerName)

            // 6. Notify Flutter Engine if app is active
            MainActivity.channel?.invokeMethod("onAdhanStarted", prayerName)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Adhan playback", e)
            stopAdhan(context)
        }
    }

    private fun postLiveFiringNotification(context: Context, prayerName: String) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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
            notificationManager.createNotificationChannel(channel)
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

        val builder = NotificationCompat.Builder(context, LIVE_NOTIFICATION_CHANNEL_ID)
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

        notificationManager.notify(LIVE_NOTIFICATION_ID, builder.build())
    }
}
