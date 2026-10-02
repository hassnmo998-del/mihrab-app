package com.masjed.mihrab

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        const val CHANNEL_NAME = "com.masjed.mihrab/custom_prayer_notification"
        var channel: MethodChannel? = null
    }

    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == "com.masjed.mihrab.OPEN_PRAYER_TIMES") {
            if (channel != null) {
                channel?.invokeMethod("openPrayerTimes", null)
            } else {
                pendingAction = "openPrayerTimes"
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel = methodChannel

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialAction" -> {
                    result.success(pendingAction)
                    pendingAction = null
                }
                // جدول الأسبوعين القادمين لشريط مواقيت الصلاة (يعمل بعدها وحده دون التطبيق)
                "syncPrayerNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val timeline = args?.get("timeline") as? String
                    if (timeline != null) {
                        val enabled = args["enabled"] as? Boolean ?: true
                        PrayerNotificationManager.sync(this, timeline, enabled)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "timeline must be a JSON string", null)
                    }
                }
                "cancelCustomPrayerNotification" -> {
                    PrayerNotificationManager.disable(this)
                    result.success(true)
                }
                "schedulePrayerAlarms" -> {
                    val alarms = call.arguments as? List<*>
                    if (alarms != null) {
                        AdhanAlarmManager.syncSchedule(this, alarms.mapNotNull { item ->
                            val map = item as? Map<*, *> ?: return@mapNotNull null
                            val name = map["name"] as? String ?: return@mapNotNull null
                            val time = (map["time"] as? Number)?.toLong() ?: return@mapNotNull null
                            name to time
                        })
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Alarms list must not be null", null)
                    }
                }
                // التطبيق مفتوح وحان الأذان: يصدح من الخدمة نفسها التي يطلقها المنبّه، مرة واحدة
                "startAdhanNow" -> {
                    val args = call.arguments as? Map<*, *>
                    val name = args?.get("name") as? String
                    val time = (args?.get("time") as? Number)?.toLong()
                    if (name != null && time != null) {
                        AdhanPlaybackService.start(this, name, time)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "name and time are required", null)
                    }
                }
                "cancelPrayerAlarms" -> {
                    AdhanAlarmManager.cancelAllAlarms(this)
                    result.success(true)
                }
                "silenceNativeAdhan" -> {
                    AdhanAlarmReceiver.stopAdhan(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        if (pendingAction != null) {
            methodChannel.invokeMethod(pendingAction!!, null)
            pendingAction = null
        }
    }

    override fun onDestroy() {
        if (channel != null) {
            channel = null
        }
        super.onDestroy()
    }
}
