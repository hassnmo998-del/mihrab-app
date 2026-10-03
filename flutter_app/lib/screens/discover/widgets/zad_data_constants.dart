/// Authentic Islamic Spiritual Knowledge Data (Zad Al-Muslim)
/// All texts are rigorously sourced from the Holy Quran, Sahih al-Bukhari,
/// Sahih Muslim, and Hisn al-Muslim (Al-Qahtani) to eliminate theological disputes.
library;

import '../../../models/zad_content.dart';
import '../../../services/allah_names_full_data.dart';
import '../../../services/zad_content_service.dart';

export '../../../models/zad_content.dart' show RuqyahAndDuaItem, GreatRewardDeed, PropheticSeerahPearl;

class AllahNameItem {
  final int number;
  final String name;
  final String meaning;
  final String reflection;
  final String dua;

  const AllahNameItem({
    required this.number,
    required this.name,
    required this.meaning,
    required this.reflection,
    required this.dua,
  });
}

/// نصوص الرقية والأدعية والأجور وقبسات السيرة لم تعد ثوابت هنا: مصدرها
/// `tool/zad/zad.json`، وتُقرأ من [ZadContentService] فتتحدّث بلا إصدار جديد.
class ZadDataConstants {
  // أسماء الله الحسنى (The 99 Beautiful Names of Allah - معاني ودعاء وأثر)
  static List<AllahNameItem> get allahNames => AllahNamesFullData.names;

  // الرقية الشرعية وأدعية الحاجات وتفريج الكرب (من القرآن وصحيح السنة)
  static List<RuqyahAndDuaItem> get ruqyahAndDuas => ZadContentService.instance.content.duas;

  // أعمال يسيرة بأجور عظيمة
  static List<GreatRewardDeed> get greatRewardDeeds => ZadContentService.instance.content.rewards;

  // قبسات من السيرة النبوية
  static List<PropheticSeerahPearl> get propheticPearls => ZadContentService.instance.content.pearls;
}
