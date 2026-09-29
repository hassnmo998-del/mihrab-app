package com.masjed.mihrab

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object AdhanAlarmManager {
    private const val TAG = "AdhanAlarmManager"
    const val ACTION_PRAYER_ALARM = "com.masjed.mihrab.ACTION_PRAYER_ALARM"
    const val ACTION_SILENCE_ADHAN = "com.masjed.mihrab.ACTION_SILENCE_ADHAN"

    private val PRAYER_IDS = mapOf(
        "الفجر" to 2001,
        "الظهر" to 2002,
        "العصر" to 2003,
        "المغرب" to 2004,
        "العشاء" to 2005
    )

    fun schedulePrayerAlarm(
        context: Context,
        prayerName: String,
        triggerEpochMillis: Long
    ) {
        val now = System.currentTimeMillis()
        if (triggerEpochMillis <= now) {
            Log.d(TAG, "Skipping past prayer: $prayerName at $triggerEpochMillis")
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val prayerId = PRAYER_IDS[prayerName] ?: (2000 + (triggerEpochMillis % 1000).toInt())

        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = ACTION_PRAYER_ALARM
            putExtra("prayer_name", prayerName)
            putExtra("prayer_id", prayerId)
            putExtra("trigger_time", triggerEpochMillis)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            prayerId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Show open app intent for setAlarmClock
        val showIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.masjed.mihrab.OPEN_PRAYER_TIMES"
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            prayerId + 100,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerEpochMillis, showPendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                Log.d(TAG, "⏰ Scheduled AlarmClock for $prayerName at $triggerEpochMillis (ID: $prayerId)")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerEpochMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerEpochMillis,
                    pendingIntent
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "⚠️ SCHEDULE_EXACT_ALARM denied, falling back to setWindow/set: ${e.message}")
            try {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    triggerEpochMillis,
                    pendingIntent
                )
            } catch (fallbackEx: Exception) {
                Log.e(TAG, "Failed fallback alarm schedule", fallbackEx)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling prayer alarm for $prayerName", e)
        }
    }

    fun cancelAllAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for ((name, id) in PRAYER_IDS) {
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                action = ACTION_PRAYER_ALARM
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "Cancelled alarm for $name (ID: $id)")
            }
        }
    }
}
