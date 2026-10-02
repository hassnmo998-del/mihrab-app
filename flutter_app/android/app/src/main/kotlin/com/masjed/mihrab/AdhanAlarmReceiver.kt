package com.masjed.mihrab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AdhanAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanAlarmReceiver"
        // An alarm delivered this late (clock changed, phone was off) no longer sounds the adhan
        private const val MAX_LATENESS_MS = 10 * 60 * 1000L

        fun stopAdhan(context: Context) = AdhanPlaybackService.stop(context)
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
            // This alarm is spent: set the following ones from the stored schedule
            AdhanAlarmManager.scheduleUpcoming(context)
            handlePrayerArrival(context, prayerName, triggerTime)
        }
    }

    private fun handlePrayerArrival(context: Context, prayerName: String, triggerTime: Long) {
        // Check Flutter SharedPreferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val masterEnabled = prefs.getBoolean("flutter.adhan_master_enabled", false)
        val prayerEnabled = prefs.getBoolean("flutter.adhan_prayer_$prayerName", true)

        if (!masterEnabled || !prayerEnabled) {
            Log.d(TAG, "Adhan for $prayerName is disabled (master: $masterEnabled, prayer: $prayerEnabled). Skipping playback.")
            return
        }

        val lateness = System.currentTimeMillis() - triggerTime
        if (triggerTime > 0L && lateness > MAX_LATENESS_MS) {
            Log.d(TAG, "Alarm for $prayerName arrived ${lateness / 1000}s late. Skipping playback.")
            return
        }

        AdhanPlaybackService.start(context, prayerName, triggerTime)
    }
}
