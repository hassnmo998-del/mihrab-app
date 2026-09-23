import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/quran_service.dart';
import 'package:flutter_app/services/hadith_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // مع false يرمي google_fonts استثناءً مؤجَّلاً لأن ملف أميري غير مضمَّن في
  // الأصول؛ مع true يكتفي بتحذير (بيئة الاختبار لا تُجري أي طلب شبكي فعلي).
  GoogleFonts.config.allowRuntimeFetching = true;

  group('Quran Service & Madinah Mushaf (604 pages)', () {
    test('QuranPage model is correctly constructed', () {
      final page = QuranPage(
        pageNumber: 1,
        juzNumber: 1,
        hizbQuarter: 1,
        surahNumbers: const [1],
        surahNames: const ['الفاتحة'],
        ayahs: const [
          QuranAyah(
            globalNumber: 1,
            surahNumber: 1,
            surahName: 'الفاتحة',
            ayahNumberInSurah: 1,
            pageNumber: 1,
            juzNumber: 1,
            hizbQuarter: 1,
            uthmaniText: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
            tajweedText: 'بِسْمِ [h:1[ٱ]للَّهِ [h:2[ٱ][l[ل]رَّحْمَ[n[ـٰ]نِ [h:3[ٱ][l[ل]رَّح[p[ِي]مِ',
          ),
        ],
      );

      expect(page.pageNumber, 1);
      expect(page.juzNumber, 1);
      expect(page.surahNames, ['الفاتحة']);
      expect(page.ayahs.length, 1);
      expect(page.hasSurahStart(1), true);
    });

    test('parseTajweedSegments cleans markers and injects ZWJ ligatures', () {
      // منطق نصي خالص: لا يحتاج تحميل خط فلا يعتمد الاختبار على الشبكة
      const verse =
          'بِسْمِ [h:1[ٱ]للَّهِ [h:2[ٱ][l[ل]رَّحْمَ[n[ـٰ]نِ [h:3[ٱ][l[ل]رَّح[p[ِي]مِ';

      final segments = QuranService.parseTajweedSegments(verse);
      expect(segments.isNotEmpty, true);

      final combined = segments.map((s) => s['text'] as String).join();
      // ZWJ يُحقن فعلاً بين المقاطع المتصلة
      expect(combined.contains('‍'), true);

      // بعد إزالة ZWJ يجب أن يتبقى النص نفسه بلا علامات التجويد
      final cleaned = combined.replaceAll('‍', '');
      final expected = verse
          .replaceAll(RegExp(r'\[[a-z](?::\d+)?\['), '')
          .replaceAll(']', '');
      expect(cleaned, expected);

      // كل مقطع يحمل مفتاح قاعدته (أو null للنص العادي)
      expect(segments.every((s) => s.containsKey('rule')), true);
    });
  });

  group('Hadith Service & Riyad as-Salihin Expansion', () {
    test('getRiyadHadiths returns curated educational hadiths', () {
      final riyadList = HadithService.getRiyadHadiths();
      expect(riyadList.isNotEmpty, true);
      expect(riyadList.length >= 20, true);

      final h1 = riyadList.first;
      expect(h1.book, 'riyad');
      expect(h1.chapter.startsWith('باب'), true);
      expect(h1.matn.isNotEmpty, true);
      expect(h1.fawaid.isNotEmpty, true);

      // حديث طلب العلم موجود في المجموعة (بلا اعتماد على ترتيب الأبواب)
      expect(
        riyadList.any((h) => h.matn.contains('سَلَكَ طَرِيقًا')),
        true,
      );
      // كل الأحاديث تحمل باباً وفوائد تربوية
      expect(riyadList.every((h) => h.book == 'riyad'), true);
      expect(riyadList.every((h) => h.chapter.trim().isNotEmpty), true);
      expect(riyadList.every((h) => h.fawaid.isNotEmpty), true);
    });

    test('getRiyadChapters returns unique moral & pedagogical chapters', () {
      final chapters = HadithService.getRiyadChapters();
      expect(chapters.isNotEmpty, true);
      // الأبواب فريدة ومسمّاة بصيغة "باب ..."
      expect(chapters.toSet().length, chapters.length);
      expect(chapters.every((c) => c.startsWith('باب')), true);

      // تغطية المحاور التربوية الأساسية (بلا تثبيت صياغة العنوان)
      for (final topic in ['العلم', 'الأخلاق', 'الوالدين', 'الأمانة']) {
        expect(
          chapters.any((c) => c.contains(topic)),
          true,
          reason: 'لا يوجد باب يغطي محور: $topic',
        );
      }
    });

    test('getHadithsByBook filters correctly', () {
      final riyad = HadithService.getHadithsByBook('riyad');
      expect(riyad.every((h) => h.book == 'riyad'), true);
    });
  });

  group('Mosque Electronic Donations & Data Integrity', () {
    test('Mosque donation active status computation', () {
      final mosqueEnabledWithAccount = Mosque(
        id: 'm1',
        name: 'مسجد الهدى',
        city: 'دمشق',
        gender: 'male',
        accessCode: 'MSQ-001',
        isDonationEnabled: true,
        donationAccountNumber: '123456789',
      );
      expect(mosqueEnabledWithAccount.hasActiveDonation, true);

      final mosqueDisabled = Mosque(
        id: 'm2',
        name: 'مسجد النور',
        city: 'دمشق',
        gender: 'male',
        accessCode: 'MSQ-002',
        isDonationEnabled: false,
        donationAccountNumber: '123456789',
      );
      expect(mosqueDisabled.hasActiveDonation, false);

      final mosqueNoAccountNoImage = Mosque(
        id: 'm3',
        name: 'مسجد الفردوس',
        city: 'دمشق',
        gender: 'male',
        accessCode: 'MSQ-003',
        isDonationEnabled: true,
        donationAccountNumber: '',
        donationImageUrl: null,
      );
      expect(mosqueNoAccountNoImage.hasActiveDonation, false);
    });

    test('Mosque JSON serialization preserves donation fields', () {
      final original = Mosque(
        id: 'm-test',
        name: 'مسجد الاختبار',
        city: 'ريف دمشق',
        gender: 'male',
        accessCode: 'MSQ-TEST',
        isDonationEnabled: true,
        donationAccountName: 'صندوق المسجد',
        donationAccountNumber: '987654321',
        donationDescription: 'ترميم وتوسعة',
        donationImageUrl: 'https://example.com/qr.png',
      );

      final json = original.toJson();
      expect(json['is_donation_enabled'], true);
      expect(json['donation_account_name'], 'صندوق المسجد');
      expect(json['donation_account_number'], '987654321');
      expect(json['donation_description'], 'ترميم وتوسعة');
      expect(json['donation_image_url'], 'https://example.com/qr.png');

      final deserialized = Mosque.fromJson(json);
      expect(deserialized.isDonationEnabled, true);
      expect(deserialized.donationAccountName, 'صندوق المسجد');
      expect(deserialized.donationAccountNumber, '987654321');
      expect(deserialized.donationDescription, 'ترميم وتوسعة');
      expect(deserialized.donationImageUrl, 'https://example.com/qr.png');
    });
  });

  group('Discover Polish: Bookmark Resume & Uniform Font Assurance', () {
    test('Bookmark page validity range check (1 to 604)', () {
      bool isDirectResumeValid(int? page) => page != null && page >= 1 && page <= 604;

      expect(isDirectResumeValid(1), true);
      expect(isDirectResumeValid(604), true);
      expect(isDirectResumeValid(300), true);
      expect(isDirectResumeValid(null), false);
      expect(isDirectResumeValid(0), false);
      expect(isDirectResumeValid(605), false);
    });

    test('Tajweed spans maintain Amiri font family across dark and light modes', () {
      final spansLight = QuranService.buildTajweedSpans(
        'بِسْمِ [h:1[ٱ]للَّهِ',
        fontSize: 20.0,
        isDark: false,
      );
      final spansDark = QuranService.buildTajweedSpans(
        'بِسْمِ [h:1[ٱ]للَّهِ',
        fontSize: 20.0,
        isDark: true,
      );

      expect(spansLight.isNotEmpty, true);
      expect(spansDark.isNotEmpty, true);
      // google_fonts يسمّي العائلة بلاحقة الوزن ('Amiri_regular')، فالمطلوب أن
      // تكون العائلة أميري لا أن تطابق الاسم حرفياً.
      for (final s in [...spansLight, ...spansDark]) {
        expect(s.style?.fontFamily, isNotNull);
        expect(s.style!.fontFamily!.startsWith('Amiri'), true);
      }
    });
  });
}
