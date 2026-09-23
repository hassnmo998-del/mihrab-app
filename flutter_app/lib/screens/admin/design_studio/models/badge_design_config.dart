enum BadgeOrientation {
  portrait, // طولي للتعليق على الصدر
  landscape, // عرضي لمحفظة الجيب
}

enum BadgeThemeVariant {
  ministerialGold, // الذهب الملكي والورق العاجي
  quranicEmerald, // الزمردي القرآني الإمبراطوري
  executiveDark, // الأوبسيديان الكحلي الداكن
}

class BadgeDesignConfig {
  final BadgeOrientation orientation;
  final BadgeThemeVariant themeVariant;
  final bool showQr;
  final bool showCode;
  final bool showHalaqa;
  final bool showSheikh;
  final bool showPhone;
  final bool showBirthDate;
  final bool showAvatar;
  final bool showMinistryHeader;
  final String customSubHeader;
  final String footerNote;
  final bool showFooterNote;

  const BadgeDesignConfig({
    this.orientation = BadgeOrientation.portrait,
    this.themeVariant = BadgeThemeVariant.ministerialGold,
    this.showQr = true,
    this.showCode = true,
    this.showHalaqa = true,
    this.showSheikh = true,
    this.showPhone = false,
    this.showBirthDate = false,
    this.showAvatar = true,
    this.showMinistryHeader = true,
    this.customSubHeader = 'وزارة التربية والتعليم • قطاع التعليم الديني والقرآني',
    this.footerNote = 'بطاقة رسمية معتمدة • صالحة للعام الدراسي الحالي',
    this.showFooterNote = true,
  });

  BadgeDesignConfig copyWith({
    BadgeOrientation? orientation,
    BadgeThemeVariant? themeVariant,
    bool? showQr,
    bool? showCode,
    bool? showHalaqa,
    bool? showSheikh,
    bool? showPhone,
    bool? showBirthDate,
    bool? showAvatar,
    bool? showMinistryHeader,
    String? customSubHeader,
    String? footerNote,
    bool? showFooterNote,
  }) {
    return BadgeDesignConfig(
      orientation: orientation ?? this.orientation,
      themeVariant: themeVariant ?? this.themeVariant,
      showQr: showQr ?? this.showQr,
      showCode: showCode ?? this.showCode,
      showHalaqa: showHalaqa ?? this.showHalaqa,
      showSheikh: showSheikh ?? this.showSheikh,
      showPhone: showPhone ?? this.showPhone,
      showBirthDate: showBirthDate ?? this.showBirthDate,
      showAvatar: showAvatar ?? this.showAvatar,
      showMinistryHeader: showMinistryHeader ?? this.showMinistryHeader,
      customSubHeader: customSubHeader ?? this.customSubHeader,
      footerNote: footerNote ?? this.footerNote,
      showFooterNote: showFooterNote ?? this.showFooterNote,
    );
  }
}
