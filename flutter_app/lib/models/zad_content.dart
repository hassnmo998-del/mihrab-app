/// محتوى تبويب «الأذكار والرقية»: الأذكار اليومية بأنواعها، الرقية والأدعية
/// بتصنيفاتها، الأعمال ذات الأجور، وقبسات السيرة.
///
/// المحتوى حزمة واحدة مصدرها `tool/zad/zad.json`: نسخة منها مضمَّنة في التطبيق،
/// وما يُنشر بعدها يصل الجهاز مرة واحدة ويُحفظ عليه (انظر ZadContentService).
library;

class DhikrItem {
  final String text;

  /// فضل الذكر؛ فارغ إن لم يُذكر.
  final String virtue;

  /// عدد مرات التكرار.
  final int count;

  const DhikrItem({required this.text, this.virtue = '', this.count = 1});
}

/// نوع من الأذكار (الصباح، المساء، بعد الصلاة...). نوع جديد في الحزمة يظهر
/// بطاقته وحده بلا تعديل في التطبيق.
class AthkarCategory {
  final String id;
  final String title;
  final List<DhikrItem> items;

  const AthkarCategory({required this.id, required this.title, required this.items});
}

class DuaCategory {
  final String id;

  /// عنوان الزر في شريط التصنيفات.
  final String title;

  /// الاسم الظاهر على بطاقة الدعاء.
  final String name;

  const DuaCategory({required this.id, required this.title, required this.name});
}

class RuqyahAndDuaItem {
  final String id;
  final String category; // 'ruqyah', 'kurb', 'rizq', 'health', 'family'
  final String categoryName;
  final String title;
  final String arabicText;
  final String source;
  final String instruction;

  const RuqyahAndDuaItem({
    required this.id,
    required this.category,
    required this.categoryName,
    required this.title,
    required this.arabicText,
    required this.source,
    required this.instruction,
  });
}

class GreatRewardDeed {
  final String id;
  final String category;
  final String title;
  final String hadithMatn;
  final String source;
  final String rewardDescription;
  final String actionTip;

  const GreatRewardDeed({
    required this.id,
    required this.category,
    required this.title,
    required this.hadithMatn,
    required this.source,
    required this.rewardDescription,
    required this.actionTip,
  });
}

class PropheticSeerahPearl {
  final String id;
  final String title;
  final String topic;
  final String contextStory;
  final String source;
  final String practicalLesson;

  const PropheticSeerahPearl({
    required this.id,
    required this.title,
    required this.topic,
    required this.contextStory,
    required this.source,
    required this.practicalLesson,
  });
}

class ZadContent {
  /// أحدث مخطط يفهمه هذا الإصدار. حزمة بمخطط أحدث تُتجاهل ويبقى ما على الجهاز.
  static const int supportedSchema = 1;

  final int rev;
  final List<AthkarCategory> athkar;
  final List<DuaCategory> duaCategories;
  final List<RuqyahAndDuaItem> duas;
  final List<GreatRewardDeed> rewards;
  final List<PropheticSeerahPearl> pearls;

  const ZadContent({
    required this.rev,
    required this.athkar,
    required this.duaCategories,
    required this.duas,
    required this.rewards,
    required this.pearls,
  });

  /// يرمي [FormatException] إن كانت الحزمة ناقصة أو معطوبة: حزمة كهذه لا تُعرض
  /// ولا تُحفظ، فلا تمحو تحديثة فاسدة ما عند المستخدم.
  factory ZadContent.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'];
    if (schema is! int || schema < 1 || schema > supportedSchema) {
      throw FormatException('مخطط غير مدعوم: $schema');
    }
    final rev = json['rev'];
    if (rev is! int || rev < 1) throw FormatException('rev غير صالح: $rev');

    final athkar = [
      for (final c in _list(json, 'athkar'))
        AthkarCategory(
          id: _text(c, 'id'),
          title: _text(c, 'title'),
          items: [
            for (final item in _list(c, 'items'))
              DhikrItem(
                text: _text(item, 'text'),
                virtue: _optional(item, 'virtue'),
                count: _count(item['count']),
              ),
          ],
        ),
    ];
    if (athkar.isEmpty) throw const FormatException('لا أذكار في الحزمة');
    for (final c in athkar) {
      if (c.items.isEmpty) throw FormatException('نوع بلا أذكار: ${c.id}');
    }
    _unique(athkar.map((c) => c.id), 'نوع أذكار');

    final duaCategories = [
      for (final c in _list(json, 'duaCategories'))
        DuaCategory(
          id: _text(c, 'id'),
          title: _text(c, 'title'),
          name: _optional(c, 'name', fallback: _text(c, 'title')),
        ),
    ];
    _unique(duaCategories.map((c) => c.id), 'تصنيف أدعية');
    final names = {for (final c in duaCategories) c.id: c.name};

    final duas = [
      for (final d in _list(json, 'duas'))
        RuqyahAndDuaItem(
          id: _text(d, 'id'),
          category: _text(d, 'category'),
          categoryName: names[d['category']] ?? (throw FormatException('دعاء بتصنيف مجهول: ${d['category']}')),
          title: _text(d, 'title'),
          arabicText: _text(d, 'text'),
          source: _optional(d, 'source'),
          instruction: _optional(d, 'instruction'),
        ),
    ];
    _unique(duas.map((d) => d.id), 'دعاء');

    final rewards = [
      for (final r in _list(json, 'rewards'))
        GreatRewardDeed(
          id: _text(r, 'id'),
          category: _optional(r, 'category'),
          title: _text(r, 'title'),
          hadithMatn: _text(r, 'hadith'),
          source: _optional(r, 'source'),
          rewardDescription: _optional(r, 'reward'),
          actionTip: _optional(r, 'tip'),
        ),
    ];
    _unique(rewards.map((r) => r.id), 'عمل');

    final pearls = [
      for (final p in _list(json, 'pearls'))
        PropheticSeerahPearl(
          id: _text(p, 'id'),
          title: _text(p, 'title'),
          topic: _optional(p, 'topic'),
          contextStory: _text(p, 'story'),
          source: _optional(p, 'source'),
          practicalLesson: _optional(p, 'lesson'),
        ),
    ];
    _unique(pearls.map((p) => p.id), 'قبسة');

    return ZadContent(
      rev: rev,
      athkar: List.unmodifiable(athkar),
      duaCategories: List.unmodifiable(duaCategories),
      duas: List.unmodifiable(duas),
      rewards: List.unmodifiable(rewards),
      pearls: List.unmodifiable(pearls),
    );
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('"$key" ليست قائمة');
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item) else throw FormatException('عنصر غير صالح في "$key"'),
    ];
  }

  static String _text(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) throw FormatException('"$key" فارغ أو مفقود');
    return value;
  }

  static String _optional(Map<String, dynamic> json, String key, {String fallback = ''}) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  static int _count(Object? value) {
    if (value == null) return 1;
    if (value is! int || value < 1) throw FormatException('عدد تكرار غير صالح: $value');
    return value;
  }

  static void _unique(Iterable<String> ids, String what) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw FormatException('$what مكرر: $id');
    }
  }
}
