package com.masjed.mihrab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == "com.masjed.mihrab.ACTION_SILENCE_ADHAN") {
            MainActivity.channel?.invokeMethod("silenceAdhan", null)
        }
    }
}
