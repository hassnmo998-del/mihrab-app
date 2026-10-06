import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'adhan_service.dart';
import 'app_update_service.dart';
import '../core/navigation/navigator_key.dart';
import '../widgets/update_dialog.dart';

/// خدمة إدارة الإشعارات المحلية على الهواتف الذكية (Android)
/// تشمل الإشعار الدائم المخصص لمواقيت الصلاة، وتحديثات التطبيق.
class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  static const MethodChannel _customNotificationChannel =
      MethodChannel('com.masjed.mihrab/custom_prayer_notification');

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int updateNotificationId = 1001;
  static const int prayerTrackerNotificationId = 1002;

  static const String prayerTrackerChannelId = 'mihrab_prayer_tracker';
  static const String prayerTrackerChannelName = 'مواقيت الصلاة والتنبيه الدائم';

  final ValueNotifier<bool> isStickyEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isPermissionGrantedNotifier = ValueNotifier<bool>(false);

  bool _isInitialized = false;

  /// تهيئة نظام الإشعارات وقناة التتبع الدائم
  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final payload = response.payload;
          final actionId = response.actionId;

          // 1. زر إسكات الأذان من شريط الإشعارات مباشرة
          if (actionId == 'silence_adhan') {
            await AdhanService.instance.silenceAdhan();
            return;
          }

          // 2. النقر على إشعار الصلاة لفتح شاشة مواقيت الصلاة
          if (payload == 'open_prayer_times' || actionId == 'open_prayer_times') {
            MainShell.targetTabNotifier.value = 'adhan_prayer_times';
            return;
          }

          // 3. نقر إشعارات التحديث
          if (payload == 'update_available' || payload == 'update_ready') {
            final latest = AppUpdateService.instance.latestInfo;
            if (latest != null &&
                AppUpdateService.instance.isNewerVersion(latest.version, AppUpdateService.currentVersion)) {
              final ctx = appNavigatorKey.currentContext;
              if (ctx != null && ctx.mounted) {
                UpdateDialog.show(ctx, latest, AppUpdateService.instance);
              }
            }
          }
        },
      );

      // تسجيل قناة الإشعار الدائم الصامت في نظام أندرويد
      if (Platform.isAndroid) {
        const prayerChannel = AndroidNotificationChannel(
          prayerTrackerChannelId,
          prayerTrackerChannelName,
          description: 'عرض الصلاة القادمة والوقت المتبقي للأذان والإقامة بشكل دائم وثابت',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );

        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(prayerChannel);
      }

      // قراءة التفضيلات المحفوظة
      final prefs = await SharedPreferences.getInstance();
      isStickyEnabledNotifier.value =
          prefs.getBool('adhan_sticky_notification_enabled') ?? true;

      // فحص الإذن الحالي
      await checkPermissionStatus();

      // الاستماع لأحداث الإشعار المخصص (إسكات الأذان، فتح شاشة المواقيت)
      if (Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST')) {
        // القناة لها معالج واحد: أحداث الأذان (إسكات، بدء، انتهاء) تُحوَّل إلى AdhanService
        _customNotificationChannel.setMethodCallHandler((call) async {
          if (call.method == 'openPrayerTimes') {
            MainShell.targetTabNotifier.value = 'adhan_prayer_times';
          } else {
            await AdhanService.instance.handleNativeCall(call);
          }
        });

        try {
          final initialAction = await _customNotificationChannel.invokeMethod<String>('getInitialAction');
          if (initialAction == 'openPrayerTimes') {
            MainShell.targetTabNotifier.value = 'adhan_prayer_times';
          }
        } catch (_) {}
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [AppNotificationService] Init error: $e');
    }
  }

  /// يُبقي الشاشة مضاءة (أندرويد) ما دام تسجيل درس جارياً، ثم يعيدها لسلوكها.
  /// النظام يُسكت الميكروفون حين تُطفأ الشاشة، فيخرج التسجيل صامتاً.
  Future<void> setKeepScreenOn(bool on) async {
    if (kIsWeb || !Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await _customNotificationChannel.invokeMethod('setKeepScreenOn', on);
    } catch (_) {}
  }

  /// فحص حالة إذن الإشعارات
  Future<bool> checkPermissionStatus() async {
    if (kIsWeb || !Platform.isAndroid) {
      isPermissionGrantedNotifier.value = true;
      return true;
    }
    try {
      final status = await Permission.notification.status;
      final granted = status.isGranted;
      isPermissionGrantedNotifier.value = granted;
      return granted;
    } catch (_) {
      isPermissionGrantedNotifier.value = true;
      return true;
    }
  }

  /// طلب إذن الإشعارات من المستخدم وتحديث الحالة
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final status = await Permission.notification.request();
      final granted = status.isGranted;
      isPermissionGrantedNotifier.value = granted;
      if (granted) {
        await setStickyNotificationEnabled(true);
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// تفعيل أو تعطيل الإشعار الدائم
  Future<void> setStickyNotificationEnabled(bool enabled) async {
    isStickyEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('adhan_sticky_notification_enabled', enabled);
    } catch (_) {}

    if (!enabled) {
      await cancelStickyPrayerNotification();
    } else {
      await checkPermissionStatus();
      if (isPermissionGrantedNotifier.value) {
        await AdhanService.instance.refreshStickyNotification(force: true);
      }
    }
  }

  /// إلغاء كرت الإشعار الدائم
  Future<void> cancelStickyPrayerNotification() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _customNotificationChannel.invokeMethod('cancelCustomPrayerNotification');
    } catch (_) {}
    try {
      await _notificationsPlugin.cancel(id: prayerTrackerNotificationId);
    } catch (_) {}
  }

  /// يرسل جدول المواقيت القادمة إلى شريط الإشعار الدائم في أندرويد
  /// (PrayerNotificationManager.kt). بعدها يعدّ الشريط وينتقل بين الأذان والإقامة وحده،
  /// والتطبيق مغلق، ويعود بعد إعادة تشغيل الهاتف. يعيد true إن وصل الجدول.
  Future<bool> syncStickyPrayerNotification(List<Map<String, dynamic>> timeline) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    if (!_isInitialized) await init();
    if (!isStickyEnabledNotifier.value) return false;
    try {
      await _customNotificationChannel.invokeMethod('syncPrayerNotification', {
        'timeline': jsonEncode(timeline),
        'enabled': true,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ [AppNotificationService] syncStickyPrayerNotification error: $e');
      return false;
    }
  }

  /// إرسال إشعار فوري في شريط إشعارات الهاتف عند توفر إصدار جديد
  Future<void> showUpdateAvailableNotification(UpdateInfo info) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        'mihrab_app_updates',
        'تحديثات منصة محراب',
        channelDescription: 'إشعارات توفر الإصدارات الجديدة وترقية التطبيق',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
      );

      const notifDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: updateNotificationId,
        title: 'تحديث جديد متاح لمحراب v${info.version} 🕌',
        body: 'يتوفر إصدار جديد يتضمن تحسينات ومزايا هامة. اضغط هنا للترقية الآن 🚀',
        notificationDetails: notifDetails,
        payload: 'update_available',
      );
    } catch (e) {
      debugPrint('⚠️ [AppNotificationService] showUpdateAvailableNotification error: $e');
    }
  }

  /// إرسال إشعار فوري عند اكتمال تنزيل التحديث في الخلفية وهو جاهز للتثبيت
  Future<void> showUpdateReadyNotification(UpdateInfo info) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        'mihrab_app_updates',
        'تحديثات منصة محراب',
        channelDescription: 'إشعارات توفر الإصدارات الجديدة وترقية التطبيق',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
      );

      const notifDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: updateNotificationId,
        title: 'اكتمل تنزيل تحديث محراب v${info.version} 🎉',
        body: 'التحديث جاهز تماماً. اضغط هنا لتثبيت الترقية فوراً ⚡',
        notificationDetails: notifDetails,
        payload: 'update_ready',
      );
    } catch (e) {
      debugPrint('⚠️ [AppNotificationService] showUpdateReadyNotification error: $e');
    }
  }
}
