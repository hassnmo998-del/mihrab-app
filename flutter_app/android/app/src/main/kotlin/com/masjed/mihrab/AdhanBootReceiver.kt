package com.masjed.mihrab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AdhanBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.d(TAG, "Boot/Time change event received: $action")

        // شريط مواقيت الصلاة لا يبقى بعد إعادة التشغيل أو تحديث التطبيق: نعيد رسمه
        PrayerNotificationManager.refresh(context)

        // منبّهات الأذان تُمحى مع إعادة التشغيل: نعيد ضبطها من الجدول المحفوظ
        AdhanAlarmManager.scheduleUpcoming(context)
    }
}
