// Accurate Quran Metadata (114 Surahs, 30 Ajza, 6236 Ayahs)
// =======================================================

class SurahInfo {
  final int number;
  final String name;
  final int ayahCount;
  final int startJuz;

  const SurahInfo({
    required this.number,
    required this.name,
    required this.ayahCount,
    required this.startJuz,
  });
}

class JuzInfo {
  final int number;
  final String name;
  final int totalAyahs;
  final String startDescription;

  const JuzInfo({
    required this.number,
    required this.name,
    required this.totalAyahs,
    required this.startDescription,
  });
}

// 114 Quranic Surahs
const List<SurahInfo> quranSurahsInfo = [
  SurahInfo(number: 1, name: 'الفاتحة', ayahCount: 7, startJuz: 1),
  SurahInfo(number: 2, name: 'البقرة', ayahCount: 286, startJuz: 1),
  SurahInfo(number: 3, name: 'آل عمران', ayahCount: 200, startJuz: 3),
  SurahInfo(number: 4, name: 'النساء', ayahCount: 176, startJuz: 4),
  SurahInfo(number: 5, name: 'المائدة', ayahCount: 120, startJuz: 6),
  SurahInfo(number: 6, name: 'الأنعام', ayahCount: 165, startJuz: 7),
  SurahInfo(number: 7, name: 'الأعراف', ayahCount: 206, startJuz: 8),
  SurahInfo(number: 8, name: 'الأنفال', ayahCount: 75, startJuz: 9),
  SurahInfo(number: 9, name: 'التوبة', ayahCount: 129, startJuz: 10),
  SurahInfo(number: 10, name: 'يونس', ayahCount: 109, startJuz: 11),
  SurahInfo(number: 11, name: 'هود', ayahCount: 123, startJuz: 11),
  SurahInfo(number: 12, name: 'يوسف', ayahCount: 111, startJuz: 12),
  SurahInfo(number: 13, name: 'الرعد', ayahCount: 43, startJuz: 13),
  SurahInfo(number: 14, name: 'إبراهيم', ayahCount: 52, startJuz: 13),
  SurahInfo(number: 15, name: 'الحجر', ayahCount: 99, startJuz: 14),
  SurahInfo(number: 16, name: 'النحل', ayahCount: 128, startJuz: 14),
  SurahInfo(number: 17, name: 'الإسراء', ayahCount: 111, startJuz: 15),
  SurahInfo(number: 18, name: 'الكهف', ayahCount: 110, startJuz: 15),
  SurahInfo(number: 19, name: 'مريم', ayahCount: 98, startJuz: 16),
  SurahInfo(number: 20, name: 'طه', ayahCount: 135, startJuz: 16),
  SurahInfo(number: 21, name: 'الأنبياء', ayahCount: 112, startJuz: 17),
  SurahInfo(number: 22, name: 'الحج', ayahCount: 78, startJuz: 17),
  SurahInfo(number: 23, name: 'المؤمنون', ayahCount: 118, startJuz: 18),
  SurahInfo(number: 24, name: 'النور', ayahCount: 64, startJuz: 18),
  SurahInfo(number: 25, name: 'الفرقان', ayahCount: 77, startJuz: 18),
  SurahInfo(number: 26, name: 'الشعراء', ayahCount: 227, startJuz: 19),
  SurahInfo(number: 27, name: 'النمل', ayahCount: 93, startJuz: 19),
  SurahInfo(number: 28, name: 'القصص', ayahCount: 88, startJuz: 20),
  SurahInfo(number: 29, name: 'العنكبوت', ayahCount: 69, startJuz: 20),
  SurahInfo(number: 30, name: 'الروم', ayahCount: 60, startJuz: 21),
  SurahInfo(number: 31, name: 'لقمان', ayahCount: 34, startJuz: 21),
  SurahInfo(number: 32, name: 'السجدة', ayahCount: 30, startJuz: 21),
  SurahInfo(number: 33, name: 'الأحزاب', ayahCount: 73, startJuz: 21),
  SurahInfo(number: 34, name: 'سبأ', ayahCount: 54, startJuz: 22),
  SurahInfo(number: 35, name: 'فاطر', ayahCount: 45, startJuz: 22),
  SurahInfo(number: 36, name: 'يس', ayahCount: 83, startJuz: 22),
  SurahInfo(number: 37, name: 'الصافات', ayahCount: 182, startJuz: 23),
  SurahInfo(number: 38, name: 'ص', ayahCount: 88, startJuz: 23),
  SurahInfo(number: 39, name: 'الزمر', ayahCount: 75, startJuz: 23),
  SurahInfo(number: 40, name: 'غافر', ayahCount: 85, startJuz: 24),
  SurahInfo(number: 41, name: 'فصلت', ayahCount: 54, startJuz: 24),
  SurahInfo(number: 42, name: 'الشورى', ayahCount: 53, startJuz: 25),
  SurahInfo(number: 43, name: 'الزخرف', ayahCount: 89, startJuz: 25),
  SurahInfo(number: 44, name: 'الدخان', ayahCount: 59, startJuz: 25),
  SurahInfo(number: 45, name: 'الجاثية', ayahCount: 37, startJuz: 25),
  SurahInfo(number: 46, name: 'الأحقاف', ayahCount: 35, startJuz: 26),
  SurahInfo(number: 47, name: 'محمد', ayahCount: 38, startJuz: 26),
  SurahInfo(number: 48, name: 'الفتح', ayahCount: 29, startJuz: 26),
  SurahInfo(number: 49, name: 'الحجرات', ayahCount: 18, startJuz: 26),
  SurahInfo(number: 50, name: 'ق', ayahCount: 45, startJuz: 26),
  SurahInfo(number: 51, name: 'الذاريات', ayahCount: 60, startJuz: 26),
  SurahInfo(number: 52, name: 'الطور', ayahCount: 49, startJuz: 27),
  SurahInfo(number: 53, name: 'النجم', ayahCount: 62, startJuz: 27),
  SurahInfo(number: 54, name: 'القمر', ayahCount: 55, startJuz: 27),
  SurahInfo(number: 55, name: 'الرحمن', ayahCount: 78, startJuz: 27),
  SurahInfo(number: 56, name: 'الواقعة', ayahCount: 96, startJuz: 27),
  SurahInfo(number: 57, name: 'الحديد', ayahCount: 29, startJuz: 27),
  SurahInfo(number: 58, name: 'المجادلة', ayahCount: 22, startJuz: 28),
  SurahInfo(number: 59, name: 'الحشر', ayahCount: 24, startJuz: 28),
  SurahInfo(number: 60, name: 'الممتحنة', ayahCount: 13, startJuz: 28),
  SurahInfo(number: 61, name: 'الصف', ayahCount: 14, startJuz: 28),
  SurahInfo(number: 62, name: 'الجمعة', ayahCount: 11, startJuz: 28),
  SurahInfo(number: 63, name: 'المنافقون', ayahCount: 11, startJuz: 28),
  SurahInfo(number: 64, name: 'التغابن', ayahCount: 18, startJuz: 28),
  SurahInfo(number: 65, name: 'الطلاق', ayahCount: 12, startJuz: 28),
  SurahInfo(number: 66, name: 'التحريم', ayahCount: 12, startJuz: 28),
  SurahInfo(number: 67, name: 'الملك', ayahCount: 30, startJuz: 29),
  SurahInfo(number: 68, name: 'القلم', ayahCount: 52, startJuz: 29),
  SurahInfo(number: 69, name: 'الحاقة', ayahCount: 52, startJuz: 29),
  SurahInfo(number: 70, name: 'المعارج', ayahCount: 44, startJuz: 29),
  SurahInfo(number: 71, name: 'نوح', ayahCount: 28, startJuz: 29),
  SurahInfo(number: 72, name: 'الجن', ayahCount: 28, startJuz: 29),
  SurahInfo(number: 73, name: 'المزمل', ayahCount: 20, startJuz: 29),
  SurahInfo(number: 74, name: 'المدثر', ayahCount: 56, startJuz: 29),
  SurahInfo(number: 75, name: 'القيامة', ayahCount: 40, startJuz: 29),
  SurahInfo(number: 76, name: 'الإنسان', ayahCount: 31, startJuz: 29),
  SurahInfo(number: 77, name: 'المرسلات', ayahCount: 50, startJuz: 29),
  SurahInfo(number: 78, name: 'النبأ', ayahCount: 40, startJuz: 30),
  SurahInfo(number: 79, name: 'النازعات', ayahCount: 46, startJuz: 30),
  SurahInfo(number: 80, name: 'عبس', ayahCount: 42, startJuz: 30),
  SurahInfo(number: 81, name: 'التكوير', ayahCount: 29, startJuz: 30),
  SurahInfo(number: 82, name: 'الانفطار', ayahCount: 19, startJuz: 30),
  SurahInfo(number: 83, name: 'المطففين', ayahCount: 36, startJuz: 30),
  SurahInfo(number: 84, name: 'الانشقاق', ayahCount: 25, startJuz: 30),
  SurahInfo(number: 85, name: 'البروج', ayahCount: 22, startJuz: 30),
  SurahInfo(number: 86, name: 'الطارق', ayahCount: 17, startJuz: 30),
  SurahInfo(number: 87, name: 'الأعلى', ayahCount: 19, startJuz: 30),
  SurahInfo(number: 88, name: 'الغاشية', ayahCount: 26, startJuz: 30),
  SurahInfo(number: 89, name: 'الفجر', ayahCount: 30, startJuz: 30),
  SurahInfo(number: 90, name: 'البلد', ayahCount: 20, startJuz: 30),
  SurahInfo(number: 91, name: 'الشمس', ayahCount: 15, startJuz: 30),
  SurahInfo(number: 92, name: 'الليل', ayahCount: 21, startJuz: 30),
  SurahInfo(number: 93, name: 'الضحى', ayahCount: 11, startJuz: 30),
  SurahInfo(number: 94, name: 'الشرح', ayahCount: 8, startJuz: 30),
  SurahInfo(number: 95, name: 'التين', ayahCount: 8, startJuz: 30),
  SurahInfo(number: 96, name: 'العلق', ayahCount: 19, startJuz: 30),
  SurahInfo(number: 97, name: 'القدر', ayahCount: 5, startJuz: 30),
  SurahInfo(number: 98, name: 'البينة', ayahCount: 8, startJuz: 30),
  SurahInfo(number: 99, name: 'الزلزلة', ayahCount: 8, startJuz: 30),
  SurahInfo(number: 100, name: 'العاديات', ayahCount: 11, startJuz: 30),
  SurahInfo(number: 101, name: 'القارعة', ayahCount: 11, startJuz: 30),
  SurahInfo(number: 102, name: 'التكاثر', ayahCount: 8, startJuz: 30),
  SurahInfo(number: 103, name: 'العصر', ayahCount: 3, startJuz: 30),
  SurahInfo(number: 104, name: 'الهمزة', ayahCount: 9, startJuz: 30),
  SurahInfo(number: 105, name: 'الفيل', ayahCount: 5, startJuz: 30),
  SurahInfo(number: 106, name: 'قريش', ayahCount: 4, startJuz: 30),
  SurahInfo(number: 107, name: 'الماعون', ayahCount: 7, startJuz: 30),
  SurahInfo(number: 108, name: 'الكوثر', ayahCount: 3, startJuz: 30),
  SurahInfo(number: 109, name: 'الكافرون', ayahCount: 6, startJuz: 30),
  SurahInfo(number: 110, name: 'النصر', ayahCount: 3, startJuz: 30),
  SurahInfo(number: 111, name: 'المسد', ayahCount: 5, startJuz: 30),
  SurahInfo(number: 112, name: 'الإخلاص', ayahCount: 4, startJuz: 30),
  SurahInfo(number: 113, name: 'الفلق', ayahCount: 5, startJuz: 30),
  SurahInfo(number: 114, name: 'الناس', ayahCount: 6, startJuz: 30),
];

// 30 Quranic Ajza with exact Ayah counts and descriptions
const List<JuzInfo> quranAjzaInfo = [
  JuzInfo(number: 1, name: 'الجزء الأول', totalAyahs: 148, startDescription: 'من الفاتحة 1 إلى البقرة 141'),
  JuzInfo(number: 2, name: 'الجزء الثاني', totalAyahs: 111, startDescription: 'من البقرة 142 إلى البقرة 252'),
  JuzInfo(number: 3, name: 'الجزء الثالث', totalAyahs: 126, startDescription: 'من البقرة 253 إلى آل عمران 92'),
  JuzInfo(number: 4, name: 'الجزء الرابع', totalAyahs: 131, startDescription: 'من آل عمران 93 إلى النساء 23'),
  JuzInfo(number: 5, name: 'الجزء الخامس', totalAyahs: 124, startDescription: 'من النساء 24 إلى النساء 147'),
  JuzInfo(number: 6, name: 'الجزء السادس', totalAyahs: 110, startDescription: 'من النساء 148 إلى المائدة 81'),
  JuzInfo(number: 7, name: 'الجزء السابع', totalAyahs: 149, startDescription: 'من المائدة 82 إلى الأنعام 110'),
  JuzInfo(number: 8, name: 'الجزء الثامن', totalAyahs: 142, startDescription: 'من الأنعام 111 إلى الأعراف 87'),
  JuzInfo(number: 9, name: 'الجزء التاسع', totalAyahs: 159, startDescription: 'من الأعراف 88 إلى الأنفال 40'),
  JuzInfo(number: 10, name: 'الجزء العاشر', totalAyahs: 127, startDescription: 'من الأنفال 41 إلى التوبة 92'),
  JuzInfo(number: 11, name: 'الجزء الحادي عشر', totalAyahs: 151, startDescription: 'من التوبة 93 إلى هود 5'),
  JuzInfo(number: 12, name: 'الجزء الثاني عشر', totalAyahs: 170, startDescription: 'من هود 6 إلى يوسف 52'),
  JuzInfo(number: 13, name: 'الجزء الثالث عشر', totalAyahs: 154, startDescription: 'من يوسف 53 إلى إبراهيم 52'),
  JuzInfo(number: 14, name: 'الجزء الرابع عشر', totalAyahs: 227, startDescription: 'من الحجر 1 إلى النحل 128'),
  JuzInfo(number: 15, name: 'الجزء الخامس عشر', totalAyahs: 185, startDescription: 'من الإسراء 1 إلى الكهف 74'),
  JuzInfo(number: 16, name: 'الجزء السادس عشر', totalAyahs: 269, startDescription: 'من الكهف 75 إلى طه 135'),
  JuzInfo(number: 17, name: 'الجزء السابع عشر', totalAyahs: 190, startDescription: 'من الأنبياء 1 إلى الحج 78'),
  JuzInfo(number: 18, name: 'الجزء الثامن عشر', totalAyahs: 202, startDescription: 'من المؤمنون 1 إلى الفرقان 20'),
  JuzInfo(number: 19, name: 'الجزء التاسع عشر', totalAyahs: 339, startDescription: 'من الفرقان 21 إلى النمل 55'),
  JuzInfo(number: 20, name: 'الجزء العشرون', totalAyahs: 171, startDescription: 'من النمل 56 إلى العنكبوت 45'),
  JuzInfo(number: 21, name: 'الجزء الحادي والعشرون', totalAyahs: 178, startDescription: 'من العنكبوت 46 إلى الأحزاب 30'),
  JuzInfo(number: 22, name: 'الجزء الثاني والعشرون', totalAyahs: 169, startDescription: 'من الأحزاب 31 إلى يس 27'),
  JuzInfo(number: 23, name: 'الجزء الثالث والعشرون', totalAyahs: 357, startDescription: 'من يس 28 إلى الزمر 31'),
  JuzInfo(number: 24, name: 'الجزء الرابع والعشرون', totalAyahs: 175, startDescription: 'من الزمر 32 إلى فصلت 46'),
  JuzInfo(number: 25, name: 'الجزء الخامس والعشرون', totalAyahs: 246, startDescription: 'من فصلت 47 إلى الجاثية 37'),
  JuzInfo(number: 26, name: 'الجزء السادس والعشرون', totalAyahs: 195, startDescription: 'من الأحقاف 1 إلى الذاريات 30'),
  JuzInfo(number: 27, name: 'الجزء السابع والعشرون', totalAyahs: 399, startDescription: 'من الذاريات 31 إلى الحديد 29'),
  JuzInfo(number: 28, name: 'الجزء الثامن والعشرون', totalAyahs: 137, startDescription: 'من المجادلة 1 إلى التحريم 12'),
  JuzInfo(number: 29, name: 'الجزء التاسع والعشرون', totalAyahs: 431, startDescription: 'من الملك 1 إلى المرسلات 50'),
  JuzInfo(number: 30, name: 'الجزء الثلاثون', totalAyahs: 564, startDescription: 'من النبأ 1 إلى الناس 6'),
];

// Helper to look up Surah by name
SurahInfo? findSurahByName(String name) {
  final clean = name.trim();
  for (final s in quranSurahsInfo) {
    if (s.name == clean) return s;
  }
  return null;
}

// Map of Juz boundaries (surahNumber, fromAyah, toAyah) for exact Ayah-to-Juz assignment
class JuzBoundary {
  final int juzNumber;
  final int surahNumber;
  final int fromAyah;
  final int toAyah;

  const JuzBoundary(this.juzNumber, this.surahNumber, this.fromAyah, this.toAyah);
}

const List<JuzBoundary> quranJuzBoundaries = [
  // Juz 1
  JuzBoundary(1, 1, 1, 7),
  JuzBoundary(1, 2, 1, 141),
  // Juz 2
  JuzBoundary(2, 2, 142, 252),
  // Juz 3
  JuzBoundary(3, 2, 253, 286),
  JuzBoundary(3, 3, 1, 92),
  // Juz 4
  JuzBoundary(4, 3, 93, 200),
  JuzBoundary(4, 4, 1, 23),
  // Juz 5
  JuzBoundary(5, 4, 24, 147),
  // Juz 6
  JuzBoundary(6, 4, 148, 176),
  JuzBoundary(6, 5, 1, 81),
  // Juz 7
  JuzBoundary(7, 5, 82, 120),
  JuzBoundary(7, 6, 1, 110),
  // Juz 8
  JuzBoundary(8, 6, 111, 165),
  JuzBoundary(8, 7, 1, 87),
  // Juz 9
  JuzBoundary(9, 7, 88, 206),
  JuzBoundary(9, 8, 1, 40),
  // Juz 10
  JuzBoundary(10, 8, 41, 75),
  JuzBoundary(10, 9, 1, 92),
  // Juz 11
  JuzBoundary(11, 9, 93, 129),
  JuzBoundary(11, 10, 1, 109),
  JuzBoundary(11, 11, 1, 5),
  // Juz 12
  JuzBoundary(12, 11, 6, 123),
  JuzBoundary(12, 12, 1, 52),
  // Juz 13
  JuzBoundary(13, 12, 53, 111),
  JuzBoundary(13, 13, 1, 43),
  JuzBoundary(13, 14, 1, 52),
  // Juz 14
  JuzBoundary(14, 15, 1, 99),
  JuzBoundary(14, 16, 1, 128),
  // Juz 15
  JuzBoundary(15, 17, 1, 111),
  JuzBoundary(15, 18, 1, 74),
  // Juz 16
  JuzBoundary(16, 18, 75, 110),
  JuzBoundary(16, 19, 1, 98),
  JuzBoundary(16, 20, 1, 135),
  // Juz 17
  JuzBoundary(17, 21, 1, 112),
  JuzBoundary(17, 22, 1, 78),
  // Juz 18
  JuzBoundary(18, 23, 1, 118),
  JuzBoundary(18, 24, 1, 64),
  JuzBoundary(18, 25, 1, 20),
  // Juz 19
  JuzBoundary(19, 25, 21, 77),
  JuzBoundary(19, 26, 1, 227),
  JuzBoundary(19, 27, 1, 55),
  // Juz 20
  JuzBoundary(20, 27, 56, 93),
  JuzBoundary(20, 28, 1, 88),
  JuzBoundary(20, 29, 1, 45),
  // Juz 21
  JuzBoundary(21, 29, 46, 69),
  JuzBoundary(21, 30, 1, 60),
  JuzBoundary(21, 31, 1, 34),
  JuzBoundary(21, 32, 1, 30),
  JuzBoundary(21, 33, 1, 30),
  // Juz 22
  JuzBoundary(22, 33, 31, 73),
  JuzBoundary(22, 34, 1, 54),
  JuzBoundary(22, 35, 1, 45),
  JuzBoundary(22, 36, 1, 27),
  // Juz 23
  JuzBoundary(23, 36, 28, 83),
  JuzBoundary(23, 37, 1, 182),
  JuzBoundary(23, 38, 1, 88),
  JuzBoundary(23, 39, 1, 31),
  // Juz 24
  JuzBoundary(24, 39, 32, 75),
  JuzBoundary(24, 40, 1, 85),
  JuzBoundary(24, 41, 1, 46),
  // Juz 25
  JuzBoundary(25, 41, 47, 54),
  JuzBoundary(25, 42, 1, 53),
  JuzBoundary(25, 43, 1, 89),
  JuzBoundary(25, 44, 1, 59),
  JuzBoundary(25, 45, 1, 37),
  // Juz 26
  JuzBoundary(26, 46, 1, 35),
  JuzBoundary(26, 47, 1, 38),
  JuzBoundary(26, 48, 1, 29),
  JuzBoundary(26, 49, 1, 18),
  JuzBoundary(26, 50, 1, 45),
  JuzBoundary(26, 51, 1, 30),
  // Juz 27
  JuzBoundary(27, 51, 31, 60),
  JuzBoundary(27, 52, 1, 49),
  JuzBoundary(27, 53, 1, 62),
  JuzBoundary(27, 54, 1, 55),
  JuzBoundary(27, 55, 1, 78),
  JuzBoundary(27, 56, 1, 96),
  JuzBoundary(27, 57, 1, 29),
  // Juz 28 (Surah 58 to 66)
  JuzBoundary(28, 58, 1, 22),
  JuzBoundary(28, 59, 1, 24),
  JuzBoundary(28, 60, 1, 13),
  JuzBoundary(28, 61, 1, 14),
  JuzBoundary(28, 62, 1, 11),
  JuzBoundary(28, 63, 1, 11),
  JuzBoundary(28, 64, 1, 18),
  JuzBoundary(28, 65, 1, 12),
  JuzBoundary(28, 66, 1, 12),
  // Juz 29 (Surah 67 to 77)
  JuzBoundary(29, 67, 1, 30),
  JuzBoundary(29, 68, 1, 52),
  JuzBoundary(29, 69, 1, 52),
  JuzBoundary(29, 70, 1, 44),
  JuzBoundary(29, 71, 1, 28),
  JuzBoundary(29, 72, 1, 28),
  JuzBoundary(29, 73, 1, 20),
  JuzBoundary(29, 74, 1, 56),
  JuzBoundary(29, 75, 1, 40),
  JuzBoundary(29, 76, 1, 31),
  JuzBoundary(29, 77, 1, 50),
  // Juz 30 (Surah 78 to 114)
  JuzBoundary(30, 78, 1, 40),
  JuzBoundary(30, 79, 1, 46),
  JuzBoundary(30, 80, 1, 42),
  JuzBoundary(30, 81, 1, 29),
  JuzBoundary(30, 82, 1, 19),
  JuzBoundary(30, 83, 1, 36),
  JuzBoundary(30, 84, 1, 25),
  JuzBoundary(30, 85, 1, 22),
  JuzBoundary(30, 86, 1, 17),
  JuzBoundary(30, 87, 1, 19),
  JuzBoundary(30, 88, 1, 26),
  JuzBoundary(30, 89, 1, 30),
  JuzBoundary(30, 90, 1, 20),
  JuzBoundary(30, 91, 1, 15),
  JuzBoundary(30, 92, 1, 21),
  JuzBoundary(30, 93, 1, 11),
  JuzBoundary(30, 94, 1, 8),
  JuzBoundary(30, 95, 1, 8),
  JuzBoundary(30, 96, 1, 19),
  JuzBoundary(30, 97, 1, 5),
  JuzBoundary(30, 98, 1, 8),
  JuzBoundary(30, 99, 1, 8),
  JuzBoundary(30, 100, 1, 11),
  JuzBoundary(30, 101, 1, 11),
  JuzBoundary(30, 102, 1, 8),
  JuzBoundary(30, 103, 1, 3),
  JuzBoundary(30, 104, 1, 9),
  JuzBoundary(30, 105, 1, 5),
  JuzBoundary(30, 106, 1, 4),
  JuzBoundary(30, 107, 1, 7),
  JuzBoundary(30, 108, 1, 3),
  JuzBoundary(30, 109, 1, 6),
  JuzBoundary(30, 110, 1, 3),
  JuzBoundary(30, 111, 1, 5),
  JuzBoundary(30, 112, 1, 4),
  JuzBoundary(30, 113, 1, 5),
  JuzBoundary(30, 114, 1, 6),
];

// Returns the Juz number for a given Surah and Ayah number
int getJuzForSurahAndAyah(int surahNum, int ayahNum) {
  for (final b in quranJuzBoundaries) {
    if (b.surahNumber == surahNum && ayahNum >= b.fromAyah && ayahNum <= b.toAyah) {
      return b.juzNumber;
    }
  }
  return 30; // fallback
}

// Generate all ayah keys (e.g. "78:1", "78:2") belonging to a specific Juz
Set<String> getAllAyahKeysInJuz(int juzNumber) {
  final keys = <String>{};
  for (final b in quranJuzBoundaries) {
    if (b.juzNumber == juzNumber) {
      for (int a = b.fromAyah; a <= b.toAyah; a++) {
        keys.add('${b.surahNumber}:$a');
      }
    }
  }
  return keys;
}

const int totalQuranAyahs = 6236;

SurahInfo? getSurahByName(String name) {
  final clean = name.trim().replaceAll('سورة', '').trim();
  for (final s in quranSurahsInfo) {
    if (s.name == clean || s.name == name.trim()) {
      return s;
    }
  }
  return null;
}

SurahInfo? getSurahByNumber(int number) {
  if (number < 1 || number > 114) return null;
  return quranSurahsInfo[number - 1];
}

int getSurahNumberByName(String name) {
  final s = getSurahByName(name);
  return s?.number ?? 1;
}

