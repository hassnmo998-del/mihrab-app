// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_config.dart';
import 'app_notification_service.dart';
import '../core/navigation/navigator_key.dart';
import '../widgets/update_dialog.dart';

// ─────────────────────────────────────────────
// UpdateInfo — نموذج بيانات الإصدار الجديد
// ─────────────────────────────────────────────

/// يحمل كل المعلومات المتعلقة بإصدار جديد تم جلبه من GitHub Releases.
class UpdateInfo {
  /// رقم الإصدار بصيغة semver مثل "1.0.1"
  final String version;

  /// رابط تنزيل ملف EXE لنظام Windows
  final String? downloadUrlWindows;

  /// رابط تنزيل ملف APK لنظام Android
  final String? downloadUrlAndroid;

  /// ملاحظات الإصدار (release notes)
  final String releaseNotes;

  /// تاريخ نشر الإصدار
  final DateTime publishedAt;

  const UpdateInfo({
    required this.version,
    this.downloadUrlWindows,
    this.downloadUrlAndroid,
    required this.releaseNotes,
    required this.publishedAt,
  });

  /// بناء [UpdateInfo] من استجابة JSON الخاصة بـ GitHub Releases API.
  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final List<dynamic> assets = json['assets'] as List<dynamic>? ?? [];

    return UpdateInfo(
      version: AppUpdateService.cleanVersion(json['tag_name'] as String? ?? ''),
      downloadUrlWindows: _extractAssetUrl(assets, ['windows', '.exe', '.msi']),
      downloadUrlAndroid: _extractAssetUrl(assets, ['android', '.apk']),
      releaseNotes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static String? _extractAssetUrl(List<dynamic> assets, List<String> keywords) {
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final browserDownloadUrl = asset['browser_download_url'] as String?;
      if (browserDownloadUrl != null &&
          keywords.any((kw) => name.contains(kw.toLowerCase()))) {
        return browserDownloadUrl;
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────
// SilentUpdateState — حالات التحديث
// ─────────────────────────────────────────────

enum SilentUpdateState {
  idle,            // خامل / لا يوجد شيء
  checking,        // جارٍ التحقق من التحديثات
  updateAvailable, // يتوفر تحديث جديد
  downloading,     // جارٍ التنزيل مع شريط تقدم ونسبة مئوية
  paused,          // تم الإيقاف المؤقت (يمكن الاستئناف)
  readyToInstall,  // اكتمل التنزيل وجاهز للتثبيت بنقرة واحدة
  installing,      // جارٍ فتح مثبت النظام
  done,            // اكتملت العملية
  error,           // حدث خطأ في الشبكة أو الملف
}

// ─────────────────────────────────────────────
// AppUpdateService — خدمة التحديث الذكية والمتقدمة
// ─────────────────────────────────────────────

class AppUpdateService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────
  AppUpdateService._internal();
  static final AppUpdateService instance = AppUpdateService._internal();

  /// تنظيف رقم الإصدار من البادئات (v / V) واللواحق (+build / -beta)
  static String cleanVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1).trim();
    }
    if (s.contains('+')) {
      s = s.split('+')[0].trim();
    }
    if (s.contains('-')) {
      s = s.split('-')[0].trim();
    }
    return s;
  }

  // ── الإصدار الحالي للتطبيق ─────────────────
  static String _packageVersion = '';
  static String get currentVersion => _packageVersion.isNotEmpty ? _packageVersion : kCurrentAppVersion;

  /// تُقرأ مرة واحدة عند الإقلاع من PackageInfo
  static Future<void> init() async {
    if (_packageVersion.isEmpty) {
      try {
        final info = await PackageInfo.fromPlatform();
        final cleaned = cleanVersion(info.version);
        _packageVersion = cleaned.isNotEmpty ? cleaned : kCurrentAppVersion;
      } catch (_) {
        _packageVersion = kCurrentAppVersion;
      }
    }
    // مسح أي خيار سابق لتجاهل التحديثات
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dismissedVersionKey);

      // تنظيف أي ملف تحديث قديم تم تنزيله إن كان الإصدار الحالي مساوياً له أو أحدث منه
      final savedVer = prefs.getString(_downloadedVersionKey);
      if (savedVer != null) {
        final cur = Semver.parse(_packageVersion);
        final sav = Semver.parse(savedVer);
        if (!sav.isStrictlyNewerThan(cur)) {
          final savedPath = prefs.getString(_downloadedPathKey);
          if (savedPath != null) {
            try {
              final f = File(savedPath);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }
          await prefs.remove(_downloadedPathKey);
          await prefs.remove(_downloadedVersionKey);
        }
      }
    } catch (_) {}
  }

  // ── مفاتيح SharedPreferences ───────────────
  static const String _dismissedVersionKey  = 'dismissed_update_version';
  static const String _downloadedPathKey    = 'update_downloaded_path';
  static const String _downloadedVersionKey = 'update_downloaded_version';

  // ── روابط المخدم المباشر السريع (Fastly CDN) و GitHub API ───
  static const String kCdnAndroidUrl =
      'https://hassnmo998-del.github.io/mihrab-app/downloads/mihrab-android.apk';
  static const String kCdnWindowsUrl =
      'https://hassnmo998-del.github.io/mihrab-app/downloads/mihrab-windows.exe';

  static const String _apiUrl =
      'https://api.github.com/repos/$kGithubRepoOwner/$kGithubRepoName/releases/latest';

  // ── عميل الشبكة ────────────────────────────
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 25),
    receiveTimeout: const Duration(minutes: 20),
    headers: {'Accept': 'application/vnd.github+json'},
  ));

  CancelToken? _cancelToken;
  Timer? _periodicTimer;

  // ── الحالة التفاعلية ────────────────────────
  SilentUpdateState state = SilentUpdateState.idle;
  UpdateInfo? latestInfo;

  double downloadProgress = 0.0;
  int receivedBytes = 0;
  int totalBytes = 0;
  String statusMessage = '';
  String? errorMessage;
  String? downloadedFilePath;

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

  // ══════════════════════════════════════════════
  // 1. التحقق من وجود إصدار أحدث وعرض الحوار
  // ══════════════════════════════════════════════

  /// يتحقق من وجود تحديث، وإذا وُجد يظهر نافذة التحديث فوراً في السياق الحالي
  Future<UpdateInfo?> checkAndPromptUpdate({BuildContext? context}) async {
    final info = await checkForUpdate();
    if (info != null) {
      final targetContext = context ?? appNavigatorKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        UpdateDialog.show(targetContext, info, this);
      }
    }
    return info;
  }

  Future<UpdateInfo?> checkForUpdate({bool ignoreDismissed = true}) async {
    if (_packageVersion.isEmpty) await init();

    // تجنب الفحص المزدوج إذا كان الفحص جارياً حالياً
    if (state == SilentUpdateState.checking) {
      return latestInfo;
    }

    _setState(SilentUpdateState.checking, msg: 'جارٍ التحقق من الخادم...');

    try {
      final response = await _dio.get(_apiUrl);
      if (response.statusCode != 200) {
        _setState(SilentUpdateState.idle, msg: '');
        return null;
      }

      final info = UpdateInfo.fromJson(response.data as Map<String, dynamic>);
      latestInfo = info;

      final hasNewer = isNewerVersion(info.version, _packageVersion);
      if (!hasNewer) {
        _setState(SilentUpdateState.idle, msg: 'التطبيق محدث لأحدث إصدار ($currentVersion) ✅');
        return null;
      }

      // تحقق إن كان الملف مُنزلاً مسبقاً وجاهزاً
      final savedPath = await getSavedDownloadedFilePath(info.version);
      if (savedPath != null) {
        downloadedFilePath = savedPath;
        _setState(SilentUpdateState.readyToInstall, msg: 'التحديث جاهز للتثبيت بنقرة واحدة.');
        AppNotificationService.instance.showUpdateReadyNotification(info);
        return info;
      }

      _setState(SilentUpdateState.updateAvailable, msg: 'يتوفر إصدار جديد: v${info.version}');
      AppNotificationService.instance.showUpdateAvailableNotification(info);
      return info;
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] خطأ في فحص التحديث: $e');
      _setState(SilentUpdateState.idle, err: 'تعذر الاتصال بخادم التحديثات');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 2. التنزيل الحقيقي القابل للاستئناف والإيقاف
  // ══════════════════════════════════════════════

  Future<void> startDownload(UpdateInfo info, {void Function(int received, int total)? onProgress}) async {
    if (state == SilentUpdateState.downloading) return;

    _cancelToken?.cancel('new_download_started');
    _cancelToken = CancelToken();

    latestInfo = info;
    errorMessage = null;

    final dir = await getTemporaryDirectory();
    final isWin = Platform.isWindows;
    final ext = isWin ? 'exe' : 'apk';
    final savePath = '${dir.path}/mihrab_update_${info.version}.$ext';
    downloadedFilePath = savePath;

    final primaryUrl = isWin ? kCdnWindowsUrl : kCdnAndroidUrl;
    final fallbackUrl = isWin ? info.downloadUrlWindows : info.downloadUrlAndroid;

    _setState(SilentUpdateState.downloading, msg: 'جارٍ الاتصال وبدء التنزيل...');

    try {
      try {
        await _performResumableDownload(primaryUrl, savePath, onProgress);
      } catch (e) {
        if (_cancelToken?.isCancelled ?? false) rethrow;
        if (fallbackUrl != null && fallbackUrl != primaryUrl) {
          if (kDebugMode) print('[AppUpdateService] الانتقال إلى الرابط الاحتياطي: $fallbackUrl');
          await _performResumableDownload(fallbackUrl, savePath, onProgress);
        } else {
          rethrow;
        }
      }

      final file = File(savePath);
      if (!await file.exists() || await file.length() < 100000) {
        throw Exception('ملف التحديث غير مكتمل أو تالف');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_downloadedPathKey, savePath);
      await prefs.setString(_downloadedVersionKey, info.version);

      _setState(SilentUpdateState.readyToInstall, msg: 'اكتمل التنزيل بنجاح! جاهز للتثبيت.');
      AppNotificationService.instance.showUpdateReadyNotification(info);
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        _setState(SilentUpdateState.paused, msg: 'تم إيقاف التنزيل مؤقتاً');
      } else {
        if (kDebugMode) print('[AppUpdateService] خطأ أثناء التنزيل: $e');
        _setState(SilentUpdateState.error, err: 'فشل التنزيل: تأكد من اتصال الإنترنت وحاول مجدداً');
      }
    }
  }

  /// تنزيل حقيقي بدعم استئناف الأجزاء عبر HTTP Range Header
  Future<void> _performResumableDownload(
    String url,
    String savePath,
    void Function(int received, int total)? onProgress,
  ) async {
    final file = File(savePath);
    int existingLength = 0;
    if (await file.exists()) {
      existingLength = await file.length();
    }

    final headers = <String, dynamic>{};
    if (existingLength > 0) {
      headers['Range'] = 'bytes=$existingLength-';
    }

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers.isNotEmpty ? headers : null,
        followRedirects: true,
        validateStatus: (s) => s != null && (s == 200 || s == 206),
      ),
      cancelToken: _cancelToken,
    );

    final isPartial = response.statusCode == 206;
    if (!isPartial) {
      existingLength = 0;
    }

    final fileMode = (isPartial && existingLength > 0) ? FileMode.append : FileMode.write;
    final sink = file.openWrite(mode: fileMode);

    final responseLength = int.tryParse(response.headers.value(HttpHeaders.contentLengthHeader) ?? '') ?? 0;
    final total = isPartial ? (existingLength + responseLength) : responseLength;
    int received = existingLength;

    totalBytes = total;
    receivedBytes = received;
    if (total > 0) {
      downloadProgress = (received / total).clamp(0.0, 1.0);
    }
    notifyListeners();

    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        receivedBytes = received;
        if (total > 0) {
          downloadProgress = (received / total).clamp(0.0, 1.0);
        }
        onProgress?.call(received, total);
        notifyListeners();
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// إيقاف التنزيل مؤقتاً لحفظ التقدم
  void pauseOrCancelDownload() {
    if (state == SilentUpdateState.downloading) {
      _cancelToken?.cancel('paused_by_user');
      _setState(SilentUpdateState.paused, msg: 'تم إيقاف التنزيل مؤقتاً');
    }
  }

  /// استئناف التنزيل من النقطة التي توقف عندها
  Future<void> resumeDownload() async {
    if (latestInfo != null) {
      await startDownload(latestInfo!);
    }
  }

  /// إلغاء التنزيل كلياً وحذف الملف المؤقت
  Future<void> cancelDownload() async {
    _cancelToken?.cancel('cancelled_by_user');
    downloadProgress = 0.0;
    receivedBytes = 0;
    totalBytes = 0;
    if (downloadedFilePath != null) {
      try {
        final f = File(downloadedFilePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadedPathKey);
    await prefs.remove(_downloadedVersionKey);
    _setState(SilentUpdateState.updateAvailable, msg: 'تم إلغاء التنزيل');
  }

  // ══════════════════════════════════════════════
  // 3. التثبيت الدقيق (Android & Windows)
  // ══════════════════════════════════════════════

  /// يُشغّل التثبيت على الهاتف أو الحاسوب
  Future<void> installDownloadedUpdate() async {
    final path = downloadedFilePath ?? await getSavedDownloadedFilePath(latestInfo?.version ?? '');
    if (path == null || !File(path).existsSync()) {
      _setState(SilentUpdateState.error, err: 'ملف التثبيت غير موجود، يرجى إعادة التنزيل.');
      return;
    }

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

  // للتوافق مع الشيفرات السابقة
  Future<void> installDownloadedApk() => installDownloadedUpdate();

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    await startDownload(info, onProgress: onProgress);
    if (state == SilentUpdateState.readyToInstall) {
      await installDownloadedUpdate();
    }
  }

  Future<void> checkAndDownloadSilently({
    void Function(UpdateInfo info)? onReadyToInstall,
  }) async {
    final info = await checkForUpdate();
    if (info != null && state != SilentUpdateState.readyToInstall) {
      await startDownload(info);
      if (state == SilentUpdateState.readyToInstall) {
        onReadyToInstall?.call(info);
      }
    }
  }

  // ══════════════════════════════════════════════
  // 4. المساعدات
  // ══════════════════════════════════════════════

  Future<String?> getSavedDownloadedFilePath(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final savedVer = prefs.getString(_downloadedVersionKey);
    final savedPath = prefs.getString(_downloadedPathKey);
    if (savedVer == version && savedPath != null && File(savedPath).existsSync()) {
      return savedPath;
    }
    return null;
  }

  Future<void> dismissVersion(String version) async {
    // التحديثات أصبحت إجبارية العرض؛ لا يمكن حجب التحديثات نهائياً
  }

  Future<bool> isVersionDismissed(String version) async {
    return false;
  }

  void startPeriodicSilentCheck({
    Duration interval = const Duration(hours: 12),
    void Function(UpdateInfo)? onReadyToInstall,
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      await checkAndDownloadSilently(onReadyToInstall: onReadyToInstall);
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
    _cancelToken?.cancel();
    super.dispose();
  }

  /// مقارنة دقيقة تحدد إن كان [latest] أحدث قطعياً من [current].
  /// تُهمل بادئة 'v' وتتعامل مع لاحقة البناء '+build' بدقة لتفادي أي بلاغات خاطئة.
  bool isNewerVersion(String latest, String current) {
    try {
      final l = Semver.parse(latest);
      final c = Semver.parse(current);
      return l.isStrictlyNewerThan(c);
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────
// Semver — محلل ومقارن دقيق لإصدارات التطبيق
// ─────────────────────────────────────────────

class Semver implements Comparable<Semver> {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const Semver({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  factory Semver.parse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1).trim();
    }
    int buildNum = 0;
    if (s.contains('+')) {
      final plusParts = s.split('+');
      s = plusParts[0].trim();
      if (plusParts.length > 1) {
        buildNum = int.tryParse(plusParts[1].trim()) ?? 0;
      }
    }
    if (s.contains('-')) {
      s = s.split('-')[0].trim();
    }
    final dotParts = s.split('.');
    final major = dotParts.isNotEmpty ? (int.tryParse(dotParts[0].trim()) ?? 0) : 0;
    final minor = dotParts.length > 1 ? (int.tryParse(dotParts[1].trim()) ?? 0) : 0;
    final patch = dotParts.length > 2 ? (int.tryParse(dotParts[2].trim()) ?? 0) : 0;

    return Semver(
      major: major,
      minor: minor,
      patch: patch,
      build: buildNum,
    );
  }

  @override
  int compareTo(Semver other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (build > 0 && other.build > 0 && build != other.build) {
      return build.compareTo(other.build);
    }
    return 0;
  }

  /// يتحقق مما إذا كان هذا الإصدار أحدث قطعياً من الإصدار الآخر.
  bool isStrictlyNewerThan(Semver other) {
    if (major > other.major) return true;
    if (major < other.major) return false;
    if (minor > other.minor) return true;
    if (minor < other.minor) return false;
    if (patch > other.patch) return true;
    if (patch < other.patch) return false;
    // إذا كانت الأرقام الرئيسية متطابقة تماماً (مثل 1.0.3 و 1.0.3)
    if (build > 0 && other.build > 0) {
      return build > other.build;
    }
    return false;
  }

  @override
  String toString() => '$major.$minor.$patch${build > 0 ? '+$build' : ''}';
}
