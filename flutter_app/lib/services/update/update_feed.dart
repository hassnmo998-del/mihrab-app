import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../update_config.dart';
import 'update_models.dart';

/// يسأل: ما آخر إصدار منشور؟
///
/// المصدر الأول `update.json` على موقعنا: يُنشر مع ملفات التثبيت في النشرة
/// نفسها، يصل عبر CDN الموقع (غير محجوب)، وبلا حدّ لعدد الطلبات. إن تعذّر
/// فالمصدر الثاني GitHub API، وله حدّ 60 طلباً في الساعة لكل عنوان IP.
class UpdateFeed {
  UpdateFeed({
    HttpClient Function()? clientFactory,
    String? manifestUrl,
    String? apiUrl,
    this.timeout = const Duration(seconds: 20),
  })  : _clientFactory = clientFactory ?? HttpClient.new,
        manifestUrl = manifestUrl ?? kUpdateManifestUrl,
        apiUrl = apiUrl ?? kUpdateApiUrl;

  static const String kSiteBaseUrl = 'https://$kGithubRepoOwner.github.io/$kGithubRepoName/';
  static const String kUpdateManifestUrl = '${kSiteBaseUrl}update.json';
  static const String kCdnAndroidUrl = '${kSiteBaseUrl}downloads/mihrab-android.apk';
  static const String kCdnWindowsUrl = '${kSiteBaseUrl}downloads/mihrab-windows.exe';
  static const String kUpdateApiUrl =
      'https://api.github.com/repos/$kGithubRepoOwner/$kGithubRepoName/releases/latest';

  final HttpClient Function() _clientFactory;
  final String manifestUrl;
  final String apiUrl;
  final Duration timeout;

  /// آخر إصدار منشور. يرمي إن تعذّر المصدران معاً (لا اتصال).
  Future<UpdateInfo> fetchLatest() async {
    try {
      final json = await _getJson(manifestUrl);
      final info = UpdateInfo.fromManifest(json, Uri.parse(manifestUrl));
      if (info.version.isNotEmpty) return info;
    } catch (_) {
      // غير منشور بعد، أو الموقع غير متاح: المصدر الثاني
    }
    final json = await _getJson(apiUrl, headers: const {'Accept': 'application/vnd.github+json'});
    return UpdateInfo.fromJson(json, cdnAndroidUrl: kCdnAndroidUrl, cdnWindowsUrl: kCdnWindowsUrl);
  }

  Future<Map<String, dynamic>> _getJson(String url, {Map<String, String> headers = const {}}) async {
    final client = _clientFactory()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().timeout(const Duration(seconds: 5)).catchError((_) {});
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}
