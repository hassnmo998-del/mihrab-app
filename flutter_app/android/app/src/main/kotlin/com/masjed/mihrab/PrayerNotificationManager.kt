package com.masjed.mihrab

import android.app.AlarmManager
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
import org.json.JSONArray
import java.util.Calendar

/**
 * شريط مواقيت الصلاة الدائم في الإشعارات.
 *
 * يعمل وحده دون Flutter: التطبيق يرسل جدول الأسبوعين القادمين (أذان وإقامة كل صلاة)
 * عبر [sync]، وهنا نحسب المرحلة الحالية (قبل الأذان / بين الأذان والإقامة)، ونعرض عدّاداً
 * تنازلياً، ونضبط منبّهاً دقيقاً على لحظة انتهائه فيُعاد الرسم بالمرحلة التالية. لذلك لا
 * يتجاوز العدّاد الصفر إلى السالب ولا يعلق حين يُغلق التطبيق، ويعود بعد إعادة التشغيل
 * ([AdhanBootReceiver]) وحين يمسحه المستخدم (deleteIntent).
 */
object PrayerNotificationManager {
    const val CHANNEL_ID = "mihrab_prayer_tracker"
    const val NOTIFICATION_ID = 1002
    const val ACTION_REFRESH = "com.masjed.mihrab.ACTION_REFRESH_PRAYER_NOTIFICATION"

    private const val PREFS = "mihrab_prayer_notification"
    private const val KEY_TIMELINE = "timeline_json"
    private const val KEY_ENABLED = "enabled"
    private const val REQUEST_REFRESH_ALARM = 3001
    private const val REQUEST_REPOST = 3002
    private const val SUNRISE = "الشروق"

    private data class PrayerEvent(val name: String, val adhan: Long, val iqama: Long) {
        val hasIqama get() = iqama > adhan
    }

    /** يحفظ الجدول القادم من التطبيق ثم يعيد رسم الإشعار. */
    fun sync(context: Context, timelineJson: String, enabled: Boolean) {
        prefs(context).edit()
            .putString(KEY_TIMELINE, timelineJson)
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
        refresh(context)
    }

    /** يوقف الشريط: لا يعود بعد إعادة التشغيل حتى يُفعَّل من التطبيق. */
    fun disable(context: Context) {
        prefs(context).edit().putBoolean(KEY_ENABLED, false).apply()
        cancelRefreshAlarm(context)
        notificationManager(context).cancel(NOTIFICATION_ID)
    }

    /** يرسم الإشعار بحسب اللحظة الحالية ويضبط منبّه التحديث التالي. */
    fun refresh(context: Context) {
        val prefs = prefs(context)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            cancelRefreshAlarm(context)
            notificationManager(context).cancel(NOTIFICATION_ID)
            return
        }
        val events = parse(prefs.getString(KEY_TIMELINE, null))
        val now = System.currentTimeMillis()

        // بين الأذان والإقامة لصلاة ما: العدّ نحو الإقامة
        val inIqama = events.firstOrNull { it.hasIqama && now >= it.adhan && now < it.iqama }
        // وإلا فالعدّ نحو أول حدث قادم (الشروق يُعرض ولا إقامة له)
        val upcoming = events.firstOrNull { it.adhan > now }

        createChannel(context)
        if (inIqama == null && upcoming == null) {
            // انتهى الجدول (لم يُفتح التطبيق منذ أسبوعين): رسالة ثابتة بلا عدّاد
            post(context, staleNotification(context))
            cancelRefreshAlarm(context)
            return
        }

        val isIqama = inIqama != null
        val current = inIqama ?: upcoming!!
        val target = if (isIqama) current.iqama else current.adhan
        val after = events.firstOrNull { it.adhan > current.adhan && it.name != SUNRISE }
        val day = events.filter { sameDay(it.adhan, current.adhan) }

        post(context, buildNotification(context, current, isIqama, target, after, day, now))
        scheduleRefresh(context, target)
    }

    // ─── الرسم ────────────────────────────────────────────────────────────

    private fun buildNotification(
        context: Context,
        current: PrayerEvent,
        isIqama: Boolean,
        target: Long,
        after: PrayerEvent?,
        day: List<PrayerEvent>,
        now: Long
    ): android.app.Notification {
        val small = RemoteViews(context.packageName, R.layout.notification_prayer_small)
        val big = RemoteViews(context.packageName, R.layout.notification_prayer_big)

        val bg = if (isIqama) R.drawable.bg_prayer_card_iqama else R.drawable.bg_prayer_card_normal
        small.setInt(R.id.cardBackgroundSmall, "setBackgroundResource", bg)
        big.setInt(R.id.cardBackground, "setBackgroundResource", bg)

        val name = current.name
        val title: String
        val countdownLabel: String
        val detail: String
        when {
            isIqama -> {
                title = "إقامة $name"
                countdownLabel = "متبقٍ لإقامة $name"
                detail = "الإقامة ${time(current.iqama)}" + (after?.let { " • ثم ${it.name} ${time(it.adhan)}" } ?: "")
            }
            name == SUNRISE -> {
                title = "الشروق"
                countdownLabel = "متبقٍ للشروق"
                detail = "الشروق ${time(current.adhan)}" + (after?.let { " • ثم ${it.name} ${time(it.adhan)}" } ?: "")
            }
            else -> {
                title = "أذان $name"
                countdownLabel = "متبقٍ لأذان $name"
                detail = "الأذان ${time(current.adhan)}" +
                    (if (current.hasIqama) " • الإقامة ${time(current.iqama)}" else "")
            }
        }

        small.setTextViewText(R.id.smallTitle, title)
        small.setTextViewText(R.id.smallDetail, detail)
        big.setTextViewText(R.id.bigTitle, title)
        big.setTextViewText(R.id.countdownLabel, countdownLabel)
        big.setTextViewText(R.id.bigDetail, detail)

        // العدّاد: ينتهي عند [target] تماماً، ومنبّه التحديث يستبدله بالمرحلة التالية لحظتها
        val remaining = (target - now).coerceAtLeast(0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val base = SystemClock.elapsedRealtime() + remaining
            for ((views, id) in listOf(small to R.id.smallCountdown, big to R.id.bigCountdown)) {
                views.setChronometerCountDown(id, true)
                views.setChronometer(id, base, null, true)
                views.setViewVisibility(id, View.VISIBLE)
            }
            small.setViewVisibility(R.id.smallTargetTime, View.GONE)
            big.setViewVisibility(R.id.bigTargetTime, View.GONE)
        } else {
            // أندرويد 6 وأقدم لا يعدّ تنازلياً: نعرض ساعة الموعد بدل العدّاد
            small.setViewVisibility(R.id.smallCountdown, View.GONE)
            big.setViewVisibility(R.id.bigCountdown, View.GONE)
            small.setTextViewText(R.id.smallTargetTime, time(target))
            big.setTextViewText(R.id.bigTargetTime, time(target))
            small.setViewVisibility(R.id.smallTargetTime, View.VISIBLE)
            big.setViewVisibility(R.id.bigTargetTime, View.VISIBLE)
        }

        // مواقيت اليوم الستة، والحالية مميّزة
        val cells = listOf(
            Triple(R.id.cell0, R.id.cell0Name, R.id.cell0Time),
            Triple(R.id.cell1, R.id.cell1Name, R.id.cell1Time),
            Triple(R.id.cell2, R.id.cell2Name, R.id.cell2Time),
            Triple(R.id.cell3, R.id.cell3Name, R.id.cell3Time),
            Triple(R.id.cell4, R.id.cell4Name, R.id.cell4Time),
            Triple(R.id.cell5, R.id.cell5Name, R.id.cell5Time)
        )
        cells.forEachIndexed { i, (cell, nameId, timeId) ->
            val event = day.getOrNull(i)
            if (event == null) {
                big.setViewVisibility(cell, View.GONE)
                return@forEachIndexed
            }
            big.setViewVisibility(cell, View.VISIBLE)
            big.setTextViewText(nameId, event.name)
            big.setTextViewText(timeId, time(event.adhan, withPeriod = false))
            val isCurrent = event.adhan == current.adhan
            big.setInt(cell, "setBackgroundResource", if (isCurrent) R.drawable.bg_time_chip_active else R.drawable.bg_time_chip)
            val alpha = if (!isCurrent && event.adhan < now) 0x99 else 0xFF
            val color = (alpha shl 24) or 0xFFFFFF
            big.setTextColor(nameId, color)
            big.setTextColor(timeId, color)
        }

        return baseBuilder(context)
            .setCustomContentView(small)
            .setCustomBigContentView(big)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            // نصّ احتياطي للساعات الذكية وقارئ الشاشة
            .setContentTitle(title)
            .setContentText(detail)
            .build()
    }

    private fun staleNotification(context: Context): android.app.Notification =
        baseBuilder(context)
            .setContentTitle("مواقيت الصلاة")
            .setContentText("افتح محراب لتحديث مواقيت الصلاة")
            .build()

    private fun baseBuilder(context: Context): NotificationCompat.Builder {
        val open = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).apply {
                action = "com.masjed.mihrab.OPEN_PRAYER_TIMES"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // أندرويد 14+ يسمح بسحب الإشعار الدائم: نعيده فوراً (يُطفأ من إعدادات الأذان في التطبيق)
        val repost = PendingIntent.getBroadcast(
            context,
            REQUEST_REPOST,
            Intent(context, PrayerNotificationReceiver::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(open)
            .setDeleteIntent(repost)
    }

    private fun post(context: Context, notification: android.app.Notification) {
        try {
            notificationManager(context).notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // إذن الإشعارات مرفوض (أندرويد 13+): لا شيء نعرضه
        }
    }

    // ─── منبّه التحديث ────────────────────────────────────────────────────

    private fun refreshIntent(context: Context, flags: Int): PendingIntent? =
        PendingIntent.getBroadcast(
            context,
            REQUEST_REFRESH_ALARM,
            Intent(context, PrayerNotificationReceiver::class.java).setAction(ACTION_REFRESH),
            flags or PendingIntent.FLAG_IMMUTABLE
        )

    private fun scheduleRefresh(context: Context, atMillis: Long) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pending = refreshIntent(context, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        // ثانية بعد الموعد كي تُحسب المرحلة التالية لا الحالية
        val at = atMillis + 1000
        try {
            val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
            when {
                exactAllowed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                exactAllowed -> alarms.setExact(AlarmManager.RTC_WAKEUP, at, pending)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                else -> alarms.set(AlarmManager.RTC_WAKEUP, at, pending)
            }
        } catch (e: SecurityException) {
            alarms.set(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    private fun cancelRefreshAlarm(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        refreshIntent(context, PendingIntent.FLAG_NO_CREATE)?.let {
            alarms.cancel(it)
            it.cancel()
        }
    }

    // ─── أدوات ────────────────────────────────────────────────────────────

    private fun parse(json: String?): List<PrayerEvent> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map {
                val o = array.getJSONObject(it)
                PrayerEvent(o.getString("name"), o.getLong("adhan"), o.optLong("iqama", 0L))
            }.sortedBy { it.adhan }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun sameDay(a: Long, b: Long): Boolean {
        val x = Calendar.getInstance().apply { timeInMillis = a }
        val y = Calendar.getInstance().apply { timeInMillis = b }
        return x.get(Calendar.YEAR) == y.get(Calendar.YEAR) &&
            x.get(Calendar.DAY_OF_YEAR) == y.get(Calendar.DAY_OF_YEAR)
    }

    /** "3:48 م" (أو "3:48" في خانات اليوم) */
    private fun time(millis: Long, withPeriod: Boolean = true): String {
        val c = Calendar.getInstance().apply { timeInMillis = millis }
        val h24 = c.get(Calendar.HOUR_OF_DAY)
        val h12 = if (h24 % 12 == 0) 12 else h24 % 12
        val clock = "$h12:${c.get(Calendar.MINUTE).toString().padStart(2, '0')}"
        return if (withPeriod) "$clock ${if (h24 < 12) "ص" else "م"}" else clock
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "مواقيت الصلاة ومتابعة الإقامة",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "شريط دائم بالصلاة القادمة والوقت المتبقي للأذان والإقامة"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager(context).createNotificationChannel(channel)
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun notificationManager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
