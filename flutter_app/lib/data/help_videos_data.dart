/// الفيديوهات التعليمية المضمَّنة في التطبيق (تعمل بلا إنترنت وتفتح فوراً).
///
/// الملفات في `assets/videos/` عمودية 720×1280 H.264 بصوت الشرح وحده، بلا موسيقى (للعامة والإدارات)،
/// ولكلٍّ منها صورة غلاف صغيرة في `assets/videos/posters/` تُعرض قبل التشغيل.
/// صُنعت الفيديوهات بـ `tool/guide/` وملفاته (انظر README هناك). لا تعدّل الأسماء هنا
/// دون إعادة تسمية الملفات: `test/help_videos_data_test.dart` يتحقق أن كل ملف موجود في pubspec.
library;

enum HelpVideoSection { general, admin }

class HelpVideo {
  final String id;
  final HelpVideoSection section;
  final String title;
  final String description;

  /// مدة الفيديو بالثواني (للعرض في البطاقة).
  final int seconds;

  /// نسبة العرض إلى الارتفاع (كلها عمودية 9:16).
  final double aspectRatio;

  const HelpVideo({
    required this.id,
    required this.section,
    required this.title,
    required this.description,
    required this.seconds,
    this.aspectRatio = 9 / 16,
  });

  String get asset => 'assets/videos/$id.mp4';
  String get poster => 'assets/videos/posters/$id.jpg';

  /// «٤٢ ثانية» أو «٣ دقائق وثانية»: كما تُقرأ في البطاقة.
  String get durationLabel {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s ثانية';
    if (s == 0) return m == 1 ? 'دقيقة' : (m == 2 ? 'دقيقتان' : '$m دقائق');
    return '$m:${s.toString().padLeft(2, '0')} دقيقة';
  }
}

/// معرّفات فيديوهات الرتب، لأزرار بطاقات بوابة الإدارة.
class HelpVideoIds {
  HelpVideoIds._();

  static const String portal = 'guide_portal';
  static const String superAdmin = 'guide_super_admin';
  static const String mosqueAdmin = 'guide_mosque_admin';
  static const String women = 'guide_women';
  static const String sheikh = 'guide_sheikh';
  static const String parent = 'guide_parent';
  static const String cashier = 'guide_cashier';
}

class HelpVideos {
  HelpVideos._();

  static const List<HelpVideo> general = [
    HelpVideo(
      id: 'intro_quran',
      section: HelpVideoSection.general,
      title: 'القرآن الكريم',
      description: 'اقرأ المصحف براحة، افتح التفسير بضغطة مطوّلة، كرّر الآية حتى تحفظها، واقرأ قصة السورة ومقاصدها، أو استمع بشاشة كاملة.',
      seconds: 39,
    ),
    HelpVideo(
      id: 'intro_library_athkar',
      section: HelpVideoSection.general,
      title: 'المكتبة والأذكار',
      description: 'عشرات الكتب النافعة تقرؤها داخل التطبيق، وأذكارك اليومية بين يديك والتطبيق يعدّ معك.',
      seconds: 18,
    ),
    HelpVideo(
      id: 'intro_prayer_adhan',
      section: HelpVideoSection.general,
      title: 'الأذان ومواقيت الصلاة',
      description: 'مواقيت دقيقة لمدينتك مع عدّاد للصلاة القادمة، واختيار صوت المؤذّن الذي تحب.',
      seconds: 9,
    ),
    HelpVideo(
      id: 'intro_lessons',
      section: HelpVideoSection.general,
      title: 'مجالس العلم والدروس',
      description: 'مواعيد مجالس العلم القادمة في المساجد، ومكتبة الدروس المسجّلة: اختر الشيخ والمسجد واستمع في أي وقت.',
      seconds: 20,
    ),
    HelpVideo(
      id: 'intro_parents',
      section: HelpVideoSection.general,
      title: 'لأولياء الأمور',
      description: 'كيف تتابع ابنك: بوابة الإدارة، حفظه وحضوره ونقاطه وترتيبه والرحلات، وكل أبنائك في مكان واحد.',
      seconds: 50,
    ),
  ];

  static const List<HelpVideo> admin = [
    HelpVideo(
      id: HelpVideoIds.portal,
      section: HelpVideoSection.admin,
      title: 'بوابة الإدارة والتفويض',
      description: 'كيف تُفتح كل رتبة بمسح بطاقتها أو كتابة رمزها، ولماذا يعمل التطبيق حتى بلا إنترنت.',
      seconds: 71,
    ),
    HelpVideo(
      id: HelpVideoIds.superAdmin,
      section: HelpVideoSection.admin,
      title: 'المشرف العام وتأسيس المسجد',
      description: 'إصدار باركود التأسيس المؤقت، واستمارة المسجد، وبطاقة المدير الدائمة.',
      seconds: 40,
    ),
    HelpVideo(
      id: HelpVideoIds.mosqueAdmin,
      section: HelpVideoSection.admin,
      title: 'مدير المسجد',
      description: 'المشايخ والحلقات والطلاب، البطاقات والطباعة، المناهج والجوائز، الدورات والرحلات والمتابعة وشام كاش والدروس.',
      seconds: 203,
    ),
    HelpVideo(
      id: HelpVideoIds.women,
      section: HelpVideoSection.admin,
      title: 'القسم النسائي المستقل',
      description: 'باركود التسليم وتأسيس الإدارة النسائية بهوية وردية وخصوصية تامة.',
      seconds: 43,
    ),
    HelpVideo(
      id: HelpVideoIds.sheikh,
      section: HelpVideoSection.admin,
      title: 'الشيخ المحفظ ومعلمة الحلقة',
      description: 'رصد الحضور والتسميع، المناهج والرحلات، طلاب الحلقة وتواصل الأهل، وتسجيل الدروس.',
      seconds: 139,
    ),
    HelpVideo(
      id: HelpVideoIds.parent,
      section: HelpVideoSection.admin,
      title: 'ولي الأمر والطالب',
      description: 'ملف الابن وتقدّم حفظه وحضوره ونقاطه، وإضافة أكثر من ابن على هاتف واحد.',
      seconds: 106,
    ),
    HelpVideo(
      id: HelpVideoIds.cashier,
      section: HelpVideoSection.admin,
      title: 'أمين الصندوق وصراف الجوائز',
      description: 'صرف الجائزة في ثوانٍ، ودعم أكثر من مسجد، والسجلات والكشف المالي.',
      seconds: 133,
    ),
  ];

  static List<HelpVideo> get all => [...general, ...admin];

  static HelpVideo? byId(String id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return null;
  }
}
