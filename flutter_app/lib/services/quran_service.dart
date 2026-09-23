import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Representation of a single authentic Quranic Ayah with Uthmani & Tajweed markup.
class QuranAyah {
  final int globalNumber;
  final int surahNumber;
  final String surahName;
  final int ayahNumberInSurah;
  final int pageNumber;
  final int juzNumber;
  final int hizbQuarter;
  final String uthmaniText;
  final String tajweedText;

  const QuranAyah({
    required this.globalNumber,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumberInSurah,
    required this.pageNumber,
    required this.juzNumber,
    required this.hizbQuarter,
    required this.uthmaniText,
    required this.tajweedText,
  });
}

/// Representation of a standard Madinah Mushaf Page (1 to 604).
class QuranPage {
  final int pageNumber;
  final int juzNumber;
  final int hizbQuarter;
  final List<QuranAyah> ayahs;
  final List<int> surahNumbers;
  final List<String> surahNames;

  const QuranPage({
    required this.pageNumber,
    required this.juzNumber,
    required this.hizbQuarter,
    required this.ayahs,
    required this.surahNumbers,
    required this.surahNames,
  });

  /// Check if a Surah starts on this page with Ayah 1
  bool hasSurahStart(int surahNum) =>
      ayahs.any((a) => a.surahNumber == surahNum && a.ayahNumberInSurah == 1);
}

/// High-performance Quran Service providing 100% authentic Uthmani Quranic text,
/// page-by-page Madinah Mushaf layout (604 pages), and official Tajweed markup
/// with seamless Arabic letter cursive ligatures.
class QuranService {
  QuranService._();

  static Map<int, List<String>>? _uthmaniSurahs;
  static Map<int, List<String>>? _tajweedSurahs;
  static Map<int, QuranPage>? _quranPages;
  static Map<int, int>? _surahStartPages;
  static Map<int, String>? _surahNames;
  static Map<String, int>? _ayahPages;
  static bool _isLoading = false;

  static bool get isLoaded =>
      _uthmaniSurahs != null && _tajweedSurahs != null && _quranPages != null;

  @visibleForTesting
  static void setMockLoadedForTesting() {
    _uthmaniSurahs = {};
    _tajweedSurahs = {};
    _quranPages = {};
    _surahStartPages = {for (var i = 1; i <= 114; i++) i: 1};
    _surahStartPages?[51] = 520;
    _surahNames = {51: 'الذاريات'};
    _ayahPages = {for (var s = 1; s <= 114; s++) '$s:1': 1};
    _isLoading = false;
  }

  static int get totalPages => 604;

  /// Returns the page number (1-604) for a given Surah and Ayah number.
  static int? getPageForAyah(int surahNumber, int ayahNumber) {
    return _ayahPages?['$surahNumber:$ayahNumber'];
  }

  /// Loads and parses both Uthmani and Tajweed Quran datasets asynchronously.
  static Future<void> ensureLoaded() async {
    if (isLoaded) return;
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return;
    }

    _isLoading = true;
    try {
      // 1. Load Uthmani text
      final uthmaniString = await rootBundle.loadString('assets/data/quran_uthmani.json');
      final uthmaniData = jsonDecode(uthmaniString);
      final uthmaniList = uthmaniData['data']['surahs'] as List;

      // 2. Load Tajweed text
      final tajweedString = await rootBundle.loadString('assets/data/quran_tajweed.json');
      final tajweedData = jsonDecode(tajweedString);
      final tajweedList = tajweedData['data']['surahs'] as List;

      final uMap = <int, List<String>>{};
      final tMap = <int, List<String>>{};
      final pageAyahsMap = <int, List<QuranAyah>>{};
      final surahStarts = <int, int>{};
      final surahNameMap = <int, String>{};
      final ayahPagesMap = <String, int>{};

      final basmalahPattern = RegExp(r'^﻿?ب[\u0651\u0650]*سْمِ\s*ٱللَّهِ\s*ٱلرَّحْمَٰنِ\s*ٱلرَّحِيمِ\s*');

      for (int sIdx = 0; sIdx < uthmaniList.length; sIdx++) {
        final sUth = uthmaniList[sIdx];
        final sTaj = sIdx < tajweedList.length ? tajweedList[sIdx] : null;

        final surahNumber = sUth['number'] as int;
        final rawSurahName = (sUth['name'] as String).replaceAll('سُورَةُ ', '').trim();
        surahNameMap[surahNumber] = rawSurahName;

        final ayahsUth = sUth['ayahs'] as List;
        final ayahsTaj = sTaj != null ? (sTaj['ayahs'] as List) : null;

        final uVerses = <String>[];
        final tVerses = <String>[];

        for (int aIdx = 0; aIdx < ayahsUth.length; aIdx++) {
          final aU = ayahsUth[aIdx];
          final aT = ayahsTaj != null && aIdx < ayahsTaj.length ? ayahsTaj[aIdx] : null;

          var uthText = (aU['text'] as String).trim();
          var tajText = aT != null ? (aT['text'] as String).trim() : uthText;

          final ayahNum = aU['numberInSurah'] as int;
          final pageNum = (aU['page'] as int?) ?? 1;
          final juzNum = (aU['juz'] as int?) ?? 1;
          final hizbQuarter = (aU['hizbQuarter'] as int?) ?? 1;
          final globalNum = (aU['number'] as int?) ?? 1;

          // Record first page of Surah
          if (ayahNum == 1) {
            surahStarts[surahNumber] = pageNum;
          }

          // Clean leading Basmalah for Surah reading lists (2..114 except 9)
          var cleanUthText = uthText;
          if (surahNumber > 1 && surahNumber != 9 && ayahNum == 1) {
            cleanUthText = cleanUthText.replaceFirst(basmalahPattern, '').trim();
          }

          uVerses.add(cleanUthText);
          tVerses.add(tajText);

          final ayahItem = QuranAyah(
            globalNumber: globalNum,
            surahNumber: surahNumber,
            surahName: rawSurahName,
            ayahNumberInSurah: ayahNum,
            pageNumber: pageNum,
            juzNumber: juzNum,
            hizbQuarter: hizbQuarter,
            uthmaniText: cleanUthText,
            tajweedText: tajText,
          );

          pageAyahsMap.putIfAbsent(pageNum, () => []).add(ayahItem);
          ayahPagesMap['$surahNumber:$ayahNum'] = pageNum;
        }

        uMap[surahNumber] = uVerses;
        tMap[surahNumber] = tVerses;
      }

      _uthmaniSurahs = uMap;
      _tajweedSurahs = tMap;
      _surahStartPages = surahStarts;
      _surahNames = surahNameMap;
      _ayahPages = ayahPagesMap;

      // Build pages 1..604
      final pagesMap = <int, QuranPage>{};
      for (int p = 1; p <= 604; p++) {
        final ayahs = pageAyahsMap[p] ?? const [];
        final juz = ayahs.isNotEmpty ? ayahs.first.juzNumber : 1;
        final hizb = ayahs.isNotEmpty ? ayahs.first.hizbQuarter : 1;
        final sNums = ayahs.map((a) => a.surahNumber).toSet().toList();
        final sNames = ayahs.map((a) => a.surahName).toSet().toList();

        pagesMap[p] = QuranPage(
          pageNumber: p,
          juzNumber: juz,
          hizbQuarter: hizb,
          ayahs: ayahs,
          surahNumbers: sNums,
          surahNames: sNames,
        );
      }
      _quranPages = pagesMap;
    } finally {
      _isLoading = false;
    }
  }

  /// Returns authentic Uthmani Ayahs for the given Surah number (1-114).
  static List<String> getUthmaniVerses(int surahNumber) {
    return _uthmaniSurahs?[surahNumber] ?? const [];
  }

  /// Returns authentic Tajweed-tagged Ayahs for the given Surah number (1-114).
  static List<String> getTajweedVerses(int surahNumber) {
    return _tajweedSurahs?[surahNumber] ?? const [];
  }

  /// Returns the complete page data for a Madinah Mushaf page (1-604).
  static QuranPage? getPage(int pageNumber) {
    return _quranPages?[pageNumber];
  }

  /// Returns the start page for a given Surah number.
  static int getSurahStartPage(int surahNumber) {
    return _surahStartPages?[surahNumber] ?? 1;
  }

  /// Returns the Surah name for a given Surah number.
  static String getSurahName(int surahNumber) {
    return _surahNames?[surahNumber] ?? '';
  }

  /// Converts an integer to authentic Eastern Arabic numerals (١، ٢، ٣...).
  static String toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((char) {
      final digit = int.tryParse(char);
      return digit != null ? arabicDigits[digit] : char;
    }).join();
  }

  /// Formats an Ayah number wrapped in authentic inward-curving ornate Quranic brackets ﴿١﴾.
  static String formatAyahBracket(int ayahNumber) {
    return '\uFD3F${toArabicDigits(ayahNumber)}\uFD3E';
  }

  // =========================================================================
  // Tajweed Cursive Shaping Engine (Prevents Arabic Letter Separation)
  // =========================================================================

  static const Set<int> _nonForwardConnecting = {
    0x0627, // ا
    0x0623, // أ
    0x0625, // إ
    0x0622, // آ
    0x0671, // ٱ
    0x062F, // د
    0x0630, // ذ
    0x0631, // ر
    0x0632, // ز
    0x0648, // و
    0x0624, // ؤ
    0x0629, // ة
    0x0649, // ى
  };

  static bool _isArabicDiacritic(int code) {
    return (code >= 0x064B && code <= 0x065F) ||
        (code == 0x0670) ||
        (code >= 0x06D6 && code <= 0x06ED);
  }

  static bool _connectsForward(String text) {
    for (int i = text.length - 1; i >= 0; i--) {
      final code = text.codeUnitAt(i);
      if (_isArabicDiacritic(code)) continue;
      if (code == 0x200D) return true; // Already joined
      if (code == 0x0640) return true; // Tatweel
      if (code >= 0x0621 && code <= 0x064A) {
        return !_nonForwardConnecting.contains(code);
      }
      return false;
    }
    return false;
  }

  static bool _connectsBackward(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (_isArabicDiacritic(code)) continue;
      if (code == 0x200D) return true; // Already joined
      if (code == 0x0640) return true; // Tatweel
      if (code >= 0x0621 && code <= 0x064A) {
        return code != 0x0621; // Hamza on line doesn't connect
      }
      return false;
    }
    return false;
  }

  static Color _getRuleColor(String? rule, bool isDark) {
    if (rule == null) {
      return isDark ? const Color(0xFFFAF5F0) : const Color(0xFF1E293B);
    }
    switch (rule) {
      case 'm': // مد لازم 6 حركات
        return AppColors.tajweedMadd;
      case 'o': // مد متصل أو منفصل (4-5 حركات)
        return const Color(0xFFE11D48);
      case 'p': // مد عارض للسكون (2-6 حركات)
        return AppColors.tajweedMaddPermissible;
      case 'n': // مد طبيعي
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      case 'q': // قلقلة
        return AppColors.tajweedQalqalah;
      case 'g': // غنة مشددة
        return AppColors.tajweedGhunnah;
      case 'c':
      case 'f': // إخفاء
        return AppColors.tajweedIkhfa;
      case 'w':
      case 'a':
      case 'd':
      case 'b': // إدغام
        return const Color(0xFF16A34A);
      case 'i': // إقلاب
        return AppColors.tajweedIqlab;
      case 'u': // إدغام بلا غنة
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      case 'h': // همزة وصل
      case 'l': // لام شمسية
      case 's': // أحرف ساقطة لا تلفظ
        return isDark ? Colors.white38 : Colors.black38;
      default:
        return isDark ? const Color(0xFFFAF5F0) : const Color(0xFF1E293B);
    }
  }

  /// Parses Tajweed-tagged verse text and outputs [TextSpan]s with Zero-Width Joiners
  /// inserted at span boundaries within the same Arabic word so letters never detach.
  /// يفصل نص التجويد إلى مقاطع نصية مع قاعدتها، ويحقن ZWJ بين الحروف المتصلة.
  ///
  /// منفصلة عن [buildTajweedSpans] لأنها منطق نصي خالص لا يعتمد على الخطوط،
  /// فتُختبر وتُستخدم بلا تحميل أي خط.
  static List<Map<String, dynamic>> parseTajweedSegments(String tajweedVerse) {
    // 1. Tokenize into raw segments: (text, rule)
    final rawSegments = <Map<String, dynamic>>[];
    final ruleStack = <String>[];
    final buffer = StringBuffer();

    void flushRaw() {
      if (buffer.isNotEmpty) {
        rawSegments.add({
          'text': buffer.toString(),
          'rule': ruleStack.isNotEmpty ? ruleStack.last : null,
        });
        buffer.clear();
      }
    }

    int i = 0;
    while (i < tajweedVerse.length) {
      if (tajweedVerse[i] == '[') {
        final match = RegExp(r'^\[([a-z])(?::\d+)?\[').matchAsPrefix(tajweedVerse.substring(i));
        if (match != null) {
          flushRaw();
          ruleStack.add(match.group(1)!);
          i += match.group(0)!.length;
          continue;
        }
        final singleMatch = RegExp(r'^\[([^\]]+)\]').matchAsPrefix(tajweedVerse.substring(i));
        if (singleMatch != null && !singleMatch.group(1)!.contains('[')) {
          flushRaw();
          buffer.write(singleMatch.group(1)!);
          i += singleMatch.group(0)!.length;
          continue;
        }
      }

      if (tajweedVerse[i] == ']') {
        if (ruleStack.isNotEmpty) {
          flushRaw();
          ruleStack.removeLast();
          i++;
          continue;
        }
      }

      buffer.write(tajweedVerse[i]);
      i++;
    }
    flushRaw();

    if (rawSegments.isEmpty) return const [];

    // 2. Process segments and inject ZWJ (\u200D) between connected letters within words
    final processedTexts = rawSegments.map((s) => s['text'] as String).toList();

    for (int s = 0; s < rawSegments.length - 1; s++) {
      final currentText = processedTexts[s];
      final nextText = processedTexts[s + 1];

      // Only join if there is no whitespace or punctuation between them
      if (currentText.isNotEmpty &&
          nextText.isNotEmpty &&
          !currentText.endsWith(' ') &&
          !nextText.startsWith(' ')) {
        final cForward = _connectsForward(currentText);
        final nBackward = _connectsBackward(nextText);

        if (cForward && nBackward) {
          // Both sides connect: append ZWJ to current and prepend ZWJ to next
          if (!processedTexts[s].endsWith('\u200D')) {
            processedTexts[s] = '${processedTexts[s]}\u200D';
          }
          if (!processedTexts[s + 1].startsWith('\u200D')) {
            processedTexts[s + 1] = '\u200D${processedTexts[s + 1]}';
          }
        }
      }
    }

    return [
      for (int s = 0; s < rawSegments.length; s++)
        {'text': processedTexts[s], 'rule': rawSegments[s]['rule'] as String?},
    ];
  }

  /// يبني مقاطع النص المنسَّقة بخط أميري فوق نتيجة [parseTajweedSegments].
  static List<TextSpan> buildTajweedSpans(
    String tajweedVerse, {
    required double fontSize,
    required bool isDark,
  }) {
    final segments = parseTajweedSegments(tajweedVerse);
    if (segments.isEmpty) return const [];

    return [
      for (final seg in segments)
        TextSpan(
          text: seg['text'] as String,
          style: GoogleFonts.amiri(
            fontSize: fontSize,
            height: 2.15,
            color: _getRuleColor(seg['rule'] as String?, isDark),
            fontWeight: FontWeight.normal,
          ),
        ),
    ];
  }
}
