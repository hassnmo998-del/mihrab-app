import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/utils/platform_utils.dart';

/// خدمة أمامية (Foreground Service) من نوع «ميكروفون» ما دام درس يُسجَّل على أندرويد.
///
/// بدونها يعطي أندرويد التطبيقَ صمتاً بدل صوت الميكروفون لحظة تُقفل الشاشة أو يُفتح
/// تطبيق آخر أو يأتي اتصال: العدّاد يكمل والملف يُرفع، لكن ما بعد تلك اللحظة سكوت.
/// النوع `microphone` مصرَّح به في `AndroidManifest.xml` مع إذن
/// `FOREGROUND_SERVICE_MICROPHONE` (أندرويد 14 يرفض الخدمة بدونه).
class LessonRecordingGuard {
  LessonRecordingGuard._();

  static bool _initialized = false;
  static bool _running = false;

  static bool get _supported => !kIsWeb && PlatformUtils.isAndroid;

  static void _ensureInitialized() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        id: 1201,
        channelId: 'lesson_recording',
        channelName: 'تسجيل الدروس',
        channelDescription: 'يبقى ظاهراً ما دام الدرس يُسجَّل، كي لا يُسكت النظام الميكروفون',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // إن أُغلق التطبيق لا تعود الخدمة وحدها: لا تسجيل بلا شاشة الدرس
        isSticky: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 60000,
        allowWakeLock: true,
      ),
    );
    _initialized = true;
  }

  /// يبدأ الخدمة. لا يرمي أبداً: فشلها لا يمنع التسجيل والشاشة تبقى مضاءة.
  static Future<void> start(String lessonTitle) async {
    if (!_supported) return;
    try {
      _ensureInitialized();
      if (_running || await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'جارٍ تسجيل الدرس',
          notificationText: lessonTitle,
        );
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: 'جارٍ تسجيل الدرس',
          notificationText: lessonTitle,
        );
      }
      _running = true;
    } catch (e) {
      debugPrint('⚠️ تعذّر بدء خدمة التسجيل الأمامية: $e');
    }
  }

  static Future<void> stop() async {
    if (!_supported || !_running) return;
    _running = false;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('⚠️ تعذّر إيقاف خدمة التسجيل الأمامية: $e');
    }
  }
}
