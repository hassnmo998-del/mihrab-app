import '../core/utils/wall_clock.dart';

/// لماذا لم تصل الأرقام.
enum InstallStatsError {
  /// كلمة السر خاطئة (أو تغيّرت على الخادم).
  wrongSecret,
  /// محاولات خاطئة كثيرة: الخادم يوقف الفحص دقائق.
  tooManyAttempts,
  /// لا إنترنت أو الخادم لم يردّ.
  unavailable,
}

class InstallStatsException implements Exception {
  final InstallStatsError error;
  const InstallStatsException(this.error);

  @override
  String toString() => 'InstallStatsException($error)';
}

/// عدد في فئة: منصة («android») أو رقم إصدار («1.0.14»).
class InstallCount {
  final String key;
  final int count;
  const InstallCount(this.key, this.count);
}

/// يوم في منحنى الأيام: كم جهازاً ظهر فيه، وكم جهازاً فُتح عليه التطبيق.
class InstallDay {
  final DateTime day;
  final int seen;
  final int opened;
  const InstallDay(this.day, this.seen, this.opened);
}

/// أرقام «الأجهزة التي عليها التطبيق» كما يعيدها الخادم (`app_install_stats`، بكلمة سر).
///
/// الأيام بتوقيت دمشق. «عليها التطبيق» = ظهرت خلال آخر 30 يوماً: جهاز حُذف منه
/// التطبيق لا يرسل شيئاً فيخرج من العدد بعد 30 يوماً من آخر ظهور.
class InstallStats {
  final DateTime today;
  /// أول جهاز عُدّ: ما قبله لا أرقام له. null إن لم يُعدّ أي جهاز بعد.
  final DateTime? countingSince;
  final int installed;
  final int total;
  final int openedToday;
  final int opened7d;
  final int new7d;
  final List<InstallCount> byPlatform;
  final List<InstallCount> byVersion;
  final List<InstallDay> daily;

  const InstallStats({
    required this.today,
    required this.countingSince,
    required this.installed,
    required this.total,
    required this.openedToday,
    required this.opened7d,
    required this.new7d,
    required this.byPlatform,
    required this.byVersion,
    required this.daily,
  });

  factory InstallStats.fromJson(Map<String, dynamic> json) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    List<InstallCount> counts(Object? raw) => [
          for (final e in (raw as List? ?? const []))
            if (e is Map) InstallCount('${e['key'] ?? ''}', n(e['count'])),
        ];
    final since = json['counting_since'];
    return InstallStats(
      today: parseWallClock(json['today']),
      // لحظة حقيقية (timestamptz) لا وقت جدار: تُعرض بتوقيت الجهاز
      countingSince: since is String ? DateTime.parse(since).toLocal() : null,
      installed: n(json['installed']),
      total: n(json['total']),
      openedToday: n(json['opened_today']),
      opened7d: n(json['opened_7d']),
      new7d: n(json['new_7d']),
      byPlatform: counts(json['by_platform']),
      byVersion: counts(json['by_version']),
      daily: [
        for (final e in (json['daily'] as List? ?? const []))
          if (e is Map) InstallDay(parseWallClock('${e['day']}'), n(e['seen']), n(e['opened'])),
      ],
    );
  }

  /// اسم المنصة كما يُعرض.
  static String platformLabel(String key) => switch (key) {
        'android' => 'أندرويد',
        'windows' => 'ويندوز',
        'ios' => 'آيفون',
        'web' => 'متصفح',
        'macos' => 'ماك',
        'linux' => 'لينكس',
        _ => key,
      };
}
