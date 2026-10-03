import '../../../services/zad_content_service.dart';

/// الأذكار اليومية بأنواعها، بالشكل الذي كانت عليه حين كانت ثوابت في هذا الملف.
/// مصدرها الآن `tool/zad/zad.json` وتُقرأ من [ZadContentService].
Map<String, List<Map<String, dynamic>>> get kAthkarDatabase => {
      for (final category in ZadContentService.instance.content.athkar)
        category.id: [
          for (final item in category.items)
            {'text': item.text, 'virtue': item.virtue, 'count': item.count},
        ],
    };
