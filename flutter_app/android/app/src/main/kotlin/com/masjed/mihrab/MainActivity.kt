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
                "showCustomPrayerNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val targetEpoch = (args["targetEpochMillis"] as? Number)?.toLong() ?: 0L
                        val isIqama = args["isIqamaPhase"] as? Boolean ?: false
                        val isLive = args["isLiveFiring"] as? Boolean ?: false
                        val adhanTime = args["adhanTimeStr"] as? String ?: ""
                        val iqamaTime = args["iqamaTimeStr"] as? String ?: ""
                        val badge = args["badgeText"] as? String ?: ""
                        val subtitle = args["subtitleText"] as? String ?: ""
                        val smallTimes = args["smallTimesSummary"] as? String ?: ""

                        PrayerNotificationManager.showCustomNotification(
                            context = this,
                            targetEpochMillis = targetEpoch,
                            isIqamaPhase = isIqama,
                            isLiveFiring = isLive,
                            adhanTimeStr = adhanTime,
                            iqamaTimeStr = iqamaTime,
                            badgeText = badge,
                            subtitleText = subtitle,
                            smallTimesSummary = smallTimes
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Arguments must not be null", null)
                    }
                }
                "cancelCustomPrayerNotification" -> {
                    PrayerNotificationManager.cancelNotification(this)
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
