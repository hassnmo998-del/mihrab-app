import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'update_models.dart';

/// ما يعرضه إشعار تقدّم التحديث عند لحظة.
class UpdateProgressView {
  final String title;
  final String body;

  /// 0..100
  final int percent;

  /// شريط متحرك بلا نسبة (انتظار الاتصال، التحقق من الملف، حجم غير معروف).
  final bool indeterminate;

  const UpdateProgressView({
    required this.title,
    required this.body,
    required this.percent,
    required this.indeterminate,
  });
}

/// شريط تقدّم تنزيل التحديث في شريط الإشعارات (أندرويد): النسبة والحجم كما في
/// الإعدادات، ثابت لا يُسحب ما دام التنزيل قائماً، ويختفي حين يكتمل.
///
/// يُحدَّث ممن يشغّل التنزيل: الواجهة والتطبيق مفتوح، ومهمة الخلفية والتطبيق مغلق.
/// الإشعار هو نفسه إشعار مهمة الخلفية ([notificationId])، فلا يظهر إشعاران.
class UpdateProgressNotification {
  UpdateProgressNotification._();

  static const int notificationId = 1003;
  static const String channelId = 'mihrab_update_progress';
  static const String channelName = 'تنزيل تحديثات محراب';

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// من يرسل الإشعار إلى النظام. الواجهة تضع مرسلها (إضافة الإشعارات المهيّأة فيها
  /// أصلاً، فلا تُعاد تهيئتها فتضيع معالجات الضغط)، ومهمة الخلفية تضع [backgroundPoster].
  /// `null` للعرض = أزل الإشعار.
  static Future<void> Function(UpdateProgressView? view)? poster;

  static int _lastPercent = -1;
  static UpdatePhase? _lastPhase;
  static DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  static String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// نص الإشعار ونسبته من حالة التنزيل.
  static UpdateProgressView describe(UpdateStatus status) {
    final percent = (status.fraction * 100).floor().clamp(0, 100);
    final version = status.version.isEmpty ? '' : ' v${status.version}';
    final size = status.total > 0
        ? '${_megabytes(status.received)} من ${_megabytes(status.total)} ميغابايت'
        : '${_megabytes(status.received)} ميغابايت';
    final body = switch (status.phase) {
      UpdatePhase.downloading => '$percent% • $size',
      UpdatePhase.waiting => 'بانتظار الاتصال بالإنترنت… يُستكمل وحده ($percent%)',
      UpdatePhase.verifying => 'جارٍ التحقق من سلامة الملف…',
      UpdatePhase.noSpace => 'لا توجد مساحة كافية على الجهاز. أفرغ بعض المساحة وسيُستكمل التنزيل.',
      UpdatePhase.ready => 'اكتمل التنزيل',
    };
    return UpdateProgressView(
      title: 'جارٍ تنزيل تحديث محراب$version',
      body: body,
      percent: percent,
      indeterminate: status.phase == UpdatePhase.verifying ||
          (status.phase == UpdatePhase.downloading && status.total <= 0),
    );
  }

  /// هل تستحق هذه الحالة تحديث الإشعار؟ عند تغيّر النسبة أو الطور، ومرة كل ثوانٍ على
  /// الأكثر، كي لا يُغرق النظام بمئات التحديثات في الثانية.
  @visibleForTesting
  static bool shouldShow(UpdateStatus status, DateTime now) {
    final percent = (status.fraction * 100).floor();
    if (status.phase != _lastPhase) return true;
    if (percent != _lastPercent && now.difference(_lastShown) >= const Duration(milliseconds: 700)) {
      return true;
    }
    // نبضة دورية تعيد الإشعار إن سحبه المستخدم (أندرويد 14 يسمح بسحب الدائم)
    return now.difference(_lastShown) >= const Duration(seconds: 5);
  }

  /// يعرض التقدّم أو يحدّثه. طور «جاهز» يزيل الإشعار.
  static Future<void> show(UpdateStatus status) async {
    if (status.phase == UpdatePhase.ready) return clear();
    final now = DateTime.now();
    if (!shouldShow(status, now)) return;
    _lastPhase = status.phase;
    _lastPercent = (status.fraction * 100).floor();
    _lastShown = now;
    try {
      await poster?.call(describe(status));
    } catch (e) {
      debugPrint('⚠️ [UpdateProgressNotification] show: $e');
    }
  }

  /// يزيل الشريط: اكتمل التنزيل أو أُلغي.
  static Future<void> clear() async {
    _lastPhase = null;
    _lastPercent = -1;
    _lastShown = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await poster?.call(null);
    } catch (e) {
      debugPrint('⚠️ [UpdateProgressNotification] clear: $e');
    }
  }

  /// يرسل [view] عبر [plugin] (أو يزيل الإشعار إن كان `null`).
  static Future<void> post(FlutterLocalNotificationsPlugin plugin, UpdateProgressView? view) async {
    if (!_supported) return;
    if (view == null) return plugin.cancel(id: notificationId);
    await plugin.show(
      id: notificationId,
      title: view.title,
      body: view.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'شريط تقدّم تنزيل تحديث التطبيق',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.progress,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          showWhen: false,
          showProgress: true,
          maxProgress: 100,
          progress: view.percent,
          indeterminate: view.indeterminate,
        ),
      ),
      payload: 'update_progress',
    );
  }

  static FlutterLocalNotificationsPlugin? _backgroundPlugin;

  /// مرسل مهمة الخلفية: محرك بلا واجهة، يهيّئ إضافة الإشعارات لنفسه.
  static Future<void> backgroundPoster(UpdateProgressView? view) async {
    if (!_supported) return;
    var plugin = _backgroundPlugin;
    if (plugin == null) {
      plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _backgroundPlugin = plugin;
    }
    await post(plugin, view);
  }
}
