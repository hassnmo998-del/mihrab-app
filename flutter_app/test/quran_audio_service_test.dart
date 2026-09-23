import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/quran_reciter.dart';
import 'package:flutter_app/services/quran_service.dart';
import 'package:flutter_app/services/quran_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuranReciter — URL Building & Catalogue Integrity', () {
    test('getAyahAudioUrl builds correct EveryAyah CDN URL for Al-Husary', () {
      final reciter = QuranReciter.defaultReciters[0]; // Al-Husary murattal
      final url = reciter.getAyahAudioUrl(1, 1);
      expect(url, 'https://everyayah.com/data/Husary_128kbps/001001.mp3');
    });

    test('getAyahAudioUrl pads surah and ayah numbers to 3 digits', () {
      final reciter = QuranReciter.defaultReciters[6]; // Alafasy
      final url = reciter.getAyahAudioUrl(2, 255); // Ayat Al-Kursi
      expect(url, 'https://everyayah.com/data/Alafasy_128kbps/002255.mp3');
    });

    test('getAyahAudioUrl for last Surah (114) and last Ayah (6)', () {
      final reciter = QuranReciter.defaultReciters[7]; // Maher Al-Muaiqly
      final url = reciter.getAyahAudioUrl(114, 6);
      expect(url, 'https://everyayah.com/data/MaherAlMuaiqly128kbps/114006.mp3');
    });

    test('Muallim reciter has dedicated educational subfolder', () {
      final muallim = QuranReciter.defaultReciters[1];
      expect(muallim.id, contains('muallim'));
      expect(muallim.style, contains('معلم'));
      expect(muallim.subfolder, contains('Muallim'));
    });

    test('All 15 reciters have unique IDs', () {
      final ids = QuranReciter.defaultReciters.map((r) => r.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, 15);
      expect(uniqueIds.length, 15,
          reason: 'All 15 reciters must have unique IDs');
    });

    test('All 15 reciters have non-empty Arabic names and subfolders', () {
      for (final reciter in QuranReciter.defaultReciters) {
        expect(reciter.nameArabic.isNotEmpty, isTrue,
            reason: '${reciter.id} must have an Arabic name');
        expect(reciter.subfolder.isNotEmpty, isTrue,
            reason: '${reciter.id} must have a non-empty subfolder');
        expect(reciter.riwayah.isNotEmpty, isTrue,
            reason: '${reciter.id} must have a riwayah');
      }
    });

    test('Mujawwad reciters are identified by style field', () {
      final mujawwadReciters = QuranReciter.defaultReciters
          .where((r) => r.style == 'مجوّد')
          .toList();
      expect(mujawwadReciters.length, greaterThanOrEqualTo(2),
          reason: 'At least Al-Minshawi and Abdul Basit must have mujawwad styles');
    });
  });

  group('QuranAudioService — Notifiers & State Management', () {
    setUp(() {
      // Reset service state for each test
      QuranAudioService.instance.stop();
    });

    test('Default reciter is Al-Husary murattal (index 0)', () {
      expect(QuranAudioService.instance.reciterNotifier.value.id,
          'husary_128kbps');
    });

    test('Default repeat scope is page', () {
      expect(QuranAudioService.instance.scopeNotifier.value,
          QuranRepeatScope.page);
    });

    test('Default speed is 1.0x', () {
      expect(QuranAudioService.instance.speedNotifier.value, 1.0);
    });

    test('Default repeat count is 1 (once)', () {
      expect(QuranAudioService.instance.repeatCountNotifier.value, 1);
    });

    test('setScope updates scopeNotifier correctly', () async {
      await QuranAudioService.instance.setScope(QuranRepeatScope.juz);
      expect(QuranAudioService.instance.scopeNotifier.value,
          QuranRepeatScope.juz);

      await QuranAudioService.instance.setScope(QuranRepeatScope.ayah);
      expect(QuranAudioService.instance.scopeNotifier.value,
          QuranRepeatScope.ayah);

      // Reset
      await QuranAudioService.instance.setScope(QuranRepeatScope.page);
    });

    test('setRepeatCount updates repeatCountNotifier', () {
      QuranAudioService.instance.setRepeatCount(5);
      expect(QuranAudioService.instance.repeatCountNotifier.value, 5);
      QuranAudioService.instance.setRepeatCount(-1);
      expect(QuranAudioService.instance.repeatCountNotifier.value, -1);
      // Reset
      QuranAudioService.instance.setRepeatCount(1);
    });

    test('setReciter updates reciterNotifier correctly', () async {
      final newReciter = QuranReciter.defaultReciters[6]; // Alafasy
      await QuranAudioService.instance.setReciter(newReciter);
      expect(QuranAudioService.instance.reciterNotifier.value.id,
          'alafasy_128kbps');

      // Reset back to default
      await QuranAudioService.instance.setReciter(
          QuranReciter.defaultReciters[0]);
    });

    test('cycleSpeed steps through speeds and wraps around', () async {
      final service = QuranAudioService.instance;
      await service.setSpeed(1.0);
      await service.cycleSpeed();
      expect(service.speedNotifier.value, 1.25);
      await service.cycleSpeed();
      expect(service.speedNotifier.value, 1.5);
      await service.cycleSpeed();
      expect(service.speedNotifier.value, 0.75);
      await service.cycleSpeed();
      expect(service.speedNotifier.value, 1.0);
    });

    test('stop() clears activeAyahNotifier, activePageNotifier, and activeTagNotifier', () async {
      await QuranAudioService.instance.stop();
      expect(QuranAudioService.instance.activeAyahNotifier.value, isNull);
      expect(QuranAudioService.instance.activePageNotifier.value, isNull);
      expect(QuranAudioService.instance.activeTagNotifier.value, isNull);
    });
  });

  group('QuranAudioService — URL Generation via QuranReciter Integration', () {
    setUpAll(() async {
      // Load Quran data for page-for-ayah lookups
      await QuranService.ensureLoaded();
    });

    test('QuranService.getPageForAyah returns correct page for Surah Al-Baqarah Ayah 255 (Ayat Al-Kursi)', () {
      final page = QuranService.getPageForAyah(2, 255);
      expect(page, isNotNull);
      expect(page, equals(42)); // Ayat Al-Kursi is on page 42
    });

    test('QuranService.getPageForAyah returns correct page for Surah Al-Fatiha Ayah 1', () {
      final page = QuranService.getPageForAyah(1, 1);
      expect(page, isNotNull);
      expect(page, equals(1));
    });

    test('QuranService.getPageForAyah returns correct page for last Surah Ayah 1 (An-Nas)', () {
      final page = QuranService.getPageForAyah(114, 1);
      expect(page, isNotNull);
      expect(page, equals(604));
    });

    test('Ayah audio URL generated correctly for Ayat Al-Kursi via default reciter', () {
      final reciter = QuranAudioService.instance.reciterNotifier.value;
      final url = reciter.getAyahAudioUrl(2, 255);
      expect(url, 'https://everyayah.com/data/Husary_128kbps/002255.mp3');
      expect(url, contains('everyayah.com/data/'));
      expect(url, endsWith('.mp3'));
    });

    test('Page playlist would contain 7 items for Al-Fatiha page (page 1)', () {
      final page = QuranService.getPage(1);
      expect(page, isNotNull);
      // Page 1 has Al-Fatiha (7 ayahs)
      expect(page!.ayahs.length, equals(7));
    });
  });

  group('QuranAyahAudioTag', () {
    test('key generates correct surah:ayah string', () {
      const tag = QuranAyahAudioTag(
        surahNumber: 36,
        ayahNumber: 1,
        surahName: 'يس',
        pageNumber: 440,
      );
      expect(tag.key, '36:1');
    });

    test('key for Al-Fatiha Ayah 1 is "1:1"', () {
      const tag = QuranAyahAudioTag(
        surahNumber: 1,
        ayahNumber: 1,
        surahName: 'الفاتحة',
        pageNumber: 1,
      );
      expect(tag.key, '1:1');
    });
  });
}
