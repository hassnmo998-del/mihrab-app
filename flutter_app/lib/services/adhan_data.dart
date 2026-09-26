import '../models/adhan_sound.dart';

/// Master catalog of 20 high-quality, authentic Adhan sounds across the Islamic world.
class AdhanData {
  static const List<String> categories = [
    'الكل',
    'الحرمان الشريفان',
    'الشام وفلسطين',
    'مصر والأزهر',
    'الخليج العربي',
    'العالم الإسلامي',
    'أصوات ندية مختارة',
  ];

  static const List<AdhanSound> allSounds = [
    // 1. Ali Ahmad Mullah - Makkah (Iconic)
    AdhanSound(
      id: "iconic_makkah_ali_mullah",
      title: "علي أحمد ملا",
      category: "الحرمان الشريفان",
      muezzinOrLocation: "الحرم المكي الشريف",
      audioUrl: "https://archive.org/download/MakkahFajrAdhan6913SheikhAliMullah/Makkah%20Fajr%20Adhan%206-9-13%20Sheikh%20Ali%20Mullah.mp3",
      durationSeconds: 242,
    ),

    // 2. Abdul Majeed Al-Surayhi - Madinah
    AdhanSound(
      id: "iconic_madinah_surayhi",
      title: "عبد المجيد السريحي",
      category: "الحرمان الشريفان",
      muezzinOrLocation: "المسجد النبوي الشريف",
      audioUrl: "https://archive.org/download/athan-nasTv/athan-nasTv.mp3",
      durationSeconds: 225,
    ),

    // 3. Yunus Khoja - Makkah Fajr
    AdhanSound(
      id: "iconic_makkah_yunus_khoja",
      title: "يونس خوجة",
      category: "الحرمان الشريفان",
      muezzinOrLocation: "أذان فجر الحرم المكي",
      audioUrl: "https://archive.org/download/MakkahAdhanAl-fajr5-9-13SheikhYunusKhoja/MakkahAdhanAl-fajr5-9-13SheikhYunusKhoja.mp3",
      durationSeconds: 333,
    ),

    // 4. Muhammad bin Majid Hakim - Madinah
    AdhanSound(
      id: "iconic_madinah_hakim",
      title: "محمد ماجد حكيم",
      category: "الحرمان الشريفان",
      muezzinOrLocation: "المسجد النبوي الشريف",
      audioUrl: "https://archive.org/download/adhan_by_sheikh_muhammad_bin_majid_hakim_fajr/adhan_by_sheikh_muhammad_bin_majid_hakim_fajr.mp3",
      durationSeconds: 265,
    ),

    // 5. Al-Aqsa Mosque - Jerusalem
    AdhanSound(
      id: "iconic_alaqsa_blessed",
      title: "أذان المسجد الأقصى",
      category: "الشام وفلسطين",
      muezzinOrLocation: "القدس الشريف - قبة الصخرة",
      audioUrl: "https://archive.org/download/AzanMagribDomeOfRockFri11.4.14/Azan%20Magrib%20Dome%20of%20Rock%20Fri%2011.4.14.mp3",
      durationSeconds: 230,
    ),

    // 6. Muhammad Siddiq Al-Minshawi - Umayyad Mosque Damascus
    AdhanSound(
      id: "iconic_alminshawi",
      title: "محمد صديق المنشاوي",
      category: "الشام وفلسطين",
      muezzinOrLocation: "الجامع الأموي بدمشق",
      audioUrl: "https://archive.org/download/Athanlelmenshawy/%D8%A3%D8%B0%D8%A7%D9%86%20%D8%A7%D9%84%D8%B4%D9%8A%D8%AE%20%D9%85%D8%AD%D9%85%D8%AF%20%D8%B5%D8%AF%D9%8A%D9%82%20%D8%A7%D9%84%D9%85%D9%86%D8%B4%D8%A7%D9%88%D9%8A.mp3",
      durationSeconds: 234,
    ),

    // 7. Abdul Basit Abdus Samad
    AdhanSound(
      id: "iconic_abdulbasit",
      title: "عبد الباسط عبد الصمد",
      category: "مصر والأزهر",
      muezzinOrLocation: "أذان ندي مجود",
      audioUrl: "https://archive.org/download/adhans_sunnah/adhan_abdul_baset.mp3",
      durationSeconds: 215,
    ),

    // 8. Mishary Rashid Al-Afasy
    AdhanSound(
      id: "iconic_alafasy",
      title: "مشاري راشد العفاسي",
      category: "الخليج العربي",
      muezzinOrLocation: "الكويت",
      audioUrl: "https://archive.org/download/adhan_202303/musharaa-bin%20rashid-aleafasaa.mp3",
      durationSeconds: 240,
    ),

    // 9. Mishary Rashid Al-Afasy - Fajr
    AdhanSound(
      id: "iconic_alafasy_fajr",
      title: "مشاري العفاسي (الفجر)",
      category: "الخليج العربي",
      muezzinOrLocation: "الكويت - أذان الفجر",
      audioUrl: "https://archive.org/download/adhan_202303/alfajr-musharaa-bin-rashid-aleafasaa.mp3",
      durationSeconds: 222,
    ),

    // 10. Islam Sobhi
    AdhanSound(
      id: "iconic_islam_sobhi",
      title: "إسلام صبحي",
      category: "أصوات ندية مختارة",
      muezzinOrLocation: "أذان هادئ وخاشع",
      audioUrl: "https://archive.org/download/adhan_202303/asalam-subhi.mp3",
      durationSeconds: 180,
    ),

    // 11. Mansour Al-Salimi
    AdhanSound(
      id: "iconic_salimi",
      title: "منصور السالمي",
      category: "الخليج العربي",
      muezzinOrLocation: "أذان مؤثر وباكي",
      audioUrl: "https://archive.org/download/adhan_202303/mansur-alsaalmaa.mp3",
      durationSeconds: 210,
    ),

    // 12. Yasser Al-Dawsari
    AdhanSound(
      id: "iconic_dawsari",
      title: "ياسر الدوسري",
      category: "الحرمان الشريفان",
      muezzinOrLocation: "إمام المسجد الحرام",
      audioUrl: "https://archive.org/download/adhan_202303/yasir-aldawsari.mp3",
      durationSeconds: 195,
    ),

    // 13. Nasser Al-Qatami
    AdhanSound(
      id: "iconic_qatami",
      title: "ناصر القطامي",
      category: "الخليج العربي",
      muezzinOrLocation: "أذان حجازي مؤثر",
      audioUrl: "https://archive.org/download/adhan_202303/nasir-alqatamaa.mp3",
      durationSeconds: 198,
    ),

    // 14. Salman Al-Utaybi
    AdhanSound(
      id: "iconic_salman_utaybi",
      title: "سلمان العتيبي",
      category: "أصوات ندية مختارة",
      muezzinOrLocation: "أذان ندي خاشع",
      audioUrl: "https://archive.org/download/adzan_201409/AZAN%20par%20Salm%C3%A2n%20Al-%27Utaybi%20%28%D8%B3%D9%84%D9%85%D8%A7%D9%86%20%D8%A7%D9%84%D8%B9%D8%AA%D9%8A%D8%A8%D9%8A%29.mp3",
      durationSeconds: 250,
    ),

    // 15. Hani Ar-Rifai
    AdhanSound(
      id: "iconic_hani_rifai",
      title: "هاني الرفاعي",
      category: "أصوات ندية مختارة",
      muezzinOrLocation: "أذان مؤثر",
      audioUrl: "https://archive.org/download/adzan_201409/Adzan%20by%20syeikh%20Hani%20Ar-Rafei.avi.mp3",
      durationSeconds: 245,
    ),

    // 16. Fahd Al-Kanderi
    AdhanSound(
      id: "iconic_fahd_kanderi",
      title: "فهد الكندري",
      category: "الخليج العربي",
      muezzinOrLocation: "الكويت",
      audioUrl: "https://archive.org/download/adzan_201409/Fahd%20al%20Kanderi%20Beautiful%20Adhan.mp3",
      durationSeconds: 240,
    ),

    // 17. Mahmoud Muhammad Al-Tablawi
    AdhanSound(
      id: "iconic_tablawi",
      title: "محمود محمد الطبلاوي",
      category: "مصر والأزهر",
      muezzinOrLocation: "مصر والأزهر الشريف",
      audioUrl: "https://archive.org/download/adhan_202303/mahmud-muhamad-altablawi.mp3",
      durationSeconds: 200,
    ),

    // 18. Sayed Al-Naqshbandi
    AdhanSound(
      id: "iconic_naqshbandi",
      title: "سيد النقشبندي",
      category: "مصر والأزهر",
      muezzinOrLocation: "إذاعة القرآن الكريم",
      audioUrl: "https://archive.org/download/adhan_202303/sayid-alnaqshabandaa.mp3",
      durationSeconds: 215,
    ),

    // 19. Hamad Al-Deghreri
    AdhanSound(
      id: "iconic_rajhi",
      title: "حمد الدغريري",
      category: "الخليج العربي",
      muezzinOrLocation: "جامع الراجحي بالرياض",
      audioUrl: "https://archive.org/download/adhan_by_sheikh_muhammad_bin_majid_hakim_fajr/adzan_hamad_degheri.mp3",
      durationSeconds: 154,
    ),

    // 20. Mukhtar Hadj Slimane
    AdhanSound(
      id: "iconic_algeria_slimane",
      title: "مختار الحاج سليمان",
      category: "العالم الإسلامي",
      muezzinOrLocation: "الجزائر - الطريقة المغاربية",
      audioUrl: "https://archive.org/download/adhan.notifications/Mokhtar_Hadj_Slimane_Adhan.mp3",
      durationSeconds: 215,
    ),
  ];

  static AdhanSound get defaultSound => allSounds.first;

  static AdhanSound getById(String? id) {
    if (id == null) return defaultSound;
    return allSounds.firstWhere((s) => s.id == id, orElse: () => defaultSound);
  }
}
