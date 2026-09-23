import 'quran_service.dart';

/// One search hit: an ayah and the Mushaf page it sits on.
class QuranSearchResult {
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final String surahName;
  final String text;

  const QuranSearchResult({
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    required this.surahName,
    required this.text,
  });

  String get key => '$surahNumber:$ayahNumber';
}

/// Word search over the Uthmani Mushaf text, forgiving of how people actually type.
///
/// The bundled text is Uthmani script, which spells many words differently from
/// everyday writing (ٱلصَّلَوٰةَ / الصلاة, ٱلسَّمَٰوَٰتِ / السماوات, يَٰٓأَيُّهَا / يا أيها).
/// Both the ayah and the query are reduced to the same consonant "skeleton"
/// ([skeleton]) and matched with `contains`.
///
/// Uthmani small letters (ۥ small waw, ۦ small yeh) are sometimes written in everyday
/// spelling (إبرٰهـۦم → إبراهيم) and sometimes not (داوۥد → داود), so each ayah is
/// indexed both ways and either may match.
class QuranSearchService {
  QuranSearchService._();

  static const int maxResults = 50;

  static List<(QuranSearchResult, String, String)>? _index;

  static final RegExp _smallWaw = RegExp('\u06E5');
  static final RegExp _smallYeh = RegExp('[\u06E6\u06E7]');

  // Uthmani silent waw carrying a dagger alef is read as alef (الصلوٰة → الصلاة).
  static final RegExp _wawDaggerAlef = RegExp('\u0648\u0670');
  static final RegExp _alefForms = RegExp('[\u0671\u0622\u0623\u0625\u0672\u0673\u0670]');
  // Harakat, Quranic annotation marks, small high letters, tatweel, BOM.
  static final RegExp _marks = RegExp('[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED\u08D3-\u08FF\u0640\uFEFF]');
  // After unifying, alef and standalone hamza are dropped: their spelling varies most
  // between Uthmani and everyday writing. Spaces too, so يٰأيها matches يا أيها.
  static final RegExp _dropped = RegExp('[\u0627\u0621\\s]');
  static final RegExp _nonArabicLetters = RegExp('[^\u0621-\u064A]');

  /// Reduces Arabic text to a spelling-agnostic skeleton for matching.
  /// With [expandSmallLetters], Uthmani small waw/yeh become full letters instead of
  /// being dropped.
  static String skeleton(String input, {bool expandSmallLetters = false}) {
    var text = input;
    if (expandSmallLetters) {
      text = text.replaceAll(_smallWaw, '\u0648').replaceAll(_smallYeh, '\u064A');
    }
    return text
        .replaceAll(_wawDaggerAlef, '\u0627')
        .replaceAll(_alefForms, '\u0627')
        .replaceAll(_marks, '')
        .replaceAll('\u0649', '\u064A') // ى → ي
        .replaceAll('\u0629', '\u0647') // ة → ه
        .replaceAll('\u0624', '\u0648') // ؤ → و
        .replaceAll('\u0626', '\u064A') // ئ → ي
        .replaceAll(_dropped, '')
        .replaceAll(_nonArabicLetters, '');
  }

  /// Page number typed in Latin or Arabic-Indic digits (1-604), or null.
  static int? pageNumberOf(String query) {
    final latin = query.trim().replaceAllMapped(
          RegExp('[\u0660-\u0669]'),
          (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
        );
    final n = int.tryParse(latin);
    return (n != null && n >= 1 && n <= QuranService.totalPages) ? n : null;
  }

  static List<(QuranSearchResult, String, String)> _buildIndex() {
    final entries = <(QuranSearchResult, String, String)>[];
    for (var s = 1; s <= 114; s++) {
      final verses = QuranService.getUthmaniVerses(s);
      final name = QuranService.getSurahName(s);
      for (var i = 0; i < verses.length; i++) {
        final ayah = i + 1;
        entries.add((
          QuranSearchResult(
            surahNumber: s,
            ayahNumber: ayah,
            pageNumber: QuranService.getPageForAyah(s, ayah) ?? 1,
            surahName: name,
            text: verses[i],
          ),
          skeleton(verses[i]),
          skeleton(verses[i], expandSmallLetters: true),
        ));
      }
    }
    return entries;
  }

  /// Builds the index ahead of the first search (a one-off pass over 6236 ayahs).
  static void warmUp() => _index ??= _buildIndex();

  /// Ayahs containing [query], in Mushaf order, at most [maxResults].
  static List<QuranSearchResult> search(String query) {
    final needle = skeleton(query);
    if (needle.length < 2) return const [];
    final index = _index ??= _buildIndex();
    final results = <QuranSearchResult>[];
    for (final (result, text, expanded) in index) {
      if (text.contains(needle) || expanded.contains(needle)) {
        results.add(result);
        if (results.length >= maxResults) break;
      }
    }
    return results;
  }
}
