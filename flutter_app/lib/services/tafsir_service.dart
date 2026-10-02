import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Supported authentic Quranic Tafsir editions.
enum TafsirEdition {
  muyassar(
    id: 'muyassar',
    name: 'التفسير الميسر',
    shortName: 'الميسر',
    author: 'مجمع الملك فهد لطباعة المصحف الشريف',
    resourceId: null,
    isOffline: true,
  ),
  ibnKathir(
    id: 'ibn_kathir',
    name: 'تفسير ابن كثير',
    shortName: 'ابن كثير',
    author: 'تفسير القرآن العظيم • للإمام الحافظ ابن كثير',
    resourceId: 14,
    isOffline: false,
  ),
  saadi(
    id: 'saadi',
    name: 'تفسير السعدي',
    shortName: 'السعدي',
    author: 'تيسير الكريم الرحمن • للشيخ عبد الرحمن السعدي',
    resourceId: 91,
    isOffline: false,
  ),
  baghawi(
    id: 'baghawi',
    name: 'تفسير البغوي',
    shortName: 'البغوي',
    author: 'معالم التنزيل • للإمام البغوي',
    resourceId: 94,
    isOffline: false,
  ),
  qurtubi(
    id: 'qurtubi',
    name: 'تفسير القرطبي',
    shortName: 'القرطبي',
    author: 'الجامع لأحكام القرآن • للإمام القرطبي',
    resourceId: 90,
    isOffline: false,
  );

  final String id;
  final String name;
  final String shortName;
  final String author;
  final int? resourceId;
  final bool isOffline;

  const TafsirEdition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.author,
    this.resourceId,
    required this.isOffline,
  });

  static TafsirEdition fromId(String? id) {
    if (id == null) return muyassar;
    return values.firstWhere((e) => e.id == id, orElse: () => muyassar);
  }
}

/// Service to load and provide authentic Quran Tafsir (Al-Muyassar, Ibn Kathir, Al-Saadi, etc.)
/// with intelligent verse-by-verse mapping and offline local caching.
class TafsirService {
  TafsirService._();

  static Map<String, dynamic>? _muyassarData;
  static bool _isLoadingMuyassar = false;

  static const String _prefEditionKey = 'selected_tafsir_edition_id';
  static TafsirEdition _selectedEdition = TafsirEdition.muyassar;

  /// Fast in-memory cache for fetched network tafsir items: key = "{editionId}_{surah}_{ayah}"
  static final Map<String, String> _networkCache = {};

  static bool get isLoaded => _muyassarData != null;
  static TafsirEdition get selectedEdition => _selectedEdition;

  /// Initializes saved edition preference and pre-loads offline data.
  static Future<void> ensureLoaded() async {
    // 1. Initialize preferred edition
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefEditionKey);
      if (savedId != null) {
        _selectedEdition = TafsirEdition.fromId(savedId);
      }
    } catch (_) {}

    // 2. Load Al-Muyassar offline JSON
    if (isLoaded) return;
    if (_isLoadingMuyassar) {
      while (_isLoadingMuyassar) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return;
    }

    _isLoadingMuyassar = true;
    try {
      final jsonString = await rootBundle.loadString('assets/data/quran_tafsir_muyassar.json');
      _muyassarData = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _muyassarData = {};
    } finally {
      _isLoadingMuyassar = false;
    }
  }

  /// Sets and saves the user's active Tafsir edition preference.
  static Future<void> setSelectedEdition(TafsirEdition edition) async {
    _selectedEdition = edition;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefEditionKey, edition.id);
    } catch (_) {}
  }

  /// Returns synchronous Tafsir text if available in offline assets or memory cache.
  /// If not yet cached for an online edition, returns null.
  static String? getAyahTafsirSync(int surahNumber, int ayahNumber, [TafsirEdition? edition]) {
    final ed = edition ?? _selectedEdition;

    if (ed == TafsirEdition.muyassar) {
      if (_muyassarData == null) return null;
      final surahMap = _muyassarData![surahNumber.toString()];
      if (surahMap is Map) {
        final text = surahMap[ayahNumber.toString()];
        if (text is String && text.isNotEmpty) {
          return text;
        }
      }
      return 'لا يتوفر تفسير لهذه الآية في التفسير الميسر.';
    }

    final cacheKey = '${ed.id}_${surahNumber}_$ayahNumber';
    return _networkCache[cacheKey];
  }

  /// Backward-compatible synchronous method.
  static String getAyahTafsir(int surahNumber, int ayahNumber, [TafsirEdition? edition]) {
    final cached = getAyahTafsirSync(surahNumber, ayahNumber, edition);
    if (cached != null) return cached;
    final ed = edition ?? _selectedEdition;
    if (ed.isOffline) {
      return 'جاري تحميل التفسير...';
    }
    return 'جاري جلب ${ed.name}...';
  }

  /// Asynchronously fetches the authentic verse-by-verse Tafsir text.
  /// Checks memory cache -> local persistent cache -> verified Quran Foundation API.
  static Future<String> getAyahTafsirAsync(
    int surahNumber,
    int ayahNumber, [
    TafsirEdition? edition,
  ]) async {
    final ed = edition ?? _selectedEdition;

    // 1. Offline Al-Muyassar
    if (ed == TafsirEdition.muyassar) {
      if (!isLoaded) {
        await ensureLoaded();
      }
      return getAyahTafsirSync(surahNumber, ayahNumber, ed) ?? 'لا يتوفر تفسير لهذه الآية.';
    }

    // 2. Check in-memory cache
    final cacheKey = '${ed.id}_${surahNumber}_$ayahNumber';
    if (_networkCache.containsKey(cacheKey)) {
      return _networkCache[cacheKey]!;
    }

    // 3. Check persistent SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final persistentCached = prefs.getString('tafsir_cache_$cacheKey');
      if (persistentCached != null && persistentCached.isNotEmpty) {
        _networkCache[cacheKey] = persistentCached;
        return persistentCached;
      }
    } catch (_) {}

    // 4. Fetch from official Quran Foundation API (verse-by-verse verified endpoint)
    final resourceId = ed.resourceId;
    if (resourceId == null) {
      return 'لا يتوفر هذا التفسير حالياً.';
    }

    final url = 'https://api.quran.com/api/v4/tafsirs/$resourceId/by_ayah/$surahNumber:$ayahNumber';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'MihrabApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rawText = json['tafsir']?['text'] as String?;
        if (rawText != null && rawText.isNotEmpty) {
          final cleanText = cleanTafsirHtml(rawText);
          _networkCache[cacheKey] = cleanText;

          // Save to persistent cache so subsequent requests work completely offline
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('tafsir_cache_$cacheKey', cleanText);
          } catch (_) {}

          return cleanText;
        }
      }
      return 'لم نتمكن من جلب تفسير الآية من المصدر، يرجى المحاولة لاحقاً.';
    } catch (e) {
      return 'تعذر تحميل التفسير حالياً. يرجى التحقق من اتصال الإنترنت (التفسير الميسر متاح دائماً بدون إنترنت).';
    }
  }

  /// Cleans and formats raw HTML text from scholarly Tafsir feeds into crisp, readable Arabic text.
  static String cleanTafsirHtml(String raw) {
    var text = raw
        .replaceAll(RegExp(r'</?(p|div|br|h[1-6])[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<hr[^>]*>', caseSensitive: false), '\n---\n');

    // Strip tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode entities
    text = text
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ');

    // Clean whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
