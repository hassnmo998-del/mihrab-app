import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/adhan_audio_cache_manager.dart';
import 'package:flutter_app/services/adhan_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adhan Audio Cache & Offline Tests', () {
    test('Default sound is always considered offline ready', () {
      final cacheManager = AdhanAudioCacheManager.instance;
      expect(
        cacheManager.isSoundDownloaded(AdhanAudioCacheManager.defaultSoundId),
        isTrue,
      );
    });

    test('AdhanData provides valid default sound and catalog items', () {
      final defaultSound = AdhanData.defaultSound;
      expect(defaultSound.id, equals(AdhanAudioCacheManager.defaultSoundId));
      expect(defaultSound.title.isNotEmpty, isTrue);
      expect(defaultSound.audioUrl.isNotEmpty, isTrue);

      final found = AdhanData.getById(defaultSound.id);
      expect(found.id, equals(defaultSound.id));

      final fallback = AdhanData.getById('non_existent_id');
      expect(fallback.id, equals(defaultSound.id));
    });

    test('getPlayableSource returns valid source for default sound', () {
      final cacheManager = AdhanAudioCacheManager.instance;
      final defaultSound = AdhanData.defaultSound;
      final source = cacheManager.getPlayableSource(defaultSound);
      expect(source, isNotNull);
    });
  });
}
