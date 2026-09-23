enum PosterAspectRatio {
  square1x1, // 1:1 مربع للمنشورات (فيسبوك، إنستغرام، تيليجرام)
  story9x16, // 9:16 طولي للستوري وحالات واتساب
}

enum PosterLayoutType {
  podiumTop3, // منصة التتويج للمراكز الثلاثة الأولى
  honorListTop5, // لوحة الشرف للخمسة الأوائل
  honorListTop10, // لوحة الشرف للعشرة الأوائل
  singleSpotlight, // وسام تكريم فردي لطالب متفوق
}

enum PosterThemeVariant {
  ministerialGold, // الذهب الملكي والورق العاجي
  quranicEmerald, // الزمردي القرآني الإمبراطوري
  executiveDark, // الأوبسيديان الكحلي الداكن
}

class PosterDesignConfig {
  final PosterAspectRatio aspectRatio;
  final PosterLayoutType layoutType;
  final PosterThemeVariant themeVariant;
  final String title;
  final String subtitle;
  final String ministryHeader; // الترويسة العليا القابلة للتحرير بالكامل
  final String stampText; // نص ختم الاعتماد الرسمي القابل للتحرير
  final bool showMinistryHeader; // إظهار أو إخفاء الترويسة
  final bool showPoints;
  final bool showRankBadges;
  final bool showStudentAvatar;
  final bool showHalaqaName;
  final bool showMosqueStamp;

  const PosterDesignConfig({
    this.aspectRatio = PosterAspectRatio.square1x1,
    this.layoutType = PosterLayoutType.podiumTop3,
    this.themeVariant = PosterThemeVariant.ministerialGold,
    this.title = 'لوحة الشرف الوزارية للمتفوقين',
    this.subtitle = 'تكريم أوائل حفظة كتاب الله تعالى والمتميزين خلقاً وعلماً',
    this.ministryHeader = 'الجمهورية العربية السورية • وزارة التربية والتعليم',
    this.stampText = 'ختم الاعتماد الرسمي',
    this.showMinistryHeader = true,
    this.showPoints = true,
    this.showRankBadges = true,
    this.showStudentAvatar = true,
    this.showHalaqaName = true,
    this.showMosqueStamp = true,
  });

  PosterDesignConfig copyWith({
    PosterAspectRatio? aspectRatio,
    PosterLayoutType? layoutType,
    PosterThemeVariant? themeVariant,
    String? title,
    String? subtitle,
    String? ministryHeader,
    String? stampText,
    bool? showMinistryHeader,
    bool? showPoints,
    bool? showRankBadges,
    bool? showStudentAvatar,
    bool? showHalaqaName,
    bool? showMosqueStamp,
  }) {
    return PosterDesignConfig(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      layoutType: layoutType ?? this.layoutType,
      themeVariant: themeVariant ?? this.themeVariant,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ministryHeader: ministryHeader ?? this.ministryHeader,
      stampText: stampText ?? this.stampText,
      showMinistryHeader: showMinistryHeader ?? this.showMinistryHeader,
      showPoints: showPoints ?? this.showPoints,
      showRankBadges: showRankBadges ?? this.showRankBadges,
      showStudentAvatar: showStudentAvatar ?? this.showStudentAvatar,
      showHalaqaName: showHalaqaName ?? this.showHalaqaName,
      showMosqueStamp: showMosqueStamp ?? this.showMosqueStamp,
    );
  }
}
