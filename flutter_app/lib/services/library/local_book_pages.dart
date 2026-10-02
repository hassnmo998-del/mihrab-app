import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../data/quran_data.dart';
import '../../models/library_book.dart';
import '../bukhari_sections.dart';
import '../hadith_service.dart';
import '../muslim_sections.dart';
import '../riyad_hadith_data.dart';

/// صفحات الكتب المضمّنة في التطبيق (تعمل بلا إنترنت): كتب الحديث التفاعلية
/// والتفسير الميسر. باقي الكتب سحابية وتمر عبر [BookContentRepository].
class LocalBookPages {
  LocalBookPages._();

  static const Set<String> bookIds = {
    'arbaeen_nawawi',
    'qudsi_hadiths',
    'riyad_salihin',
    'sahih_bukhari',
    'sahih_muslim',
    'tafsir_muyassar',
  };

  static Future<List<BookPage>> load(LibraryBook book) async {
    try {
      switch (book.id) {
        case 'arbaeen_nawawi':
          return await _nawawi();
        case 'qudsi_hadiths':
          return await _qudsi();
        case 'riyad_salihin':
          return _riyad();
        case 'sahih_bukhari':
          return await _sahih(
            asset: 'assets/data/bukhari_full.json',
            bookName: 'صحيح البخاري',
            sectionNames: BukhariSections.arabicNames,
          );
        case 'sahih_muslim':
          return await _sahih(
            asset: 'assets/data/muslim_full.json',
            bookName: 'صحيح مسلم',
            sectionNames: MuslimSections.arabicNames,
          );
        case 'tafsir_muyassar':
          return await _tafsirMuyassar();
      }
    } catch (e) {
      debugPrint('⚠️ Error building local pages for ${book.id}: $e');
    }
    return book.pages;
  }

  static Future<List<BookPage>> _nawawi() async {
    await HadithService.ensureLoaded();
    final hadiths = HadithService.getAllHadiths();
    return [
      for (int i = 0; i < hadiths.length; i++)
        BookPage(
          pageNumber: i + 1,
          title: 'الحديث رقم (${hadiths[i].number}): ${hadiths[i].title}',
          section: 'الأربعون النووية في مباني الإسلام',
          content: 'عن ${hadiths[i].narrator} رضي الله عنه قال: سمعت رسول الله ﷺ يقول:\n\n'
              '«${hadiths[i].matn}»\n\n'
              '📌 فوائد وهدايات الحديث الشريف:\n'
              '${hadiths[i].fawaid}',
          footnote: hadiths[i].source,
        ),
    ];
  }

  static Future<List<BookPage>> _qudsi() async {
    await HadithService.ensureQudsiLoaded();
    final hadiths = HadithService.getQudsiHadiths();
    return [
      for (int i = 0; i < hadiths.length; i++)
        BookPage(
          pageNumber: i + 1,
          title: hadiths[i].title,
          section: hadiths[i].chapter,
          content: 'عن ${hadiths[i].narrator}، عن رسول الله ﷺ فِيمَا رَوَى عَنِ اللَّهِ تَبَارَكَ وَتَعَالَى:\n\n'
              '«${hadiths[i].matn}»\n\n'
              '📌 الدروس الإيمانية:\n'
              '${hadiths[i].fawaid}',
          footnote: hadiths[i].source,
        ),
    ];
  }

  static List<BookPage> _riyad() {
    return [
      for (int i = 0; i < kRiyadHadiths.length; i++)
        BookPage(
          pageNumber: i + 1,
          title: '${kRiyadHadiths[i].title} (حديث ${kRiyadHadiths[i].number})',
          section: kRiyadHadiths[i].chapter,
          content: 'عن ${kRiyadHadiths[i].narrator} رضي الله عنه قال:\n\n'
              '«${kRiyadHadiths[i].matn}»\n\n'
              '📌 فقه الحديث والفوائد التربوية:\n'
              '${kRiyadHadiths[i].fawaid}',
          footnote: kRiyadHadiths[i].source,
        ),
    ];
  }

  /// البخاري ومسلم: أحاديث كل كتاب مجموعة 15 حديثاً في الصفحة.
  static Future<List<BookPage>> _sahih({
    required String asset,
    required String bookName,
    required Map<int, String> sectionNames,
  }) async {
    final data = jsonDecode(await rootBundle.loadString(asset, cache: false));
    final sections = <int, List<Map<String, dynamic>>>{};
    for (final item in data['hadiths'] as List) {
      if ((item['text'] as String? ?? '').trim().isEmpty) continue;
      final section = (item['reference']?['book'] as num?)?.toInt() ?? 0;
      sections.putIfAbsent(section, () => []).add(item as Map<String, dynamic>);
    }

    const chunkSize = 15;
    final pages = <BookPage>[];
    sections.forEach((sectionId, hadiths) {
      final name = sectionNames[sectionId] ?? 'كتاب رقم ($sectionId)';
      for (int i = 0; i < hadiths.length; i += chunkSize) {
        final chunk = hadiths.sublist(i, math.min(i + chunkSize, hadiths.length));
        final buffer = StringBuffer();
        for (final h in chunk) {
          buffer.writeln('【حديث رقم (${h['hadithnumber'] ?? ''})】');
          buffer.writeln('${(h['text'] as String? ?? '').trim()}\n');
        }
        final part = hadiths.length > chunkSize ? ' (جزء ${(i ~/ chunkSize) + 1})' : '';
        pages.add(BookPage(
          pageNumber: pages.length + 1,
          title: '$name$part',
          section: '$bookName — $name',
          content: buffer.toString().trim(),
          footnote: '$bookName — كتاب $name '
              '[أحاديث ${chunk.first['hadithnumber']} - ${chunk.last['hadithnumber']}]',
        ));
      }
    });
    return pages;
  }

  static Future<List<BookPage>> _tafsirMuyassar() async {
    final Map<String, dynamic> tafsir = jsonDecode(
      await rootBundle.loadString('assets/data/quran_tafsir_muyassar.json', cache: false),
    );

    const chunkSize = 25;
    final pages = <BookPage>[];
    for (final surah in quranSurahsInfo) {
      final ayahs = (tafsir[surah.number.toString()] as Map<String, dynamic>?)?.entries.toList();
      if (ayahs == null || ayahs.isEmpty) continue;

      for (int i = 0; i < ayahs.length; i += chunkSize) {
        final chunk = ayahs.sublist(i, math.min(i + chunkSize, ayahs.length));
        final range = ayahs.length > chunkSize ? ' (الآيات ${chunk.first.key} - ${chunk.last.key})' : '';
        pages.add(BookPage(
          pageNumber: pages.length + 1,
          title: 'سورة ${surah.name}$range',
          section: 'التفسير الميسر — جزء ${surah.startJuz}',
          content: chunk.map((e) => '﴿الآية ${e.key}﴾: ${e.value}').join('\n'),
        ));
      }
    }
    return pages;
  }
}
