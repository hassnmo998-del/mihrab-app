import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'update_models.dart';
import 'update_session.dart';

/// متابعة تنزيل التحديث في الخلفية على أندرويد.
///
/// مهمة WorkManager واحدة باسم ثابت، شرطها وجود اتصال. النظام يحفظها ويعيد
/// تشغيلها وحده: بعد قتل التطبيق، وبعد إعادة تشغيل الهاتف، وحين يعود الاتصال.
/// تعمل كخدمة أمامية (إشعار "جارٍ تنزيل التحديث") فلا يوقفها النظام بعد
/// دقائق، وإن مُنعت من ذلك تعمل مهمة عادية على دفعات يكمل كل منها ما قبله.
///
/// المهمة تشغّل [UpdateSession] نفسها التي تشغّلها الواجهة، على المجلد نفسه:
/// إن كانت الواجهة حيّة وتنزّل، تكتفي المهمة بإبقاء التطبيق حياً ومراقبتها؛
/// وإن ماتت الواجهة تتولى المهمة التنزيل من حيث وقف.
class UpdateBackground {
  UpdateBackground._();

  static const String uniqueName = 'mihrab_update_download';
  static const String taskName = 'mihrabUpdateDownload';
  static const int progressNotificationId = 1003;
  static const int readyNotificationId = 1001;

  static bool get _supported => !kIsWeb && Platform.isAndroid;
  static bool _initialized = false;

  /// يُستدعى مرة عند إقلاع التطبيق.
  static Future<void> initialize() async {
    if (!_supported || _initialized) return;
    try {
      await Workmanager().initialize(updateCallbackDispatcher);
      _initialized = true;
    } catch (e) {
      // بلا مهمة خلفية يبقى التنزيل يعمل والتطبيق مفتوح، ويكمل عند فتحه
      debugPrint('⚠️ [UpdateBackground] initialize: $e');
    }
  }

  /// يضمن وجود المهمة ما دام هناك تحديث قيد التنزيل. استدعاؤه مرتين لا يكررها.
  static Future<void> ensureScheduled(String dirPath) async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      await Workmanager().registerOneOffTask(
        uniqueName,
        taskName,
        inputData: {'dir': dirPath},
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(seconds: 15),
        foregroundServiceConfig: ForegroundServiceConfig(
          notificationTitle: 'تحديث محراب',
          notificationText: 'جارٍ تنزيل التحديث… يكتمل وحده ولو أغلقت التطبيق',
          notificationChannelId: 'mihrab_update_progress',
          notificationChannelName: 'تنزيل تحديثات محراب',
          notificationId: progressNotificationId,
          foregroundServiceType: ForegroundServiceType.dataSync,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [UpdateBackground] ensureScheduled: $e');
    }
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(uniqueName);
    } catch (_) {}
  }
}

/// مدخل مهمة الخلفية: يعمل في محرك Flutter بلا واجهة.
@pragma('vm:entry-point')
void updateCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != UpdateBackground.taskName) return true;
    final dirPath = inputData?['dir'] as String?;
    if (dirPath == null || dirPath.isEmpty) return true;

    try {
      final session = UpdateSession(
        dir: Directory(dirPath),
        ownerId: 'bg-$pid-${DateTime.now().microsecondsSinceEpoch}',
      );
      var ownedByTask = false;
      final file = await session.run(
        onStatus: (status) {
          // نبضة "جاهز" تحمل هوية من قرأها لا من نزّل؛ المالك يُعرف من نبضات التنزيل
          if (status.phase != UpdatePhase.ready) ownedByTask = status.owner == session.ownerId;
        },
      );
      // الإشعار ممن أكمل التنزيل فقط: إن أكملته الواجهة فهي تعرض نافذتها
      if (file != null && ownedByTask) {
        await _notifyReady(session.readJob()?.version ?? '');
      }
      return true;
    } catch (e) {
      // false = أعد المحاولة لاحقاً
      return false;
    }
  });
}

Future<void> _notifyReady(String version) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.show(
      id: UpdateBackground.readyNotificationId,
      title: 'اكتمل تنزيل تحديث محراب${version.isEmpty ? '' : ' v$version'} 🎉',
      body: 'التحديث جاهز. اضغط هنا لفتح التطبيق وتثبيته.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'mihrab_app_updates',
          'تحديثات منصة محراب',
          channelDescription: 'إشعارات توفر الإصدارات الجديدة وترقية التطبيق',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'update_ready',
    );
  } catch (_) {}
}
