package com.masjed.mihrab

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

object PrayerNotificationManager {
    const val CHANNEL_ID = "mihrab_prayer_tracker"
    const val NOTIFICATION_ID = 1002

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "مواقيت الصلاة ومتابعة الإقامة"
            val descriptionText = "شريط متابعة الصلاة القادمة والإقامة بشكل دائم"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showCustomNotification(
        context: Context,
        targetEpochMillis: Long,
        isIqamaPhase: Boolean,
        isLiveFiring: Boolean,
        adhanTimeStr: String,
        iqamaTimeStr: String,
        badgeText: String,
        subtitleText: String,
        smallTimesSummary: String
    ) {
        createNotificationChannel(context)

        val smallViews = RemoteViews(context.packageName, R.layout.notification_prayer_small)
        val bigViews = RemoteViews(context.packageName, R.layout.notification_prayer_big)

        // Select background drawable based on phase
        val bgDrawable = when {
            isLiveFiring -> R.drawable.bg_prayer_card_live
            isIqamaPhase -> R.drawable.bg_prayer_card_iqama
            else -> R.drawable.bg_prayer_card_normal
        }
        smallViews.setInt(R.id.cardBackgroundSmall, "setBackgroundResource", bgDrawable)
        bigViews.setInt(R.id.cardBackground, "setBackgroundResource", bgDrawable)

        // Set Texts
        smallViews.setTextViewText(R.id.smallBadgeText, badgeText)
        smallViews.setTextViewText(R.id.smallTimesSummary, smallTimesSummary)

        bigViews.setTextViewText(R.id.badgeText, badgeText)
        bigViews.setTextViewText(R.id.countdownSubtitle, subtitleText)
        bigViews.setTextViewText(R.id.chipAdhanTime, adhanTimeStr)
        bigViews.setTextViewText(R.id.chipIqamaTime, iqamaTimeStr)

        if (isIqamaPhase) {
            bigViews.setTextViewText(R.id.chipIqamaLabel, "وقت الإقامة 🕌")
        } else {
            bigViews.setTextViewText(R.id.chipIqamaLabel, "الإقامة المتوقعة ⏳")
        }

        // Live Silence Button Visibility
        bigViews.setViewVisibility(
            R.id.liveSilenceContainer,
            if (isLiveFiring) View.VISIBLE else View.GONE
        )

        // Configure Chronometer CountDown
        val now = System.currentTimeMillis()
        val remaining = (targetEpochMillis - now).coerceAtLeast(0)
        val chronometerBase = SystemClock.elapsedRealtime() + remaining

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            smallViews.setChronometerCountDown(R.id.smallCountdownChronometer, true)
            bigViews.setChronometerCountDown(R.id.countdownChronometer, true)
        }
        smallViews.setChronometer(R.id.smallCountdownChronometer, chronometerBase, null, true)
        bigViews.setChronometer(R.id.countdownChronometer, chronometerBase, null, true)

        // PendingIntent to Open App on Notification Click
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.masjed.mihrab.OPEN_PRAYER_TIMES"
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // PendingIntent for Silence Button
        val silenceIntent = Intent(context, PrayerNotificationReceiver::class.java).apply {
            action = "com.masjed.mihrab.ACTION_SILENCE_ADHAN"
        }
        val silencePendingIntent = PendingIntent.getBroadcast(
            context,
            1003,
            silenceIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        bigViews.setOnClickPendingIntent(R.id.btnSilenceAdhan, silencePendingIntent)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(smallViews)
            .setCustomBigContentView(bigViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    fun cancelNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
