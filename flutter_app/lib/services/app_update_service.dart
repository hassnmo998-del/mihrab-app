// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_config.dart';
import 'app_notification_service.dart';
import 'update/update_background.dart';
import 'update/update_feed.dart';
import 'update/update_models.dart';
import 'update/update_models.dart' as models;
import 'update/update_session.dart';
import '../core/navigation/navigator_key.dart';
import '../widgets/update_dialog.dart';

export 'update/update_models.dart' show Semver, UpdateAsset, UpdateInfo;

// ─────────────────────────────────────────────
// SilentUpdateState — حالات التحديث
// ─────────────────────────────────────────────

enum SilentUpdateState {
  idle,            // لا شيء
  checking,        // جارٍ التحقق من التحديثات
  updateAvailable, // يتوفر تحديث جديد
  downloading,     // جارٍ التنزيل (ومنه: بانتظار عودة الاتصال)
  readyToInstall,  // اكتمل التنزيل وجاهز للتثبيت
  installing,      // جارٍ فتح مثبت النظام
  error,           // لا ملف لهذا الجهاز في الإصدار
}

// ─────────────────────────────────────────────
// AppUpdateService — التحديث داخل التطبيق
// ─────────────────────────────────────────────

/// التحديث داخل التطبيق: الفحص، التنزيل، التثبيت.
///
/// من لحظة ضغط «تحديث» يصير التحديث مهمة محفوظة على القرص ([UpdateSession])
/// لا تنتهي إلا بتثبيت الإصدار:
///  - انقطاع الشبكة ليس فشلاً: يبقى التنزيل "قيد التنفيذ" وينتظر، ويكمل من آخر
///    بايت حين يعود الاتصال.
///  - إغلاق التطبيق أو إعادة تشغيل الجهاز لا يلغيها: [resumePendingUpdate]
///    يكملها عند الفتح بلا سؤال، ومهمة الخلفية تكملها على أندرويد والتطبيق مغلق.
///  - فحص التحديث أثناء تنزيل جارٍ لا يمسّ حالته، فلا تظهر نافذة «تحديث متاح»
///    لتحديث هو قيد التنزيل أصلاً.
class AppUpdateService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────
  AppUpdateService._internal();
  static final AppUpdateService instance = AppUpdateService._internal();

  /// تنظيف رقم الإصدار من البادئات (v / V) واللواحق (+build / -beta)
  static String cleanVersion(String v) => models.cleanVersion(v);

  // ── الإصدار الحالي للتطبيق ─────────────────
  static String _packageVersion = '';
  static String get currentVersion => _packageVersion.isNotEmpty ? _packageVersion : kCurrentAppVersion;
  static Completer<void>? _initCompleter;

  /// تُقرأ مرة واحدة عند الإقلاع من PackageInfo
  static Future<void> init() async {
    if (_packageVersion.isNotEmpty) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      final info = await PackageInfo.fromPlatform();
      final cleaned = cleanVersion(info.version);
      _packageVersion = cleaned.isNotEmpty ? cleaned : kCurrentAppVersion;
    } catch (_) {
      _packageVersion = kCurrentAppVersion;
    }

    completer.complete();
  }

  // ── مفاتيح SharedPreferences القديمة (تُنظَّف مرة) ───
  static const String _legacyDownloadedPathKey = 'update_downloaded_path';
  static const String _legacyDownloadedVersionKey = 'update_downloaded_version';

  UpdateFeed _feed = UpdateFeed();
  Future<Directory> Function() _updatesDir = _defaultUpdatesDir;
  String? _platformOverride;
  UpdateSession Function(Directory dir, String ownerId, UpdateFeed feed)? _sessionFactory;

  static Future<Directory> _defaultUpdatesDir() async {
    // مجلد دعم التطبيق لا المجلد المؤقت: النظام يمسح المؤقت متى ضاق التخزين
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}updates');
  }

  String get _platform => _platformOverride ?? (Platform.isWindows ? 'windows' : 'android');

  @visibleForTesting
  void debugConfigure({
    UpdateFeed? feed,
    Future<Directory> Function()? updatesDir,
    String? platform,
    String? currentVersion,
    UpdateSession Function(Directory dir, String ownerId, UpdateFeed feed)? sessionFactory,
  }) {
    if (feed != null) _feed = feed;
    if (sessionFactory != null) _sessionFactory = sessionFactory;
    if (updatesDir != null) _updatesDir = updatesDir;
    _platformOverride = platform ?? _platformOverride;
    if (currentVersion != null) _packageVersion = currentVersion;
    _session = null;
    _resumeFuture = null;
    _sessionRunning = false;
    _stopRequested = false;
    latestInfo = null;
    state = SilentUpdateState.idle;
    downloadProgress = 0;
    receivedBytes = 0;
    totalBytes = 0;
    isWaitingForNetwork = false;
    downloadedFilePath = null;
  }

  Timer? _periodicTimer;
  UpdateSession? _session;
  bool _sessionRunning = false;
  bool _stopRequested = false;
  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);
  UpdatePhase? _lastPhase;
  String? _notifiedAvailableVersion;

  // ── الحالة التفاعلية ────────────────────────
  SilentUpdateState state = SilentUpdateState.idle;
  UpdateInfo? latestInfo;

  double downloadProgress = 0.0;
  int receivedBytes = 0;
  int totalBytes = 0;
  String statusMessage = '';
  String? errorMessage;
  String? downloadedFilePath;

  /// التنزيل قائم لكن لا اتصال الآن؛ يُستكمل وحده حين يعود.
  bool isWaitingForNetwork = false;

  /// يُستدعى حين يكتمل تنزيل كان جارياً والتطبيق مفتوح.
  void Function(UpdateInfo info)? onReadyToInstall;

  /// هناك تحديث ضُغط عليه ولم يُثبَّت بعد (ينزّل أو جاهز).
  bool get hasActiveUpdate =>
      _sessionRunning ||
      state == SilentUpdateState.downloading ||
      state == SilentUpdateState.readyToInstall ||
      state == SilentUpdateState.installing;

  // تنسيقات مساعدة للعرض العربي
  String get formattedProgress => '${(downloadProgress * 100).toInt()}%';
  String get formattedSize {
    final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes > 0) {
      final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$recMb ميغابايت من $totMb ميغابايت';
    }
    return '$recMb ميغابايت';
  }

  void _setState(SilentUpdateState newState, {String? msg, String? err}) {
    state = newState;
    if (msg != null) statusMessage = msg;
    if (err != null) errorMessage = err;
    notifyListeners();
  }

  Future<UpdateSession> _ensureSession() async {
    final existing = _session;
    if (existing != null) return existing;
    final dir = await _updatesDir();
    final ownerId = 'ui-$pid-${DateTime.now().microsecondsSinceEpoch}';
    return _session ??= _sessionFactory?.call(dir, ownerId, _feed) ??
        UpdateSession(dir: dir, ownerId: ownerId, feed: _feed);
  }

  // ══════════════════════════════════════════════
  // 1. متابعة تحديث بدأ من قبل
  // ══════════════════════════════════════════════

  /// يُستدعى عند كل إقلاع: إن كان هناك تحديث ضُغط عليه ولم يُثبَّت، يكمله فوراً
  /// بلا سؤال. وإن كان الإصدار قد ثُبِّت، ينظف ملفاته.
  Future<void> resumePendingUpdate() => _resumeFuture ??= _resumePendingUpdate();

  Future<void>? _resumeFuture;

  Future<void> _resumePendingUpdate() async {
    if (kIsWeb) return;
    if (_packageVersion.isEmpty) await init();
    try {
      final session = await _ensureSession();
      final job = session.readJob();
      if (job == null) {
        unawaited(_cleanupLegacyDownload());
        return;
      }
      if (!isNewerVersion(job.version, currentVersion)) {
        await UpdateBackground.cancel();
        await session.clear();
        return;
      }
      latestInfo = job.info;
      _startSession();
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] resumePendingUpdate: $e');
    }
  }

  /// ملف نزّلته النسخ السابقة في المجلد المؤقت.
  Future<void> _cleanupLegacyDownload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_legacyDownloadedPathKey);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      await prefs.remove(_legacyDownloadedPathKey);
      await prefs.remove(_legacyDownloadedVersionKey);
    } catch (_) {}
  }

  // ══════════════════════════════════════════════
  // 2. التحقق من وجود إصدار أحدث
  // ══════════════════════════════════════════════

  Future<UpdateInfo?>? _inFlightCheck;

  /// يتحقق من وجود تحديث، وإذا وُجد يظهر نافذة التحديث فوراً في السياق الحالي
  Future<UpdateInfo?> checkAndPromptUpdate({BuildContext? context}) async {
    final info = await checkForUpdate();
    if (info != null && isNewerVersion(info.version, currentVersion)) {
      final targetContext = context ?? appNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        UpdateDialog.show(targetContext, info, this);
      }
      return info;
    }
    return null;
  }

  Future<UpdateInfo?> checkForUpdate({bool ignoreDismissed = true}) async {
    // نسخة الويب (الآيفون) تتحدث وحدها مع كل فتح: لا ملف تحديث ولا مثبّت
    if (kIsWeb) return null;
    if (_packageVersion.isEmpty) await init();

    // فحص جارٍ: ننتظر نتيجته بدل طلب مكرر
    if (_inFlightCheck != null) {
      return await _inFlightCheck;
    }

    final future = _performCheckForUpdate();
    _inFlightCheck = future;
    try {
      return await future;
    } finally {
      _inFlightCheck = null;
    }
  }

  Future<UpdateInfo?> _performCheckForUpdate() async {
    // متابعة تحديث سابق تسبق أي فحص: به نعرف إن كان هناك تنزيل قائم
    if (_resumeFuture != null) await _resumeFuture;

    // تحديث قيد التنزيل أو جاهز: حالته لا تُمسّ، ولا يعود "متاحاً" من جديد
    final busy = hasActiveUpdate;
    if (!busy) _setState(SilentUpdateState.checking, msg: 'جارٍ التحقق من الخادم...');

    final UpdateInfo info;
    try {
      info = await _feed.fetchLatest();
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] خطأ في فحص التحديث: $e');
      if (busy) return latestInfo;
      _setState(SilentUpdateState.idle, err: 'تعذر الاتصال بخادم التحديثات');
      return null;
    }

    if (!isNewerVersion(info.version, currentVersion)) {
      if (busy) return latestInfo;
      latestInfo = null; // لا بلاغ كاذب
      _setState(SilentUpdateState.idle, msg: 'التطبيق محدث لأحدث إصدار ($currentVersion) ✅');
      return null;
    }

    if (busy) {
      // صدر إصدار أحدث من الذي يُنزَّل: ننتقل إليه، فالمستخدم طلب التحديث أصلاً
      final current = latestInfo;
      if (current != null && isNewerVersion(info.version, current.version)) {
        await startDownload(info);
      }
      return latestInfo;
    }

    latestInfo = info;

    // نُزّل من قبل وجاهز؟
    final session = await _ensureSession();
    final job = session.readJob();
    if (job != null && job.version == info.version) {
      final file = await session.readyFile();
      if (file != null) {
        downloadedFilePath = file.path;
        _setState(SilentUpdateState.readyToInstall, msg: 'التحديث جاهز للتثبيت بنقرة واحدة.');
        return info;
      }
    }

    _setState(SilentUpdateState.updateAvailable, msg: 'يتوفر إصدار جديد: v${info.version}');
    if (_notifiedAvailableVersion != info.version) {
      _notifiedAvailableVersion = info.version;
      AppNotificationService.instance.showUpdateAvailableNotification(info);
    }
    return info;
  }

  // ══════════════════════════════════════════════
  // 3. التنزيل
  // ══════════════════════════════════════════════

  /// يبدأ تنزيل [info] ويحفظه كمهمة قائمة. يعود فوراً؛ التنزيل يستمر إلى أن
  /// يكتمل مهما انقطع الاتصال أو أُغلق التطبيق.
  Future<void> startDownload(UpdateInfo info, {void Function(int received, int total)? onProgress}) async {
    if (kIsWeb) return;
    final job = UpdateJob.forPlatform(info, _platform);
    if (job == null) {
      _setState(SilentUpdateState.error, err: 'هذا الإصدار لا يحمل ملف تثبيت لهذا الجهاز.');
      return;
    }

    try {
      final session = await _ensureSession();
      final existing = session.readJob();
      errorMessage = null;
      if (existing == null || existing.signature != job.signature) {
        // الجلسة الجارية (هنا أو في الخلفية) ترى المهمة تبدّلت فتنتقل إليها
        await session.writeJob(job);
        downloadProgress = 0;
        receivedBytes = 0;
        totalBytes = job.size;
      }
      // بعد كتابة المهمة لا قبلها: نبضة من التنزيل السابق تصل أثناء الكتابة
      // تقارن بما على القرص، فلا تعيد الإصدار القديم إلى الواجهة
      latestInfo = info;
      _startSession();
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] startDownload: $e');
      _setState(SilentUpdateState.error, err: 'تعذر بدء التنزيل: لا يمكن الكتابة في تخزين التطبيق.');
    }
  }

  void _startSession() {
    if (_sessionRunning) return;
    _sessionRunning = true;
    _stopRequested = false;
    _setState(SilentUpdateState.downloading, msg: 'جارٍ تنزيل التحديث...');
    unawaited(_runSession());
  }

  Future<void> _runSession() async {
    final session = _session!;
    try {
      // مهمة الخلفية تبقي التنزيل حياً خارج التطبيق، وتكمله إن أُغلق
      unawaited(UpdateBackground.ensureScheduled(session.dir.path));

      final file = await session.run(onStatus: _onStatus, shouldStop: () => _stopRequested);
      if (file != null) {
        final job = session.readJob();
        if (job != null) latestInfo = job.info;
        downloadedFilePath = file.path;
        downloadProgress = 1.0;
        isWaitingForNetwork = false;
        _setState(SilentUpdateState.readyToInstall, msg: 'اكتمل التنزيل بنجاح! جاهز للتثبيت.');
        final info = latestInfo;
        if (info != null) {
          AppNotificationService.instance.showUpdateReadyNotification(info);
          onReadyToInstall?.call(info);
        }
      } else if (!_stopRequested) {
        // المهمة أُلغيت من خارج الجلسة
        _setState(SilentUpdateState.idle, msg: '');
      }
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] session: $e');
    } finally {
      _sessionRunning = false;
    }
  }

  void _onStatus(UpdateStatus status) {
    receivedBytes = status.received;
    totalBytes = status.total;
    downloadProgress = status.fraction;
    isWaitingForNetwork = status.phase == UpdatePhase.waiting;
    statusMessage = switch (status.phase) {
      UpdatePhase.downloading => 'جارٍ تنزيل التحديث...',
      UpdatePhase.waiting => 'بانتظار الاتصال بالإنترنت… يُستكمل التنزيل تلقائياً',
      UpdatePhase.verifying => 'جارٍ التحقق من سلامة الملف...',
      UpdatePhase.noSpace => 'لا توجد مساحة كافية على الجهاز. أفرغ بعض المساحة وسيُستكمل التنزيل.',
      UpdatePhase.ready => 'اكتمل التنزيل بنجاح! جاهز للتثبيت.',
    };
    if (status.version != latestInfo?.version) {
      final job = _session?.readJob();
      if (job != null) latestInfo = job.info;
    }
    if (state != SilentUpdateState.readyToInstall && state != SilentUpdateState.installing) {
      state = SilentUpdateState.downloading;
    }

    // النبضة كل ثانية تقريباً؛ الواجهة لا تحتاج أكثر، وتغيّر الطور يُبلَّغ فوراً
    final now = DateTime.now();
    if (status.phase != _lastPhase || now.difference(_lastProgressNotify).inMilliseconds >= 200) {
      _lastPhase = status.phase;
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  /// يرمي ما نُزّل ويبدأ من الصفر (إن رفض النظام تثبيت الملف مثلاً).
  Future<void> restartDownload() async {
    final info = latestInfo;
    if (info == null) return;
    _stopRequested = true;
    await UpdateBackground.cancel();
    for (var i = 0; i < 60 && _sessionRunning; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final session = await _ensureSession();
    await session.clear();
    downloadedFilePath = null;
    downloadProgress = 0;
    receivedBytes = 0;
    await startDownload(info);
  }

  // ══════════════════════════════════════════════
  // 4. التثبيت (Android & Windows)
  // ══════════════════════════════════════════════

  /// يُشغّل التثبيت على الهاتف أو الحاسوب
  Future<void> installDownloadedUpdate() async {
    final session = await _ensureSession();
    final file = await session.readyFile();
    if (file == null) {
      // الملف غير مكتمل أو حُذف: نكمل تنزيله بدل إعلان خطأ
      final info = latestInfo;
      if (info != null) await startDownload(info);
      return;
    }
    final path = file.path;
    downloadedFilePath = path;

    _setState(SilentUpdateState.installing, msg: 'جارٍ فتح مثبت النظام...');

    if (Platform.isAndroid) {
      final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        _setState(
          SilentUpdateState.readyToInstall,
          msg: 'يرجى تأكيد التثبيت، أو تفعيل خيار «السماح بتثبيت التطبيقات غير المعروفة» لمحراب في إعدادات الهاتف.',
        );
      } else {
        _setState(SilentUpdateState.readyToInstall, msg: 'تم فتح مثبت الحزمة بنجاح.');
      }
    } else if (Platform.isWindows) {
      // تشغيل المثبت بشكل مستقل وإغلاق التطبيق الحالي لفك قفل الملفات
      try {
        await Process.start(path, ['/SILENT'], mode: ProcessStartMode.detached);
        await Future.delayed(const Duration(milliseconds: 600));
        exit(0);
      } catch (e) {
        await Process.start(path, [], mode: ProcessStartMode.detached);
        await Future.delayed(const Duration(milliseconds: 600));
        exit(0);
      }
    }
  }

  // ══════════════════════════════════════════════
  // 5. المساعدات
  // ══════════════════════════════════════════════

  /// فحص دوري والتطبيق مفتوح. إن وُجد إصدار جديد لم يُضغط عليه بعد يُستدعى
  /// [onUpdateFound] (لعرض النافذة)؛ لا يُنزَّل شيء بلا طلب المستخدم.
  void startPeriodicSilentCheck({
    Duration interval = const Duration(hours: 12),
    void Function(UpdateInfo)? onUpdateFound,
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      final info = await checkForUpdate();
      if (info != null && !_sessionRunning) onUpdateFound?.call(info);
    });
  }

  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _stopRequested = true;
    super.dispose();
  }

  /// مقارنة دقيقة تحدد إن كان [latest] أحدث قطعياً من [current].
  /// تُهمل بادئة 'v' وتتعامل مع لاحقة البناء '+build' بدقة لتفادي أي بلاغات خاطئة.
  bool isNewerVersion(String latest, String current) {
    final effectiveCurrent = current.trim().isNotEmpty ? current.trim() : currentVersion;
    return isVersionNewer(latest, effectiveCurrent);
  }
}
