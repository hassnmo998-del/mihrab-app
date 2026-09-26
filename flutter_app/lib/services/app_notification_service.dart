import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
            if (latest != null) {
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
        _customNotificationChannel.setMethodCallHandler((call) async {
          if (call.method == 'silenceAdhan') {
            await AdhanService.instance.silenceAdhan();
          } else if (call.method == 'openPrayerTimes') {
            MainShell.targetTabNotifier.value = 'adhan_prayer_times';
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
        await AdhanService.instance.refreshStickyNotification();
      }
    }
  }

  String _formatTimeArabic(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${hour.toString().padLeft(2, '0')}:$min $period';
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

  /// تحديث كرت شريط الإشعارات الدائم مطابقاً لكرت شاشة التطبيق تماماً بتصميم مخصص (Custom RemoteViews)
  Future<void> updateStickyPrayerNotification({
    required CurrentPrayerState prayerState,
    required List<Map<String, dynamic>> todaySchedule,
    String? liveFiringPrayer,
    String? muezzinName,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!_isInitialized) await init();
    if (!isStickyEnabledNotifier.value) return;
    if (!isPermissionGrantedNotifier.value) return;

    try {
      final isLive = liveFiringPrayer != null;
      final isIqama = prayerState.phase == PrayerCountdownPhase.betweenAdhanAndIqama;

      DateTime targetTime;
      String badgeText;
      String subtitleText;
      String adhanTimeStr;
      String iqamaTimeStr;
      String smallTimesSummary;

      if (isLive) {
        targetTime = DateTime.now();
        badgeText = 'يصدح الآن أذان $liveFiringPrayer 🕌';
        subtitleText = 'بصوت الشيخ: ${muezzinName ?? "المؤذن"}';
        adhanTimeStr = 'يصدح الآن';
        iqamaTimeStr = 'إسكات 🔇';
        smallTimesSummary = 'أذان $liveFiringPrayer يصدح الآن 🕌';
      } else if (isIqama) {
        targetTime = prayerState.iqamaTime ?? DateTime.now();
        final pName = prayerState.prayerName;
        badgeText = 'حان الآن وقت أذان $pName 🕌';
        subtitleText = 'الوقت المتبقي لرفع إقامة الصلاة';
        adhanTimeStr = _formatTimeArabic(prayerState.prayerTime);
        iqamaTimeStr = _formatTimeArabic(targetTime);
        smallTimesSummary = 'أذان $pName • الإقامة: $iqamaTimeStr';
      } else {
        final nextName = prayerState.nextPrayerName;
        final nextTime = prayerState.nextPrayerTime;
        final prayerInfo = todaySchedule.firstWhere(
          (p) => p['name'] == nextName,
          orElse: () => {'iqamaMinutes': 15},
        );
        final iqamaMin = (prayerInfo['iqamaMinutes'] as int?) ?? 15;
        final iqamaTime = nextTime.add(Duration(minutes: iqamaMin));

        targetTime = nextTime;
        badgeText = 'الصلاة القادمة: $nextName 🌙';
        subtitleText = 'الوقت المتبقي لرفع الأذان';
        adhanTimeStr = _formatTimeArabic(nextTime);
        iqamaTimeStr = _formatTimeArabic(iqamaTime);
        smallTimesSummary = 'الأذان: $adhanTimeStr • الإقامة: $iqamaTimeStr';
      }

      // 1. المحاولة أولاً عبر واجهة RemoteViews المخصصة والمطابقة لكرت التطبيق
      try {
        await _customNotificationChannel.invokeMethod('showCustomPrayerNotification', {
          'targetEpochMillis': targetTime.millisecondsSinceEpoch,
          'isIqamaPhase': isIqama,
          'isLiveFiring': isLive,
          'adhanTimeStr': adhanTimeStr,
          'iqamaTimeStr': iqamaTimeStr,
          'badgeText': badgeText,
          'subtitleText': subtitleText,
          'smallTimesSummary': smallTimesSummary,
        });
        return;
      } catch (nativeErr) {
        debugPrint('⚠️ [AppNotificationService] Custom RemoteViews fallback: $nativeErr');
      }

      // 2. خطة احتياطية في حال تعذر الإشعار المخصص (Fallback)
      final canCountDown = !isLive && targetTime.isAfter(DateTime.now());
      final androidDetails = AndroidNotificationDetails(
        prayerTrackerChannelId,
        prayerTrackerChannelName,
        channelDescription:
            'إشعار دائم وثابت يعرض الصلاة القادمة والوقت المتبقي للأذان والإقامة',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: targetTime.millisecondsSinceEpoch,
        usesChronometer: canCountDown,
        chronometerCountDown: canCountDown,
        category: AndroidNotificationCategory.status,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF047857),
        actions: [
          const AndroidNotificationAction(
            'open_prayer_times',
            'فتح محراب 🕌',
            showsUserInterface: true,
          ),
          if (isLive)
            const AndroidNotificationAction(
              'silence_adhan',
              'إسكات الأذان 🔇',
            ),
        ],
      );

      final notifDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: prayerTrackerNotificationId,
        title: badgeText,
        body: '$smallTimesSummary\n$subtitleText',
        notificationDetails: notifDetails,
        payload: 'open_prayer_times',
      );
    } catch (e) {
      debugPrint('⚠️ [AppNotificationService] updateStickyPrayerNotification error: $e');
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
