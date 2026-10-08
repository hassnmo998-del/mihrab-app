import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/datasources/supabase_remote_datasource.dart';
import 'update/update_background.dart';

/// يرسل جسم الطلب إلى `app_install_ping` ويعيد رده، أو يرمي إن لم يصل.
typedef PresenceSender = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// آخر إشارة وصلت الخادم من هذا الجهاز.
@immutable
class PresenceState {
  final String installId;
  final String version;
  /// يوم الخادم (بتوقيت دمشق) الذي سُجّلت فيه.
  final String day;
  /// هل سُجّل في ذلك اليوم أن التطبيق فُتح (لا إشارة خلفية فقط).
  final bool opened;
  /// بساعة الجهاز.
  final DateTime sentAt;
  /// ما بقي من يوم الخادم لحظة الإرسال، كما حسبه الخادم.
  final Duration untilNextDay;

  const PresenceState({
    required this.installId,
    required this.version,
    required this.day,
    required this.opened,
    required this.sentAt,
    required this.untilNextDay,
  });

  /// بداية يوم الخادم التالي بساعة الجهاز. تُحسب من فرق أرسله الخادم لا من تاريخ
  /// الجهاز: ساعة متقدمة أو منطقة زمنية خاطئة لا تغيّر متى يبدأ اليوم التالي.
  DateTime get nextDayAt => sentAt.add(untilNextDay);

  Map<String, dynamic> toJson() => {
        'id': installId,
        'version': version,
        'day': day,
        'opened': opened,
        'sentAt': sentAt.millisecondsSinceEpoch,
        'untilNextDay': untilNextDay.inSeconds,
      };

  static PresenceState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return PresenceState(
        installId: raw['id'] as String,
        version: raw['version'] as String,
        day: raw['day'] as String,
        opened: raw['opened'] as bool,
        sentAt: DateTime.fromMillisecondsSinceEpoch(raw['sentAt'] as int),
        untilNextDay: Duration(seconds: raw['untilNextDay'] as int),
      );
    } catch (_) {
      return null;
    }
  }
}

/// عدّ الأجهزة التي عليها التطبيق، بلا أي بيان عن صاحبها.
///
/// كل جهاز يقول للخادم «أنا موجود» مرة في اليوم: عند فتح التطبيق، ثم كل ربع ساعة يفحص
/// ما دام مفتوحاً (شاشة مسجد تبقى مفتوحة أياماً)، وعلى أندرويد من الخلفية كل بضع ساعات
/// ولو لم يُفتح (من يستعمله للأذان وحده). الخادم يحفظ سطراً واحداً لكل جهاز، فمئة فتحة
/// من الجهاز نفسه جهاز واحد. ما يُرسل: معرّف الجهاز، المنصة، رقم الإصدار، وهل فُتح.
///
/// المعرّف على أندرويد بصمة `ANDROID_ID` (ثابت لهذا الجهاز ولتطبيقنا: لا يتغير بحذف
/// التطبيق وإعادة تثبيته ولا بمسح بياناته، ولا ينتقل مع النسخ الاحتياطي إلى هاتف آخر).
/// وفي غيره رقم عشوائي يُحفظ في إعدادات التطبيق.
///
/// بلا إنترنت لا يضيع شيء: الإشارة لا تُعدّ مرسلة حتى يردّ الخادم، فتُعاد في الفحص التالي.
class InstallPresence {
  InstallPresence._();

  static const String idPrefsKey = 'install_presence_id';
  static const String statePrefsKey = 'install_presence_state';

  static const String backgroundUniqueName = 'mihrab_install_presence';
  static const String backgroundTaskName = 'mihrabInstallPresence';

  static const Duration _checkEvery = Duration(minutes: 15);
  static const MethodChannel _channel = MethodChannel('com.masjed.mihrab/custom_prayer_notification');
  static final RegExp _validId = RegExp(r'^[0-9a-f]{32}$');

  @visibleForTesting
  static PresenceSender sender = _postPing;
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static Timer? _timer;
  static Future<bool>? _inFlight;

  /// يُنادى مرة عند الإقلاع.
  static Future<void> start() async {
    if (_timer != null) return;
    _timer = Timer.periodic(_checkEvery, (_) => onForeground());
    unawaited(_scheduleBackground());
    await onForeground();
  }

  /// عاد المستخدم إلى التطبيق. لا شيء إن لم يُنادَ [start] (الاختبارات).
  static void onResumed() {
    if (_timer != null) unawaited(onForeground());
  }

  /// التطبيق أمام المستخدم: عند الفتح والعودة إليه، وكل ربع ساعة ما دام مفتوحاً.
  static Future<bool> onForeground() =>
      _inFlight ??= report(opened: true, deviceKey: _androidDeviceKey).whenComplete(() => _inFlight = null);

  /// مهمة الخلفية على أندرويد. لا تنشئ معرّفاً: إن لم يُفتح التطبيق قط بعد هذا الإصدار
  /// فلا معرّف لتستعمله، وإنشاء عشوائي هنا كان سيعدّ الجهاز مرتين.
  static Future<bool> reportFromBackground() async {
    try {
      await report(opened: false, createId: false);
    } catch (_) {}
    // true دائماً: المهمة دورية، والمحاولة التالية في موعدها
    return true;
  }

  /// يرسل الإشارة إن كان موعدها قد حان، ويعيد true إن وصلت الخادم.
  @visibleForTesting
  static Future<bool> report({
    required bool opened,
    Future<String?> Function()? deviceKey,
    Future<String> Function()? version,
    bool createId = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = await resolveInstallId(prefs, deviceKey: deviceKey, create: createId);
      if (id == null) return false;
      final ver = await (version ?? _appVersion)();
      final last = PresenceState.fromJson(_decode(prefs.getString(statePrefsKey)));

      if (!isDue(last: last, installId: id, version: ver, opened: opened, now: clock())) return false;

      final reply = await sender({
        'p_install_id': id,
        'p_platform': platformName,
        'p_version': ver,
        'p_opened': opened,
      });
      final day = '${reply['day'] ?? ''}';
      final secondsLeft = (reply['seconds_left'] as num?)?.toInt();
      if (day.isEmpty || secondsLeft == null) return false;

      // فتحٌ سُجّل في اليوم نفسه يبقى مسجَّلاً بعد إشارة خلفية
      final openedEarlierToday = last != null && last.installId == id && last.day == day && last.opened;
      final state = PresenceState(
        installId: id,
        version: ver,
        day: day,
        opened: opened || openedEarlierToday,
        sentAt: clock(),
        // يوم الخادم لا يزيد على 25 ساعة (يوم تغيير الساعة)، ولا معنى لأقل من دقيقة
        untilNextDay: Duration(seconds: secondsLeft.clamp(60, 25 * 3600)),
      );
      await prefs.setString(statePrefsKey, jsonEncode(state.toJson()));
      return true;
    } catch (e) {
      debugPrint('ℹ️ [InstallPresence] not sent: $e');
      return false;
    }
  }

  /// هل تُرسل إشارة الآن؟ واحدة في يوم الخادم تكفي، إلا إن:
  /// تغيّر المعرّف أو الإصدار، أو رجعت ساعة الجهاز، أو فُتح التطبيق ولم يُسجَّل فتحه اليوم
  /// (الإشارة السابقة كانت من الخلفية).
  @visibleForTesting
  static bool isDue({
    required PresenceState? last,
    required String installId,
    required String version,
    required bool opened,
    required DateTime now,
  }) {
    if (last == null) return true;
    if (last.installId != installId || last.version != version) return true;
    if (now.isBefore(last.sentAt)) return true;
    if (!now.isBefore(last.nextDayAt)) return true;
    return opened && !last.opened;
  }

  /// معرّف هذا الجهاز. مع [deviceKey] (أندرويد) بصمته، ويُحفظ كي تقرأه مهمة الخلفية
  /// (لا قناة إلى أندرويد هناك). وبدونه المحفوظ، أو عشوائي جديد يُحفظ إن سُمح [create].
  @visibleForTesting
  static Future<String?> resolveInstallId(
    SharedPreferences prefs, {
    Future<String?> Function()? deviceKey,
    bool create = true,
  }) async {
    String? key;
    try {
      key = await deviceKey?.call();
    } catch (_) {}
    if (key != null && key.trim().isNotEmpty) {
      final id = sha256.convert(utf8.encode('mihrab-install:${key.trim()}')).toString().substring(0, 32);
      if (prefs.getString(idPrefsKey) != id) await prefs.setString(idPrefsKey, id);
      return id;
    }

    final stored = prefs.getString(idPrefsKey);
    if (stored != null && _validId.hasMatch(stored)) return stored;
    if (!create) return null;

    final rnd = Random.secure();
    final id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(idPrefsKey, id);
    return id;
  }

  /// كما تُعرض في لوحة المشرف العام. نسخة الويب على آيفون/آيباد «ios».
  static String get platformName {
    if (kIsWeb) return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'web';
  }

  static Future<String?> _androidDeviceKey() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('getDeviceKey');
  }

  static Future<String> _appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '';
    }
  }

  static Object? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// طلب مباشر بلا عميل Supabase: يعمل كما هو في مهمة الخلفية حيث لا تهيئة.
  static Future<Map<String, dynamic>> _postPing(Map<String, dynamic> body) async {
    const key = SupabaseRemoteDataSource.defaultSupabaseAnonKey;
    final res = await http
        .post(
          Uri.parse('${SupabaseRemoteDataSource.defaultSupabaseUrl}/rest/v1/rpc/app_install_ping'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('HTTP ${res.statusCode}: ${res.body}');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  /// مهمة WorkManager دورية (أندرويد): تُبقي الجهاز معدوداً ولو لم يُفتح التطبيق.
  static Future<void> _scheduleBackground() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!await UpdateBackground.initialize()) return;
    try {
      await Workmanager().registerPeriodicTask(
        backgroundUniqueName,
        backgroundTaskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (e) {
      debugPrint('⚠️ [InstallPresence] schedule: $e');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _timer?.cancel();
    _timer = null;
    _inFlight = null;
    sender = _postPing;
    clock = DateTime.now;
  }
}
