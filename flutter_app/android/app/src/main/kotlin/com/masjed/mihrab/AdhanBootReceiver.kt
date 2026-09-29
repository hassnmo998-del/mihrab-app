package com.masjed.mihrab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray

class AdhanBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Boot/Time change event received: $action")

        // شريط مواقيت الصلاة لا يبقى بعد إعادة التشغيل أو تحديث التطبيق: نعيد رسمه
        PrayerNotificationManager.refresh(context)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val masterEnabled = prefs.getBoolean("flutter.adhan_master_enabled", false)
        if (!masterEnabled) {
            Log.d(TAG, "Adhan master is disabled, skipping alarm reschedule.")
            return
        }

        val cachedSchedule = prefs.getString("flutter.adhan_cached_schedule_json", null)
        if (!cachedSchedule.isNullOrEmpty()) {
            try {
                val jsonArray = JSONArray(cachedSchedule)
                val now = System.currentTimeMillis()
                for (i in 0 until jsonArray.length()) {
                    val item = jsonArray.getJSONObject(i)
                    val name = item.getString("name")
                    val epoch = item.getLong("time")
                    if (epoch > now) {
                        AdhanAlarmManager.schedulePrayerAlarm(context, name, epoch)
                    }
                }
                Log.d(TAG, "✅ Successfully restored ${jsonArray.length()} prayer alarms from cache after $action")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restore prayer alarms from cached schedule", e)
            }
        }
    }
}
