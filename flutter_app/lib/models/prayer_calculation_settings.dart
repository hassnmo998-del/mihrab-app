import 'dart:math' as math;
import 'package:adhan/adhan.dart';

/// Represents a predefined city with geographic coordinates and optimal calculation method.
class PrayerCity {
  final String id;
  final String nameAr;
  final String countryAr;
  final double latitude;
  final double longitude;
  final CalculationMethod defaultMethod;

  const PrayerCity({
    required this.id,
    required this.nameAr,
    required this.countryAr,
    required this.latitude,
    required this.longitude,
    this.defaultMethod = CalculationMethod.muslim_world_league,
  });

  String get displayName => '$nameAr، $countryAr';
}

/// Information & Arabic localization for calculation methods.
class CalculationMethodInfo {
  final CalculationMethod method;
  final String titleAr;
  final String regionAr;
  final String descriptionAr;

  const CalculationMethodInfo({
    required this.method,
    required this.titleAr,
    required this.regionAr,
    required this.descriptionAr,
  });

  static const List<CalculationMethodInfo> all = [
    CalculationMethodInfo(
      method: CalculationMethod.muslim_world_league,
      titleAr: 'رابطة العالم الإسلامي',
      regionAr: 'دمشق، بلاد الشام، وأوروبا',
      descriptionAr: 'فجر 18° وعشاء 17° (الأنسب لدمشق وسوريا وأوروبا)',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.umm_al_qura,
      titleAr: 'تقويم أم القرى',
      regionAr: 'مكة المكرمة، السعودية، ودول الخليج',
      descriptionAr: 'فجر 18.5° والعشاء 90 دقيقة ثابتة بعد المغرب (120 برمضان)',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.turkey,
      titleAr: 'رئاسة الشؤون الدينية التركية (Diyanet)',
      regionAr: 'تركيا وشمال سوريا',
      descriptionAr:
          'يتضمن دقائق الاحتياط الرسمية للمساجد (+5 ظهر، +4 عصر، +7 مغرب)',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.egyptian,
      titleAr: 'الهيئة العامة المصرية للمساحة',
      regionAr: 'مصر، السودان، وشمال إفريقيا',
      descriptionAr: 'فجر 19.5° وعشاء 17.5°',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.dubai,
      titleAr: 'دائرة الشؤون الإسلامية بدبي',
      regionAr: 'الإمارات العربية المتحدة',
      descriptionAr: 'فجر 18.2° وعشاء 18.2° مع تعديلات الخليج',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.kuwait,
      titleAr: 'تقويم دولة الكويت',
      regionAr: 'الكويت',
      descriptionAr: 'فجر 18° وعشاء 17.5°',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.qatar,
      titleAr: 'تقويم دولة قطر',
      regionAr: 'قطر',
      descriptionAr: 'فجر 18° والعشاء 90 دقيقة بعد المغرب',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.karachi,
      titleAr: 'جامعة العلوم الإسلامية بكراتشي',
      regionAr: 'باكستان، الهند، وأفغانستان',
      descriptionAr: 'فجر 18° وعشاء 18°',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.north_america,
      titleAr: 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)',
      regionAr: 'أمريكا الشمالية وكندا',
      descriptionAr: 'فجر 15° وعشاء 15°',
    ),
    CalculationMethodInfo(
      method: CalculationMethod.moon_sighting_committee,
      titleAr: 'لجنة رؤية الهلال (Moon Sighting)',
      regionAr: 'مناطق متنوعة',
      descriptionAr: 'فجر 18° وعشاء 18° مع تعديلات موسمية',
    ),
  ];

  static CalculationMethodInfo getByMethod(CalculationMethod method) {
    return all.firstWhere((m) => m.method == method, orElse: () => all.first);
  }
}

/// Information & Arabic localization for Asr Madhab.
class MadhabInfo {
  final Madhab madhab;
  final String titleAr;
  final String descriptionAr;

  const MadhabInfo({
    required this.madhab,
    required this.titleAr,
    required this.descriptionAr,
  });

  static const List<MadhabInfo> all = [
    MadhabInfo(
      madhab: Madhab.shafi,
      titleAr: 'الشافعي / الحنبلي / المالكي (الجمهور)',
      descriptionAr:
          'يبدأ وقت العصر عندما يصبح ظل الشيء مثله (المعتمد في أغلب المساجد)',
    ),
    MadhabInfo(
      madhab: Madhab.hanafi,
      titleAr: 'المذهب الحنفي',
      descriptionAr:
          'يبدأ وقت العصر عندما يصبح ظل الشيء مثليه (متأخر بنحو 45-60 دقيقة)',
    ),
  ];

  static MadhabInfo getByMadhab(Madhab madhab) {
    return all.firstWhere((m) => m.madhab == madhab, orElse: () => all.first);
  }
}

/// Catalog of curated cities across Syria, the Arab world, Turkey, and worldwide.
class PrayerCitiesData {
  PrayerCitiesData._();

  static const List<PrayerCity> syrianCities = [
    PrayerCity(
      id: 'sy_damascus',
      nameAr: 'دمشق',
      countryAr: 'سوريا',
      latitude: 33.5138,
      longitude: 36.2765,
    ),
    PrayerCity(
      id: 'sy_rif_dimashq',
      nameAr: 'ريف دمشق',
      countryAr: 'سوريا',
      latitude: 33.5500,
      longitude: 36.3500,
    ),
    PrayerCity(
      id: 'sy_aleppo',
      nameAr: 'حلب',
      countryAr: 'سوريا',
      latitude: 36.2021,
      longitude: 37.1343,
    ),
    PrayerCity(
      id: 'sy_homs',
      nameAr: 'حمص',
      countryAr: 'سوريا',
      latitude: 34.7324,
      longitude: 36.7136,
    ),
    PrayerCity(
      id: 'sy_hama',
      nameAr: 'حماة',
      countryAr: 'سوريا',
      latitude: 35.1318,
      longitude: 36.7578,
    ),
    PrayerCity(
      id: 'sy_latakia',
      nameAr: 'اللاذقية',
      countryAr: 'سوريا',
      latitude: 35.5317,
      longitude: 35.7900,
    ),
    PrayerCity(
      id: 'sy_tartus',
      nameAr: 'طرطوس',
      countryAr: 'سوريا',
      latitude: 34.8890,
      longitude: 35.8866,
    ),
    PrayerCity(
      id: 'sy_idlib',
      nameAr: 'إدلب',
      countryAr: 'سوريا',
      latitude: 35.9306,
      longitude: 36.6340,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'sy_daraa',
      nameAr: 'درعا',
      countryAr: 'سوريا',
      latitude: 32.6255,
      longitude: 36.1054,
    ),
    PrayerCity(
      id: 'sy_as_suwayda',
      nameAr: 'السويداء',
      countryAr: 'سوريا',
      latitude: 32.7090,
      longitude: 36.5695,
    ),
    PrayerCity(
      id: 'sy_quneitra',
      nameAr: 'القنيطرة',
      countryAr: 'سوريا',
      latitude: 33.1259,
      longitude: 35.8246,
    ),
    PrayerCity(
      id: 'sy_deir_ez_zor',
      nameAr: 'دير الزور',
      countryAr: 'سوريا',
      latitude: 35.3359,
      longitude: 40.1408,
    ),
    PrayerCity(
      id: 'sy_raqqa',
      nameAr: 'الرقة',
      countryAr: 'سوريا',
      latitude: 35.9594,
      longitude: 39.0089,
    ),
    PrayerCity(
      id: 'sy_al_hasakah',
      nameAr: 'الحسكة',
      countryAr: 'سوريا',
      latitude: 36.5024,
      longitude: 40.7483,
    ),
    PrayerCity(
      id: 'sy_qamishli',
      nameAr: 'القامشلي',
      countryAr: 'سوريا',
      latitude: 37.0522,
      longitude: 41.2281,
    ),
    PrayerCity(
      id: 'sy_manbij',
      nameAr: 'منبج',
      countryAr: 'سوريا',
      latitude: 36.5281,
      longitude: 37.9549,
    ),
    PrayerCity(
      id: 'sy_al_bab',
      nameAr: 'الباب',
      countryAr: 'سوريا',
      latitude: 36.3706,
      longitude: 37.5160,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'sy_afrin',
      nameAr: 'عفرين',
      countryAr: 'سوريا',
      latitude: 36.5119,
      longitude: 36.8686,
      defaultMethod: CalculationMethod.turkey,
    ),
  ];

  static const List<PrayerCity> saudiAndGulfCities = [
    PrayerCity(
      id: 'sa_makkah',
      nameAr: 'مكة المكرمة',
      countryAr: 'السعودية',
      latitude: 21.4225,
      longitude: 39.8262,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_madinah',
      nameAr: 'المدينة المنورة',
      countryAr: 'السعودية',
      latitude: 24.4672,
      longitude: 39.6111,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_riyadh',
      nameAr: 'الرياض',
      countryAr: 'السعودية',
      latitude: 24.7136,
      longitude: 46.6753,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_jeddah',
      nameAr: 'جدة',
      countryAr: 'السعودية',
      latitude: 21.5433,
      longitude: 39.1728,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_dammam',
      nameAr: 'الدمام',
      countryAr: 'السعودية',
      latitude: 26.4207,
      longitude: 50.0888,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_khobar',
      nameAr: 'الخبر',
      countryAr: 'السعودية',
      latitude: 26.2818,
      longitude: 50.2083,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_taif',
      nameAr: 'الطائف',
      countryAr: 'السعودية',
      latitude: 21.2854,
      longitude: 40.4222,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_tabuk',
      nameAr: 'تبوك',
      countryAr: 'السعودية',
      latitude: 28.3835,
      longitude: 36.5550,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_abha',
      nameAr: 'أبها',
      countryAr: 'السعودية',
      latitude: 18.2164,
      longitude: 42.5053,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'sa_buraidah',
      nameAr: 'بريدة',
      countryAr: 'السعودية',
      latitude: 26.3592,
      longitude: 43.9818,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'ae_abu_dhabi',
      nameAr: 'أبوظبي',
      countryAr: 'الإمارات',
      latitude: 24.4539,
      longitude: 54.3773,
      defaultMethod: CalculationMethod.dubai,
    ),
    PrayerCity(
      id: 'ae_dubai',
      nameAr: 'دبي',
      countryAr: 'الإمارات',
      latitude: 25.2048,
      longitude: 55.2708,
      defaultMethod: CalculationMethod.dubai,
    ),
    PrayerCity(
      id: 'ae_sharjah',
      nameAr: 'الشارقة',
      countryAr: 'الإمارات',
      latitude: 25.3463,
      longitude: 55.4209,
      defaultMethod: CalculationMethod.dubai,
    ),
    PrayerCity(
      id: 'qa_doha',
      nameAr: 'الدوحة',
      countryAr: 'قطر',
      latitude: 25.2854,
      longitude: 51.5310,
      defaultMethod: CalculationMethod.qatar,
    ),
    PrayerCity(
      id: 'kw_kuwait_city',
      nameAr: 'مدينة الكويت',
      countryAr: 'الكويت',
      latitude: 29.3759,
      longitude: 47.9774,
      defaultMethod: CalculationMethod.kuwait,
    ),
    PrayerCity(
      id: 'bh_manama',
      nameAr: 'المنامة',
      countryAr: 'البحرين',
      latitude: 26.2285,
      longitude: 50.5860,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'om_muscat',
      nameAr: 'مسقط',
      countryAr: 'عُمان',
      latitude: 23.5880,
      longitude: 58.3829,
      defaultMethod: CalculationMethod.dubai,
    ),
  ];

  static const List<PrayerCity> levantAndEgyptCities = [
    PrayerCity(
      id: 'ps_jerusalem',
      nameAr: 'القدس الشريف',
      countryAr: 'فلسطين',
      latitude: 31.7767,
      longitude: 35.2345,
    ),
    PrayerCity(
      id: 'ps_gaza',
      nameAr: 'غزة',
      countryAr: 'فلسطين',
      latitude: 31.5017,
      longitude: 34.4668,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'ps_hebron',
      nameAr: 'الخليل',
      countryAr: 'فلسطين',
      latitude: 31.5293,
      longitude: 35.0938,
    ),
    PrayerCity(
      id: 'ps_nablus',
      nameAr: 'نابلس',
      countryAr: 'فلسطين',
      latitude: 32.2211,
      longitude: 35.2544,
    ),
    PrayerCity(
      id: 'ps_ramallah',
      nameAr: 'رام الله',
      countryAr: 'فلسطين',
      latitude: 31.9038,
      longitude: 35.2034,
    ),
    PrayerCity(
      id: 'jo_amman',
      nameAr: 'عمّان',
      countryAr: 'الأردن',
      latitude: 31.9539,
      longitude: 35.9106,
    ),
    PrayerCity(
      id: 'jo_irbid',
      nameAr: 'إربد',
      countryAr: 'الأردن',
      latitude: 32.5568,
      longitude: 35.8469,
    ),
    PrayerCity(
      id: 'jo_zarqa',
      nameAr: 'الزرقاء',
      countryAr: 'الأردن',
      latitude: 32.0728,
      longitude: 36.0880,
    ),
    PrayerCity(
      id: 'jo_aqaba',
      nameAr: 'العقبة',
      countryAr: 'الأردن',
      latitude: 29.5320,
      longitude: 35.0063,
    ),
    PrayerCity(
      id: 'lb_beirut',
      nameAr: 'بيروت',
      countryAr: 'لبنان',
      latitude: 33.8938,
      longitude: 35.5018,
    ),
    PrayerCity(
      id: 'lb_tripoli',
      nameAr: 'طرابلس',
      countryAr: 'لبنان',
      latitude: 34.4367,
      longitude: 35.8497,
    ),
    PrayerCity(
      id: 'lb_sidon',
      nameAr: 'صيدا',
      countryAr: 'لبنان',
      latitude: 33.5630,
      longitude: 35.3689,
    ),
    PrayerCity(
      id: 'eg_cairo',
      nameAr: 'القاهرة',
      countryAr: 'مصر',
      latitude: 30.0444,
      longitude: 31.2357,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'eg_alexandria',
      nameAr: 'الإسكندرية',
      countryAr: 'مصر',
      latitude: 31.2001,
      longitude: 29.9187,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'eg_giza',
      nameAr: 'الجيزة',
      countryAr: 'مصر',
      latitude: 30.0131,
      longitude: 31.2089,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'eg_tanta',
      nameAr: 'طنطا',
      countryAr: 'مصر',
      latitude: 30.7865,
      longitude: 31.0004,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'eg_mansoura',
      nameAr: 'المنصورة',
      countryAr: 'مصر',
      latitude: 31.0409,
      longitude: 31.3785,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'eg_asyut',
      nameAr: 'أسيوط',
      countryAr: 'مصر',
      latitude: 27.1809,
      longitude: 31.1837,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'eg_aswan',
      nameAr: 'أسوان',
      countryAr: 'مصر',
      latitude: 24.0889,
      longitude: 32.8998,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'sd_khartoum',
      nameAr: 'الخرطوم',
      countryAr: 'السودان',
      latitude: 15.5007,
      longitude: 32.5599,
      defaultMethod: CalculationMethod.egyptian,
    ),
    PrayerCity(
      id: 'ly_tripoli',
      nameAr: 'طرابلس الغرب',
      countryAr: 'ليبيا',
      latitude: 32.8872,
      longitude: 13.1913,
    ),
    PrayerCity(
      id: 'ly_benghazi',
      nameAr: 'بنغازي',
      countryAr: 'ليبيا',
      latitude: 32.1166,
      longitude: 20.0686,
    ),
    PrayerCity(
      id: 'tn_tunis',
      nameAr: 'تونس',
      countryAr: 'تونس',
      latitude: 36.8065,
      longitude: 10.1815,
    ),
    PrayerCity(
      id: 'dz_algiers',
      nameAr: 'الجزائر العاصمة',
      countryAr: 'الجزائر',
      latitude: 36.7538,
      longitude: 3.0588,
    ),
    PrayerCity(
      id: 'dz_oran',
      nameAr: 'وهران',
      countryAr: 'الجزائر',
      latitude: 35.6987,
      longitude: -0.6349,
    ),
    PrayerCity(
      id: 'ma_rabat',
      nameAr: 'الرباط',
      countryAr: 'المغرب',
      latitude: 34.0209,
      longitude: -6.8416,
    ),
    PrayerCity(
      id: 'ma_casablanca',
      nameAr: 'الدار البيضاء',
      countryAr: 'المغرب',
      latitude: 33.5731,
      longitude: -7.5898,
    ),
    PrayerCity(
      id: 'ma_marrakech',
      nameAr: 'مراكش',
      countryAr: 'المغرب',
      latitude: 31.6295,
      longitude: -7.9811,
    ),
  ];

  static const List<PrayerCity> iraqAndYemenCities = [
    PrayerCity(
      id: 'iq_baghdad',
      nameAr: 'بغداد',
      countryAr: 'العراق',
      latitude: 33.3152,
      longitude: 44.3661,
    ),
    PrayerCity(
      id: 'iq_mosul',
      nameAr: 'الموصل',
      countryAr: 'العراق',
      latitude: 36.3400,
      longitude: 43.1300,
    ),
    PrayerCity(
      id: 'iq_basra',
      nameAr: 'البصرة',
      countryAr: 'العراق',
      latitude: 30.5081,
      longitude: 47.7835,
    ),
    PrayerCity(
      id: 'iq_erbil',
      nameAr: 'أربيل',
      countryAr: 'العراق',
      latitude: 36.1911,
      longitude: 44.0091,
    ),
    PrayerCity(
      id: 'iq_sulaymaniyah',
      nameAr: 'السليمانية',
      countryAr: 'العراق',
      latitude: 35.5558,
      longitude: 45.4351,
    ),
    PrayerCity(
      id: 'iq_najaf',
      nameAr: 'النجف الأشرف',
      countryAr: 'العراق',
      latitude: 32.0259,
      longitude: 44.3463,
    ),
    PrayerCity(
      id: 'iq_karbala',
      nameAr: 'كربلاء المقدسة',
      countryAr: 'العراق',
      latitude: 32.6160,
      longitude: 44.0249,
    ),
    PrayerCity(
      id: 'ye_sanaa',
      nameAr: 'صنعاء',
      countryAr: 'اليمن',
      latitude: 15.3694,
      longitude: 44.1910,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'ye_aden',
      nameAr: 'عدن',
      countryAr: 'اليمن',
      latitude: 12.7855,
      longitude: 45.0187,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
    PrayerCity(
      id: 'ye_taiz',
      nameAr: 'تعز',
      countryAr: 'اليمن',
      latitude: 13.5789,
      longitude: 44.0175,
      defaultMethod: CalculationMethod.umm_al_qura,
    ),
  ];

  static const List<PrayerCity> turkeyCities = [
    PrayerCity(
      id: 'tr_istanbul',
      nameAr: 'إسطنبول',
      countryAr: 'تركيا',
      latitude: 41.0082,
      longitude: 28.9784,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_gaziantep',
      nameAr: 'غازي عنتاب',
      countryAr: 'تركيا',
      latitude: 37.0662,
      longitude: 37.3833,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_ankara',
      nameAr: 'أنقرة',
      countryAr: 'تركيا',
      latitude: 39.9334,
      longitude: 32.8597,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_sanliurfa',
      nameAr: 'شانلي أورفا',
      countryAr: 'تركيا',
      latitude: 37.1674,
      longitude: 38.7955,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_antakya',
      nameAr: 'أنطاكية / هاتاي',
      countryAr: 'تركيا',
      latitude: 36.2023,
      longitude: 36.1606,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_mersin',
      nameAr: 'مرسين',
      countryAr: 'تركيا',
      latitude: 36.8121,
      longitude: 34.6415,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_kilis',
      nameAr: 'كلس',
      countryAr: 'تركيا',
      latitude: 36.7161,
      longitude: 37.1150,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_konya',
      nameAr: 'قونية',
      countryAr: 'تركيا',
      latitude: 37.8746,
      longitude: 32.4932,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_bursa',
      nameAr: 'بورصة',
      countryAr: 'تركيا',
      latitude: 40.1885,
      longitude: 29.0610,
      defaultMethod: CalculationMethod.turkey,
    ),
    PrayerCity(
      id: 'tr_izmir',
      nameAr: 'إزمير',
      countryAr: 'تركيا',
      latitude: 38.4237,
      longitude: 27.1428,
      defaultMethod: CalculationMethod.turkey,
    ),
  ];

  static const List<PrayerCity> worldwideCities = [
    PrayerCity(
      id: 'de_berlin',
      nameAr: 'برلين',
      countryAr: 'ألمانيا',
      latitude: 52.5200,
      longitude: 13.4050,
    ),
    PrayerCity(
      id: 'de_munich',
      nameAr: 'ميونخ',
      countryAr: 'ألمانيا',
      latitude: 48.1351,
      longitude: 11.5820,
    ),
    PrayerCity(
      id: 'de_cologne',
      nameAr: 'كولن / فرانكفورت',
      countryAr: 'ألمانيا',
      latitude: 50.1109,
      longitude: 8.6821,
    ),
    PrayerCity(
      id: 'gb_london',
      nameAr: 'لندن',
      countryAr: 'بريطانيا',
      latitude: 51.5074,
      longitude: -0.1278,
    ),
    PrayerCity(
      id: 'fr_paris',
      nameAr: 'باريس',
      countryAr: 'فرنسا',
      latitude: 48.8566,
      longitude: 2.3522,
    ),
    PrayerCity(
      id: 'at_vienna',
      nameAr: 'فيينا',
      countryAr: 'النمسا',
      latitude: 48.2082,
      longitude: 16.3738,
    ),
    PrayerCity(
      id: 'nl_amsterdam',
      nameAr: 'أمستردام',
      countryAr: 'هولندا',
      latitude: 52.3676,
      longitude: 4.9041,
    ),
    PrayerCity(
      id: 'be_brussels',
      nameAr: 'بروكسل',
      countryAr: 'بلجيكا',
      latitude: 50.8503,
      longitude: 4.3517,
    ),
    PrayerCity(
      id: 'se_stockholm',
      nameAr: 'ستوكهولم',
      countryAr: 'السويد',
      latitude: 59.3293,
      longitude: 18.0686,
    ),
    PrayerCity(
      id: 'no_oslo',
      nameAr: 'أوسلو',
      countryAr: 'النرويج',
      latitude: 59.9139,
      longitude: 10.7522,
    ),
    PrayerCity(
      id: 'dk_copenhagen',
      nameAr: 'كوبنهاغن',
      countryAr: 'الدنمارك',
      latitude: 55.6761,
      longitude: 12.5683,
    ),
    PrayerCity(
      id: 'ca_toronto',
      nameAr: 'تورونتو',
      countryAr: 'كندا',
      latitude: 43.6532,
      longitude: -79.3832,
      defaultMethod: CalculationMethod.north_america,
    ),
    PrayerCity(
      id: 'us_new_york',
      nameAr: 'نيويورك',
      countryAr: 'أمريكا',
      latitude: 40.7128,
      longitude: -74.0060,
      defaultMethod: CalculationMethod.north_america,
    ),
    PrayerCity(
      id: 'us_chicago',
      nameAr: 'شيكاغو',
      countryAr: 'أمريكا',
      latitude: 41.8781,
      longitude: -87.6298,
      defaultMethod: CalculationMethod.north_america,
    ),
  ];

  static List<PrayerCity> get allCities => [
    ...syrianCities,
    ...saudiAndGulfCities,
    ...levantAndEgyptCities,
    ...iraqAndYemenCities,
    ...turkeyCities,
    ...worldwideCities,
  ];

  static PrayerCity get defaultCity => syrianCities.first; // Damascus

  /// Finds the nearest predefined city to the given coordinates (using Haversine formula)
  static (PrayerCity city, double distanceKm)? findNearestCity(
    double lat,
    double lng,
  ) {
    if (allCities.isEmpty) return null;

    PrayerCity? nearest;
    double minDistance = double.infinity;

    for (final city in allCities) {
      final d = _haversineKm(lat, lng, city.latitude, city.longitude);
      if (d < minDistance) {
        minDistance = d;
        nearest = city;
      }
    }

    if (nearest == null) return null;
    return (nearest, minDistance);
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
