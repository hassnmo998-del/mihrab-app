/// Model representing an Adhan sound item for playback and selection.
class AdhanSound {
  final String id;
  final String title;
  final String category;
  final String muezzinOrLocation;
  final String audioUrl;
  final int durationSeconds;

  const AdhanSound({
    required this.id,
    required this.title,
    required this.category,
    required this.muezzinOrLocation,
    required this.audioUrl,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'muezzinOrLocation': muezzinOrLocation,
        'audioUrl': audioUrl,
        'durationSeconds': durationSeconds,
      };

  factory AdhanSound.fromJson(Map<String, dynamic> json) => AdhanSound(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        muezzinOrLocation: json['muezzinOrLocation'] as String,
        audioUrl: json['audioUrl'] as String,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 180,
      );
}
