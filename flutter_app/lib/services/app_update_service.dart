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
  /// رقم الإصدار بصيغة semver مثل "1.2.0"
  final String version;

  /// رابط تنزيل ملف EXE/MSI لنظام Windows (إن وُجد)
  final String? downloadUrlWindows;

  /// رابط تنزيل ملف APK لنظام Android (إن وُجد)
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
      downloadUrlWindows: _extractAssetUrl(assets, ['windows', '.exe', '.msi', '.msix']),
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
// SilentUpdateState — حالة التحديث الصامت
// ─────────────────────────────────────────────

enum SilentUpdateState {
  idle,        // لا يوجد شيء
  checking,    // جارٍ التحقق من GitHub
  downloading, // جارٍ التنزيل في الخلفية
  readyToInstall, // اكتمل التنزيل (Android فقط — ينتظر إشعار)
  installing,  // جارٍ التثبيت
  done,        // اكتمل التثبيت (Windows)
  error,       // حدث خطأ
}

// ─────────────────────────────────────────────
// AppUpdateService — خدمة التحديث الصامت
// ─────────────────────────────────────────────

/// خدمة Singleton تفحص وتنزّل وتثبّت التحديثات بصمت تام قدر الإمكان.
///
/// - **Windows**: تنزيل كامل صامت + تثبيت صامت بـ /S flag
/// - **Android**: تنزيل صامت في الخلفية → إشعار واحد فقط عند الجهوز
class AppUpdateService {
  // ── Singleton ──────────────────────────────
  AppUpdateService._internal();
  static final AppUpdateService instance = AppUpdateService._internal();

  // ── الإصدار الحالي للتطبيق ─────────────────

  /// الإصدار المبني فعلاً، مقروءاً من الحزمة لا مكتوباً هنا.
  ///
  /// كان ثابتاً مكتوباً بجانب رقم `pubspec.yaml`: رقمان لشيء واحد يفترقان عند
  /// أول مرة يُنسى أحدهما. وأثر افتراقهما صامت في الاتجاهين — إن تخلّف هذا
  /// الرقم عن الحقيقة عُرض تحديثٌ لنسخة التطبيقُ عليها أصلاً، وإن سبقها لم
  /// يُعرض التحديث إطلاقاً. ولا شيء في الحالتين يدلّ على السبب.
  static String _packageVersion = '';

  static String get currentVersion => _packageVersion;

  /// تُقرأ مرة واحدة عند الإقلاع، قبل أي فحص تحديث.
  static Future<void> init() async {
    if (_packageVersion.isNotEmpty) return;
    final info = await PackageInfo.fromPlatform();
    _packageVersion = info.version;
  }

  // ── مفاتيح SharedPreferences ───────────────
  static const String _dismissedVersionKey  = 'dismissed_update_version';
  static const String _downloadedPathKey    = 'update_downloaded_path';
  static const String _downloadedVersionKey = 'update_downloaded_version';

  // ── GitHub API ─────────────────────────────
  static const String _apiUrl =
      'https://api.github.com/repos/$kGithubRepoOwner/$kGithubRepoName/releases/latest';

  // ── الحالة الداخلية ────────────────────────
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 10), // وقت كافٍ لتنزيل ملف كبير
    headers: {'Accept': 'application/vnd.github+json'},
  ));

  Timer? _periodicTimer;

  /// الحالة الحالية لعملية التحديث
  SilentUpdateState state = SilentUpdateState.idle;

  /// آخر معلومات إصدار تم اكتشافه
  UpdateInfo? latestInfo;

  /// تقدم التنزيل (0.0 → 1.0)
  double downloadProgress = 0.0;

  /// Callback يُستدعى عند تغيّر الحالة (للواجهة إن أراد أحد يستمع)
  void Function(SilentUpdateState)? onStateChanged;

  // ══════════════════════════════════════════════
  // 1. الفحص والتنزيل الصامت التلقائي
  // ══════════════════════════════════════════════

  /// نقطة البداية الرئيسية.
  /// يفحص GitHub ولو في إصدار جديد ينزّله مباشرة بصمت تام — بدون أي dialog.
  ///
  /// - Windows: ينزّل ويثبّت تلقائياً /S
  /// - Android: ينزّل ثم يستدعي [onReadyToInstall] لإظهار إشعار واحد
  Future<void> checkAndDownloadSilently({
    void Function(UpdateInfo info)? onReadyToInstall,
  }) async {
    if (state == SilentUpdateState.downloading ||
        state == SilentUpdateState.installing) {
      return;
    }

    _setState(SilentUpdateState.checking);

    final info = await checkForUpdate();
    if (info == null) {
      _setState(SilentUpdateState.idle);
      return;
    }

    latestInfo = info;
    _setState(SilentUpdateState.downloading);

    try {
      if (Platform.isWindows) {
        final url = info.downloadUrlWindows;
        if (url == null) { _setState(SilentUpdateState.idle); return; }
        await _downloadAndInstallWindowsSilent(url, info.version);

      } else if (Platform.isAndroid) {
        final url = info.downloadUrlAndroid;
        if (url == null) { _setState(SilentUpdateState.idle); return; }
        final path = await _downloadApkSilent(url, info.version);
        if (path != null) {
          _setState(SilentUpdateState.readyToInstall);
          onReadyToInstall?.call(info);
        } else {
          _setState(SilentUpdateState.idle);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] خطأ صامت: $e');
      _setState(SilentUpdateState.error);
    }
  }

  /// تنزيل وتثبيت مباشر للتوافق مع شاشات الحوار المباشرة
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url = Platform.isWindows ? info.downloadUrlWindows : info.downloadUrlAndroid;
    if (url == null) throw Exception('No download URL available');
    if (Platform.isWindows) {
      await _downloadAndInstallWindowsSilent(url, info.version);
    } else if (Platform.isAndroid) {
      final path = await _downloadApkSilent(url, info.version);
      if (path != null) {
        await installDownloadedApk();
      }
    }
  }

  // ══════════════════════════════════════════════
  // 2. التحقق من وجود إصدار أحدث
  // ══════════════════════════════════════════════

  Future<UpdateInfo?> checkForUpdate() async {
    // بلا الإصدار الحالي لا معنى للمقارنة: سلسلة فارغة تُقرأ كأقدم من أي شيء،
    // فيُعرض تحديث عند كل فحص. [init] تُستدعى عند الإقلاع، وهذا السطر يضمن ألّا
    // يتحوّل نسيانها إلى تحديث وهمي متكرّر.
    await init();
    if (currentVersion.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(_apiUrl);
      if (response.statusCode != 200 || response.data == null) return null;

      final info = UpdateInfo.fromJson(response.data!);
      if (!_isNewerVersion(info.version, currentVersion)) return null;
      if (await isVersionDismissed(info.version)) return null;

      return info;
    } on DioException catch (e) {
      if (kDebugMode) print('[AppUpdateService] خطأ شبكة: $e');
      return null;
    } catch (e) {
      if (kDebugMode) print('[AppUpdateService] خطأ غير متوقع: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // 3أ. Windows — تنزيل وتثبيت صامت تماماً
  // ══════════════════════════════════════════════

  Future<void> _downloadAndInstallWindowsSilent(String url, String version) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}\\mihrab_update_$version.exe';

    // تنزيل صامت في الخلفية
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) downloadProgress = received / total;
      },
      options: Options(
        followRedirects: true,
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    _setState(SilentUpdateState.installing);

    // تثبيت صامت تام — المستخدم لا يرى شيئاً
    // /S = Silent mode (NSIS installer flag)
    // /SILENT أو /VERYSILENT لـ InnoSetup
    await Process.run(savePath, ['/S', '/SILENT', '/VERYSILENT'],
        runInShell: false);

    _setState(SilentUpdateState.done);
    if (kDebugMode) print('[AppUpdateService] ✅ Windows: تم التثبيت الصامت');
  }

  // ══════════════════════════════════════════════
  // 3ب. Android — تنزيل صامت → يرجع المسار
  // ══════════════════════════════════════════════

  Future<String?> _downloadApkSilent(String url, String version) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/mihrab_update_$version.apk';

    // لو الملف موجود بالفعل (نُزّل سابقاً) نتجنب إعادة التنزيل
    if (File(savePath).existsSync()) {
      if (kDebugMode) print('[AppUpdateService] APK موجود مسبقاً: $savePath');
      return savePath;
    }

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) downloadProgress = received / total;
      },
      options: Options(
        followRedirects: true,
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    // حفظ المسار في SharedPreferences للاستخدام عند الضغط على الإشعار
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadedPathKey, savePath);
    await prefs.setString(_downloadedVersionKey, version);

    if (kDebugMode) print('[AppUpdateService] ✅ Android: APK جاهز في $savePath');
    return savePath;
  }

  // ══════════════════════════════════════════════
  // 4. تثبيت APK عند ضغط المستخدم على الإشعار
  // ══════════════════════════════════════════════

  /// يُشغّل مثبّت APK — يُستدعى عند ضغط المستخدم على الإشعار
  Future<void> installDownloadedApk() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_downloadedPathKey);
    if (path == null || !File(path).existsSync()) return;

    _setState(SilentUpdateState.installing);
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  // ══════════════════════════════════════════════
  // 5. إدارة تجاهل الإصدار
  // ══════════════════════════════════════════════

  Future<void> dismissVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  Future<bool> isVersionDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedVersionKey) == version;
  }

  // ══════════════════════════════════════════════
  // 6. الفحص الدوري الصامت
  // ══════════════════════════════════════════════

  /// يبدأ فحصاً دورياً صامتاً تماماً في الخلفية.
  /// [onReadyToInstall] يُستدعى فقط على Android عند اكتمال التنزيل
  void startPeriodicSilentCheck({
    Duration interval = const Duration(hours: 24),
    void Function(UpdateInfo)? onReadyToInstall,
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      await checkAndDownloadSilently(onReadyToInstall: onReadyToInstall);
    });
    if (kDebugMode) print('[AppUpdateService] فحص صامت كل ${interval.inHours}h');
  }

  // ══════════════════════════════════════════════
  // 7. مقارنة الإصدارات
  // ══════════════════════════════════════════════

  bool _isNewerVersion(String remote, String current) {
    try {
      final r = _parseSemver(remote);
      final c = _parseSemver(current);
      for (int i = 0; i < 3; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false;
    } catch (_) { return false; }
  }

  List<int> _parseSemver(String v) {
    final parts = v.split('.');
    while (parts.length < 3) {
      parts.add('0');
    }
    return parts.map((p) => int.tryParse(p) ?? 0).toList();
  }

  // ══════════════════════════════════════════════
  // 8. تنظيف الموارد
  // ══════════════════════════════════════════════

  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _dio.close();
  }

  void _setState(SilentUpdateState newState) {
    state = newState;
    onStateChanged?.call(newState);
  }
}
