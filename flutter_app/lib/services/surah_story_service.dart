import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Data model representing a verified, rich narrative story of a Quranic Surah.
class SurahStoryModel {
  final int number;
  final String name;
  final String period;
  final String story;

  const SurahStoryModel({
    required this.number,
    required this.name,
    required this.period,
    required this.story,
  });

  factory SurahStoryModel.fromJson(Map<String, dynamic> json) {
    return SurahStoryModel(
      number: json['number'] as int? ?? 1,
      name: json['name'] as String? ?? '',
      period: json['period'] as String? ?? 'مكية',
      story: json['story'] as String? ?? '',
    );
  }
}

/// Service to load and provide authentic Surah Stories and contextual themes
/// for all 114 Surahs of the Holy Quran offline.
class SurahStoryService {
  SurahStoryService._();

  static Map<int, SurahStoryModel>? _storiesMap;
  static bool _isLoading = false;

  static bool get isLoaded => _storiesMap != null;

  /// Ensures Surah Stories dataset is loaded into memory asynchronously.
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
      final jsonString = await rootBundle.loadString('assets/data/surah_stories.json');
      final Map<String, dynamic> rawMap = jsonDecode(jsonString);
      final parsed = <int, SurahStoryModel>{};
      rawMap.forEach((key, val) {
        final numKey = int.tryParse(key);
        if (numKey != null && val is Map<String, dynamic>) {
          parsed[numKey] = SurahStoryModel.fromJson(val);
        }
      });
      _storiesMap = parsed;
    } catch (e) {
      _storiesMap = {};
    } finally {
      _isLoading = false;
    }
  }

  /// Returns the story model for a specific Surah number (1 to 114).
  static SurahStoryModel? getStory(int surahNumber) {
    return _storiesMap?[surahNumber];
  }
}
