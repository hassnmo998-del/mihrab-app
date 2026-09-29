package com.masjed.mihrab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            "com.masjed.mihrab.ACTION_SILENCE_ADHAN" -> {
                AdhanAlarmReceiver.stopAdhan(context)
                MainActivity.channel?.invokeMethod("silenceAdhan", null)
            }
            // انتهى عدّاد المرحلة الحالية، أو مسح المستخدم الشريط: نرسم المرحلة التالية
            PrayerNotificationManager.ACTION_REFRESH -> PrayerNotificationManager.refresh(context)
        }
    }
}
