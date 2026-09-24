// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_config.dart';

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
      version: (json['tag_name'] as String? ?? '').replaceFirst('v', ''),
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

  // ── الإصدار الحالي للتطبيق ─────────────────
  static String _packageVersion = '';
  static String get currentVersion => _packageVersion;

  /// تُقرأ مرة واحدة عند الإقلاع من PackageInfo
  static Future<void> init() async {
    if (_packageVersion.isNotEmpty) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _packageVersion = info.version;
    } catch (_) {
      _packageVersion = '1.0.1';
    }
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
  // 1. التحقق من وجود إصدار أحدث
  // ══════════════════════════════════════════════

  Future<UpdateInfo?> checkForUpdate({bool ignoreDismissed = true}) async {
    if (_packageVersion.isEmpty) await init();

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

      if (!ignoreDismissed && await isVersionDismissed(info.version)) {
        _setState(SilentUpdateState.idle, msg: '');
        return null;
      }

      // تحقق إن كان الملف مُنزلاً مسبقاً وجاهزاً
      final savedPath = await getSavedDownloadedFilePath(info.version);
      if (savedPath != null) {
        downloadedFilePath = savedPath;
        _setState(SilentUpdateState.readyToInstall, msg: 'التحديث جاهز للتثبيت بنقرة واحدة.');
        return info;
      }

      _setState(SilentUpdateState.updateAvailable, msg: 'يتوفر إصدار جديد: v${info.version}');
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
    final info = await checkForUpdate(ignoreDismissed: false);
    if (info != null && state != SilentUpdateState.readyToInstall) {
      await startDownload(info);
      if (state == SilentUpdateState.readyToInstall) {
        onReadyToInstall?.call(info);
      }
    }
  }

  // ══════════════════════════════════════════════
  // 4. المساعدات وتجاهل الإصدارات
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  Future<bool> isVersionDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedVersionKey) == version;
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

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  bool isNewerVersion(String latest, String current) {
    try {
      final l = _parseSemver(latest);
      final c = _parseSemver(current);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return latest != current;
    }
  }

  List<int> _parseSemver(String v) {
    final parts = v.split('.');
    while (parts.length < 3) {
      parts.add('0');
    }
    return parts.map((p) => int.tryParse(p) ?? 0).toList();
  }
}
