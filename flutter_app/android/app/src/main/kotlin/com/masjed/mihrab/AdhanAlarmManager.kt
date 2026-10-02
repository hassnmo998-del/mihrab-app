package com.masjed.mihrab

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Exact alarms that fire the adhan with the app closed.
 *
 * Flutter sends the adhan times of the coming two weeks ([syncSchedule]). Only the next
 * [SLOT_COUNT] are handed to AlarmManager; every time one fires, [scheduleUpcoming] tops
 * them up from the stored schedule, so the adhan keeps sounding for days without the app
 * being opened.
 */
object AdhanAlarmManager {
    private const val TAG = "AdhanAlarmManager"
    const val ACTION_PRAYER_ALARM = "com.masjed.mihrab.ACTION_PRAYER_ALARM"
    const val ACTION_SILENCE_ADHAN = "com.masjed.mihrab.ACTION_SILENCE_ADHAN"

    private const val PREFS = "mihrab_adhan_alarms"
    private const val KEY_SCHEDULE = "schedule_json"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    // One request code per upcoming alarm. They used to be keyed by prayer name, so
    // tomorrow's Dhuhr replaced today's Dhuhr and today's adhan never fired.
    private const val SLOT_BASE = 2100
    private const val SLOT_COUNT = 10
    private const val REQUEST_SHOW_APP = 2099
    private val LEGACY_PRAYER_IDS = 2001..2005

    /** Stores the schedule sent by Flutter, then sets the alarms. */
    fun syncSchedule(context: Context, alarms: List<Pair<String, Long>>) {
        val json = JSONArray()
        for ((name, time) in alarms) {
            json.put(JSONObject().put("name", name).put("time", time))
        }
        prefs(context).edit().putString(KEY_SCHEDULE, json.toString()).apply()
        scheduleUpcoming(context)
    }

    /** Sets the next alarms from the stored schedule and clears the slots left over. */
    fun scheduleUpcoming(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for (id in LEGACY_PRAYER_IDS) cancelAlarm(context, alarmManager, id)

        val masterEnabled = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getBoolean("flutter.adhan_master_enabled", false)
        val now = System.currentTimeMillis()
        val upcoming = if (masterEnabled) {
            storedSchedule(context).filter { it.second > now }.sortedBy { it.second }.take(SLOT_COUNT)
        } else {
            emptyList()
        }

        for (slot in 0 until SLOT_COUNT) {
            val alarm = upcoming.getOrNull(slot)
            if (alarm == null) {
                cancelAlarm(context, alarmManager, SLOT_BASE + slot)
            } else {
                setAlarm(context, alarmManager, SLOT_BASE + slot, alarm.first, alarm.second)
            }
        }
        Log.d(TAG, "⏰ Scheduled ${upcoming.size} adhan alarms (master enabled: $masterEnabled)")
    }

    fun cancelAllAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for (id in LEGACY_PRAYER_IDS) cancelAlarm(context, alarmManager, id)
        for (slot in 0 until SLOT_COUNT) cancelAlarm(context, alarmManager, SLOT_BASE + slot)
    }

    private fun setAlarm(
        context: Context,
        alarmManager: AlarmManager,
        requestCode: Int,
        prayerName: String,
        triggerEpochMillis: Long
    ) {
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = ACTION_PRAYER_ALARM
            putExtra("prayer_name", prayerName)
            putExtra("trigger_time", triggerEpochMillis)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
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
            REQUEST_SHOW_APP,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerEpochMillis, showPendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        } catch (e: SecurityException) {
            Log.w(TAG, "⚠️ SCHEDULE_EXACT_ALARM denied, falling back to an inexact alarm: ${e.message}")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerEpochMillis, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerEpochMillis, pendingIntent)
                }
            } catch (fallbackEx: Exception) {
                Log.e(TAG, "Failed fallback alarm schedule", fallbackEx)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling prayer alarm for $prayerName", e)
        }
    }

    private fun cancelAlarm(context: Context, alarmManager: AlarmManager, requestCode: Int) {
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = ACTION_PRAYER_ALARM
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun storedSchedule(context: Context): List<Pair<String, Long>> {
        val json = prefs(context).getString(KEY_SCHEDULE, null)
            // Right after updating from a version that kept the schedule in Flutter's prefs
            ?: context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                .getString("flutter.adhan_cached_schedule_json", null)
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map {
                val item = array.getJSONObject(it)
                item.getString("name") to item.getLong("time")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read the stored adhan schedule", e)
            emptyList()
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
