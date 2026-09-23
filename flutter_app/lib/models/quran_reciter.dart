/// Model representing a Quran Reciter available on EveryAyah CDN.
class QuranReciter {
  final String id;
  final String nameArabic;
  final String nameEnglish;
  final String style; // 'مرتل', 'مجود', 'معلم'
  final String subfolder;
  final String riwayah; // 'حفص عن عاصم', 'ورش', 'قالون'
  final String quality; // '128kbps', '192kbps', etc.

  const QuranReciter({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    required this.style,
    required this.subfolder,
    this.riwayah = 'حفص عن عاصم',
    this.quality = '128kbps',
  });

  /// Builds the direct audio URL for a specific Ayah (Surah: 1-114, Ayah: 1-286).
  /// EveryAyah CDN convention: {subfolder}/{surah3digits}{ayah3digits}.mp3
  String getAyahAudioUrl(int surahNumber, int ayahNumberInSurah) {
    final sStr = surahNumber.toString().padLeft(3, '0');
    final aStr = ayahNumberInSurah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$subfolder/$sStr$aStr.mp3';
  }

  /// Curated list of 15 top esteemed reciters recognized across Islamic ministries and organizations.
  static const List<QuranReciter> defaultReciters = [
    QuranReciter(
      id: 'husary_128kbps',
      nameArabic: 'محمود خليل الحصري',
      nameEnglish: 'Mahmoud Khalil Al-Husary',
      style: 'مرتل',
      subfolder: 'Husary_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'husary_muallim_128kbps',
      nameArabic: 'محمود خليل الحصري (المصحف المعلم)',
      nameEnglish: 'Al-Husary (Muallim / Educational)',
      style: 'معلم للحفظ',
      subfolder: 'Husary_Muallim_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'minshawy_murattal_128kbps',
      nameArabic: 'محمد صديق المنشاوي',
      nameEnglish: 'Mohamed Siddiq Al-Minshawi',
      style: 'مرتل',
      subfolder: 'Minshawy_Murattal_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'minshawy_mujawwad_192kbps',
      nameArabic: 'محمد صديق المنشاوي (مجوّد)',
      nameEnglish: 'Al-Minshawi (Mujawwad)',
      style: 'مجوّد',
      subfolder: 'Minshawy_Mujawwad_192kbps',
      riwayah: 'حفص عن عاصم',
      quality: '192kbps',
    ),
    QuranReciter(
      id: 'abdul_basit_murattal_192kbps',
      nameArabic: 'عبد الباسط عبد الصمد',
      nameEnglish: 'Abdul Basit Abdul Samad',
      style: 'مرتل',
      subfolder: 'Abdul_Basit_Murattal_192kbps',
      riwayah: 'حفص عن عاصم',
      quality: '192kbps',
    ),
    QuranReciter(
      id: 'abdul_basit_mujawwad_128kbps',
      nameArabic: 'عبد الباسط عبد الصمد (مجوّد)',
      nameEnglish: 'Abdul Basit (Mujawwad)',
      style: 'مجوّد',
      subfolder: 'Abdul_Basit_Mujawwad_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'alafasy_128kbps',
      nameArabic: 'مشاري بن راشد العفاسي',
      nameEnglish: 'Mishary Rashid Alafasy',
      style: 'مرتل',
      subfolder: 'Alafasy_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'maher_almuaiqly_128kbps',
      nameArabic: 'ماهر المعيقلي',
      nameEnglish: 'Maher Al-Muaiqly',
      style: 'مرتل',
      subfolder: 'MaherAlMuaiqly128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'saood_shuraym_128kbps',
      nameArabic: 'سعود الشريم',
      nameEnglish: 'Saud Al-Shuraim',
      style: 'مرتل',
      subfolder: 'Saood_ash-Shuraym_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'sudais_192kbps',
      nameArabic: 'عبد الرحمن السديس',
      nameEnglish: 'Abdul Rahman Al-Sudais',
      style: 'مرتل',
      subfolder: 'Abdurrahmaan_As-Sudais_192kbps',
      riwayah: 'حفص عن عاصم',
      quality: '192kbps',
    ),
    QuranReciter(
      id: 'ali_jaber_64kbps',
      nameArabic: 'علي عبد الله جابر',
      nameEnglish: 'Ali Abdullah Jaber',
      style: 'مرتل',
      subfolder: 'Ali_Jaber_64kbps',
      riwayah: 'حفص عن عاصم',
      quality: '64kbps',
    ),
    QuranReciter(
      id: 'ghamadi_40kbps',
      nameArabic: 'سعد الغامدي',
      nameEnglish: 'Saad Al-Ghamdi',
      style: 'مرتل',
      subfolder: 'Ghamadi_40kbps',
      riwayah: 'حفص عن عاصم',
      quality: '40kbps',
    ),
    QuranReciter(
      id: 'shatri_128kbps',
      nameArabic: 'أبو بكر الشاطري',
      nameEnglish: 'Abu Bakr Al-Shatri',
      style: 'مرتل',
      subfolder: 'Abu_Bakr_Ash-Shaatree_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'yasser_dussary_128kbps',
      nameArabic: 'ياسر الدوسري',
      nameEnglish: 'Yasser Al-Dosari',
      style: 'مرتل',
      subfolder: 'Yasser_Ad-Dussary_128kbps',
      riwayah: 'حفص عن عاصم',
      quality: '128kbps',
    ),
    QuranReciter(
      id: 'ayman_suwaid_64kbps',
      nameArabic: 'أيمن سويد (تلاوة تعليمية)',
      nameEnglish: 'Dr. Ayman Suwaid',
      style: 'تعليمي',
      subfolder: 'Ayman_Sowaid_64kbps',
      riwayah: 'حفص عن عاصم',
      quality: '64kbps',
    ),
  ];
}
