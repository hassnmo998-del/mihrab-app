import 'dart:convert';

/// "v1.0.9+9" ← "1.0.9": بلا بادئة v ولا لاحقة البناء.
String cleanVersion(String v) {
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

/// هل [latest] أحدث قطعياً من [current]؟ نص فارغ أو غير مفهوم لا يُعدّ تحديثاً.
bool isVersionNewer(String latest, String current) {
  final l = latest.trim(), c = current.trim();
  if (l.isEmpty || c.isEmpty) return false;
  try {
    return Semver.parse(l).isStrictlyNewerThan(Semver.parse(c));
  } catch (_) {
    return false;
  }
}

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

    return Semver(major: major, minor: minor, patch: patch, build: buildNum);
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
    // الأرقام الرئيسية متطابقة (مثل 1.0.3 و 1.0.3): يفصل رقم البناء إن وُجد عند الطرفين
    if (build > 0 && other.build > 0) {
      return build > other.build;
    }
    return false;
  }

  @override
  String toString() => '$major.$minor.$patch${build > 0 ? '+$build' : ''}';
}

/// ملف التثبيت لمنصة واحدة: من أين يُنزَّل، وكم حجمه، وما بصمته.
class UpdateAsset {
  /// الروابط بترتيب الأفضلية؛ كلها يجب أن تخدم الملف نفسه.
  final List<String> urls;

  /// الحجم بالبايت (0 = غير معروف).
  final int size;

  /// بصمة sha256 بحروف صغيرة ('' = غير معروفة).
  final String sha256;

  const UpdateAsset({required this.urls, this.size = 0, this.sha256 = ''});

  Map<String, dynamic> toJson() => {'urls': urls, 'size': size, 'sha256': sha256};

  factory UpdateAsset.fromJson(Map<String, dynamic> json) => UpdateAsset(
        urls: (json['urls'] as List? ?? const []).cast<String>(),
        size: (json['size'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
      );
}

/// إصدار منشور: رقمه وملاحظاته وملفات تثبيته.
class UpdateInfo {
  /// رقم الإصدار بصيغة semver مثل "1.0.1"
  final String version;
  final String releaseNotes;
  final DateTime publishedAt;
  final UpdateAsset? android;
  final UpdateAsset? windows;

  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.publishedAt,
    this.android,
    this.windows,
  });

  String? get downloadUrlAndroid => android == null || android!.urls.isEmpty ? null : android!.urls.first;
  String? get downloadUrlWindows => windows == null || windows!.urls.isEmpty ? null : windows!.urls.first;

  /// من استجابة GitHub Releases API (`releases/latest`).
  ///
  /// [cdnAndroidUrl] و[cdnWindowsUrl] روابط الموقع (أسرع وغير محجوبة) تُجرَّب
  /// أولاً؛ الحجم والبصمة من GitHub يكشفان إن كان الموقع ما زال يخدم إصداراً أقدم.
  factory UpdateInfo.fromJson(
    Map<String, dynamic> json, {
    String? cdnAndroidUrl,
    String? cdnWindowsUrl,
  }) {
    final assets = (json['assets'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

    UpdateAsset? pick(List<String> keywords, String? cdnUrl) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        final url = asset['browser_download_url'] as String?;
        if (url == null || !keywords.any((kw) => name.contains(kw))) continue;
        final digest = asset['digest'] as String? ?? '';
        return UpdateAsset(
          urls: [if (cdnUrl != null) cdnUrl, url],
          size: (asset['size'] as num?)?.toInt() ?? 0,
          sha256: digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : '',
        );
      }
      return null;
    }

    return UpdateInfo(
      version: cleanVersion(json['tag_name'] as String? ?? ''),
      releaseNotes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      android: pick(const ['android', '.apk'], cdnAndroidUrl),
      windows: pick(const ['windows', '.exe', '.msi'], cdnWindowsUrl),
    );
  }

  /// من `update.json` على الموقع: يُنشر مع ملفات التثبيت في النشرة نفسها، فلا
  /// يسبق أحدهما الآخر.
  factory UpdateInfo.fromManifest(Map<String, dynamic> json, Uri manifestUri) {
    UpdateAsset? asset(String key) {
      final a = json[key];
      if (a is! Map<String, dynamic>) return null;
      final path = a['path'] as String?;
      final mirror = a['mirror'] as String?;
      final urls = [
        if (path != null && path.isNotEmpty) manifestUri.resolve(path).toString(),
        if (mirror != null && mirror.isNotEmpty) mirror,
      ];
      if (urls.isEmpty) return null;
      return UpdateAsset(
        urls: urls,
        size: (a['size'] as num?)?.toInt() ?? 0,
        sha256: (a['sha256'] as String? ?? '').toLowerCase(),
      );
    }

    return UpdateInfo(
      version: cleanVersion(json['version'] as String? ?? ''),
      releaseNotes: json['notes'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ?? DateTime.now(),
      android: asset('android'),
      windows: asset('windows'),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'releaseNotes': releaseNotes,
        'publishedAt': publishedAt.toIso8601String(),
        if (android != null) 'android': android!.toJson(),
        if (windows != null) 'windows': windows!.toJson(),
      };

  factory UpdateInfo.fromStored(Map<String, dynamic> json) => UpdateInfo(
        version: json['version'] as String? ?? '',
        releaseNotes: json['releaseNotes'] as String? ?? '',
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ?? DateTime.now(),
        android: json['android'] is Map<String, dynamic>
            ? UpdateAsset.fromJson(json['android'] as Map<String, dynamic>)
            : null,
        windows: json['windows'] is Map<String, dynamic>
            ? UpdateAsset.fromJson(json['windows'] as Map<String, dynamic>)
            : null,
      );
}

/// ما يحتاجه محرك التنزيل عن أي ملف: من أين يُجلب، وكم حجمه، وما بصمته.
/// يشترك فيه ملف التحديث وملفات أصوات الأذان.
abstract class DownloadSpec {
  /// اسم الملف على الجهاز.
  String get fileName;

  /// روابط الملف نفسه، بترتيب التفضيل.
  List<String> get urls;

  /// بالبايت؛ 0 إن لم يُعرف.
  int get size;

  /// بصمة الملف الكامل (hex)؛ فارغة إن لم تُعرف.
  String get sha256;
}

/// مهمة تنزيل تحديث واحدة. تُحفظ في ملف (`job.json`) فيكملها التطبيق بعد إغلاقه
/// وإعادة فتحه، وتكملها مهمة الخلفية والتطبيق مغلق.
class UpdateJob implements DownloadSpec {
  final UpdateInfo info;

  /// 'android' أو 'windows'
  final String platform;

  const UpdateJob({required this.info, required this.platform});

  String get version => info.version;
  UpdateAsset get asset => (platform == 'windows' ? info.windows : info.android)!;
  @override
  List<String> get urls => asset.urls;
  @override
  int get size => asset.size;
  @override
  String get sha256 => asset.sha256;

  /// اسم الملف على الجهاز يحمل رقم الإصدار: جزء من إصدار لا يُستكمل بإصدار آخر.
  @override
  String get fileName => 'mihrab-$version.${platform == 'windows' ? 'exe' : 'apk'}';

  /// يتغيّر إن تغيّر ما يُنزَّل: من يعمل على مهمة قديمة يتوقف حين يراه اختلف.
  String get signature => '$platform|$version|$size|$sha256|${urls.join(',')}';

  static UpdateJob? forPlatform(UpdateInfo info, String platform) {
    final asset = platform == 'windows' ? info.windows : info.android;
    if (asset == null || asset.urls.isEmpty) return null;
    return UpdateJob(info: info, platform: platform);
  }

  String encode() => jsonEncode({'platform': platform, 'info': info.toJson()});

  static UpdateJob? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final info = UpdateInfo.fromStored(json['info'] as Map<String, dynamic>);
      if (info.version.isEmpty) return null;
      return forPlatform(info, json['platform'] as String? ?? 'android');
    } catch (_) {
      return null;
    }
  }
}

enum UpdatePhase {
  /// البايتات تصل.
  downloading,

  /// لا اتصال الآن؛ المحاولة مستمرة والجزء المنزَّل محفوظ.
  waiting,

  /// اكتمل الحجم ويُتحقق من البصمة.
  verifying,

  /// الملف كامل وسليم.
  ready,

  /// القرص ممتلئ؛ يُعاد المحاولة حين يتوفر مكان.
  noSpace,
}

/// نبضة حالة التنزيل: يكتبها من يملك التنزيل كل ثانية تقريباً، ويقرؤها غيره
/// ليعرض التقدم وليعرف أن المالك ما زال حياً.
class UpdateStatus {
  final String owner;
  final int atMs;
  final UpdatePhase phase;
  final int received;
  final int total;
  final String version;

  const UpdateStatus({
    required this.owner,
    required this.atMs,
    required this.phase,
    required this.received,
    required this.total,
    required this.version,
  });

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

  bool isFresh(DateTime now, Duration staleAfter) =>
      now.millisecondsSinceEpoch - atMs < staleAfter.inMilliseconds;

  String encode() => jsonEncode({
        'owner': owner,
        'at': atMs,
        'phase': phase.name,
        'received': received,
        'total': total,
        'version': version,
      });

  static UpdateStatus? decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UpdateStatus(
        owner: json['owner'] as String,
        atMs: (json['at'] as num).toInt(),
        phase: UpdatePhase.values.firstWhere(
          (p) => p.name == json['phase'],
          orElse: () => UpdatePhase.downloading,
        ),
        received: (json['received'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        version: json['version'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
