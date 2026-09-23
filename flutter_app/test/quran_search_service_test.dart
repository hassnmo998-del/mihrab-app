import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/quran_search_service.dart';
import 'package:flutter_app/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  List<String> keys(String query) => QuranSearchService.search(query).map((r) => r.key).toList();

  group('Everyday spelling finds Uthmani text', () {
    test('الرحمن (dagger alef) → Al-Fatiha 3', () => expect(keys('الرحمن'), contains('1:3')));
    test('إياك نعبد → Al-Fatiha 5', () => expect(keys('إياك نعبد'), contains('1:5')));
    test('اياك نعبد without hamza → Al-Fatiha 5', () => expect(keys('اياك نعبد'), contains('1:5')));
    test('ذلك الكتاب → Al-Baqarah 2', () => expect(keys('ذلك الكتاب'), contains('2:2')));
    test('الصلاة (Uthmani الصلوٰة) → Al-Baqarah 3', () => expect(keys('الصلاة'), contains('2:3')));
    test('سماوات (Uthmani سمٰوٰت) → Al-Baqarah 29', () => expect(keys('سماوات'), contains('2:29')));
    test('يا أيها الناس (Uthmani يٰٓأيها) → Al-Baqarah 21', () => expect(keys('يا أيها الناس'), contains('2:21')));
    test('إبراهيم → Al-Baqarah 124', () => expect(keys('إبراهيم'), contains('2:124')));
    test('داود (Uthmani داوۥد, small waw not written) → Al-Baqarah 251', () => expect(keys('داود'), contains('2:251')));
    test('آمنوا (Uthmani ءامنوا) → Al-Baqarah 9', () => expect(keys('آمنوا'), contains('2:9')));
    test('على (Uthmani علىٰ) → Al-Baqarah 5', () => expect(keys('على هدى'), contains('2:5')));
    test('قل هو الله أحد → Al-Ikhlas 1', () => expect(keys('قل هو الله أحد'), contains('112:1')));
  });

  group('Search behaviour', () {
    test('results carry the right Mushaf page', () {
      final hit = QuranSearchService.search('قل هو الله أحد').firstWhere((r) => r.key == '112:1');
      expect(hit.pageNumber, 604);
    });

    test('results are capped and in Mushaf order', () {
      final results = QuranSearchService.search('الله');
      expect(results.length, QuranSearchService.maxResults);
      expect(results.first.surahNumber, 1);
    });

    test('a single letter or empty query returns nothing', () {
      expect(QuranSearchService.search(''), isEmpty);
      expect(QuranSearchService.search('ب'), isEmpty);
    });

    test('a query that is not in the Quran returns nothing', () {
      expect(QuranSearchService.search('تلفاز حاسوب'), isEmpty);
    });

    test('page numbers are recognised in Latin and Arabic digits', () {
      expect(QuranSearchService.pageNumberOf('42'), 42);
      expect(QuranSearchService.pageNumberOf('٤٢'), 42);
      expect(QuranSearchService.pageNumberOf('605'), isNull);
      expect(QuranSearchService.pageNumberOf('الله'), isNull);
    });
  });
}
