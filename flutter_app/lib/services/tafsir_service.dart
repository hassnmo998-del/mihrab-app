import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Service to load and provide authentic Tafsir Al-Muyassar (مجمع الملك فهد لطباعة المصحف الشريف)
/// for all 6,236 Ayahs of the Holy Quran offline with 0ms latency.
class TafsirService {
  TafsirService._();

  static Map<String, dynamic>? _tafsirData;
  static bool _isLoading = false;

  static bool get isLoaded => _tafsirData != null;

  /// Ensures Tafsir Al-Muyassar dataset is loaded into memory asynchronously.
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
      final jsonString = await rootBundle.loadString('assets/data/quran_tafsir_muyassar.json');
      _tafsirData = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // Fallback empty map on error to prevent crashes
      _tafsirData = {};
    } finally {
      _isLoading = false;
    }
  }

  /// Returns the Tafsir text for a specific Surah and Ayah number.
  static String getAyahTafsir(int surahNumber, int ayahNumber) {
    if (_tafsirData == null) return 'جاري تحميل التفسير...';
    final surahMap = _tafsirData![surahNumber.toString()];
    if (surahMap is Map) {
      final text = surahMap[ayahNumber.toString()];
      if (text is String && text.isNotEmpty) {
        return text;
      }
    }
    return 'لا يتوفر تفسير لهذه الآية حالياً.';
  }
}
