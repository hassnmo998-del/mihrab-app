/// Model representing an Adhan sound item for playback and selection.
///
/// لكل مؤذن ملف «الأذان العادي» ([audioUrl])، بلا «الصلاة خير من النوم». التسجيلات
/// التي تحمل هذه الجملة لها ملف ثانٍ ([fajrUrl]) يُؤذَّن به للفجر وحده.
class AdhanSound {
  final String id;
  final String title;
  final String category;
  final String muezzinOrLocation;
  final String audioUrl;

  /// حجم الملف وبصمته: يُتحقق منهما قبل اعتماد ما نُزّل.
  final int audioBytes;
  final String audioSha256;

  final String? fajrUrl;
  final int fajrBytes;
  final String fajrSha256;

  final int durationSeconds;

  const AdhanSound({
    required this.id,
    required this.title,
    required this.category,
    required this.muezzinOrLocation,
    required this.audioUrl,
    this.audioBytes = 0,
    this.audioSha256 = '',
    this.fajrUrl,
    this.fajrBytes = 0,
    this.fajrSha256 = '',
    required this.durationSeconds,
  });

  bool get hasFajrVariant => fajrUrl != null && fajrUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'muezzinOrLocation': muezzinOrLocation,
        'audioUrl': audioUrl,
        'audioBytes': audioBytes,
        'audioSha256': audioSha256,
        if (hasFajrVariant) ...{
          'fajrUrl': fajrUrl,
          'fajrBytes': fajrBytes,
          'fajrSha256': fajrSha256,
        },
        'durationSeconds': durationSeconds,
      };

  factory AdhanSound.fromJson(Map<String, dynamic> json) => AdhanSound(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        muezzinOrLocation: json['muezzinOrLocation'] as String,
        audioUrl: json['audioUrl'] as String,
        audioBytes: (json['audioBytes'] as num?)?.toInt() ?? 0,
        audioSha256: json['audioSha256'] as String? ?? '',
        fajrUrl: json['fajrUrl'] as String?,
        fajrBytes: (json['fajrBytes'] as num?)?.toInt() ?? 0,
        fajrSha256: json['fajrSha256'] as String? ?? '',
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 180,
      );
}
