import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'bukhari_sections.dart';
import 'muslim_sections.dart';
import 'riyad_hadith_data.dart';
import 'qudsi_hadith_data.dart';
import 'muttafaq_hadith_data.dart';

class NawawiHadith {
  final int number;
  final String title;
  final String narrator;
  final String matn;
  final String source;
  final String fawaid;
  final String book; // 'bukhari', 'muslim', 'qudsi', 'muttafaq', 'nawawi', 'riyad'
  final String chapter; // الباب والموضوع

  const NawawiHadith({
    required this.number,
    required this.title,
    required this.narrator,
    required this.matn,
    required this.source,
    required this.fawaid,
    this.book = 'nawawi',
    this.chapter = 'الأربعون النووية',
  });
}

/// Service providing Authentic Hadith Collections (15,200+ hadiths):
/// Sahih al-Bukhari (7,589), Sahih Muslim (7,563), Nawawi 40 (42), Qudsi (40), Riyad.
class HadithService {
  HadithService._();

  static List<NawawiHadith>? _hadiths;
  static bool _isLoading = false;

  static List<NawawiHadith>? _qudsiAll;
  static bool _isLoadingQudsi = false;

  static List<NawawiHadith>? _bukhariHadiths;
  static bool _isLoadingBukhari = false;

  static List<NawawiHadith>? _muslimHadiths;
  static bool _isLoadingMuslim = false;

  static bool get isLoaded => _hadiths != null && _hadiths!.isNotEmpty;

  static bool isBookLoaded(String book) {
    switch (book) {
      case 'bukhari':
        return _bukhariHadiths != null && _bukhariHadiths!.isNotEmpty;
      case 'muslim':
        return _muslimHadiths != null && _muslimHadiths!.isNotEmpty;
      case 'qudsi':
        return _qudsiAll != null && _qudsiAll!.isNotEmpty;
      case 'nawawi':
        return isLoaded;
      case 'muttafaq':
      case 'riyad':
      default:
        return true;
    }
  }

  static Future<void> ensureLoaded() async {
    if (isLoaded) return;
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return;
    }

    _isLoading = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/nawawi_hadiths.json');
      final data = jsonDecode(jsonStr);
      final rawList = data['hadiths'] as List;

      final list = <NawawiHadith>[];
      for (final item in rawList) {
        final num = item['hadithnumber'] as int;
        if (num < 1 || num > 42) continue;

        final rawText = (item['text'] as String).trim();
        final metadata = _hadithMetadata[num] ?? _DefaultMetadata(num);

        list.add(
          NawawiHadith(
            number: num,
            title: metadata.title,
            narrator: metadata.narrator,
            matn: rawText,
            source: metadata.source,
            fawaid: metadata.fawaid,
          ),
        );
      }

      list.sort((a, b) => a.number.compareTo(b.number));
      _hadiths = list;
    } finally {
      _isLoading = false;
    }
  }

  static Future<void> ensureQudsiLoaded() async {
    if (_qudsiAll != null && _qudsiAll!.isNotEmpty) return;
    if (_isLoadingQudsi) {
      while (_isLoadingQudsi) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return;
    }

    _isLoadingQudsi = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/qudsi_full.json', cache: false);
      final data = jsonDecode(jsonStr);
      final rawList = data['hadiths'] as List;

      final list = <NawawiHadith>[...kQudsiHadiths];
      final existingNumbers = kQudsiHadiths.map((h) => h.number).toSet();

      for (final item in rawList) {
        final hadithNum = (item['hadithnumber'] as num?)?.toInt() ?? 0;
        if (hadithNum <= 0 || existingNumbers.contains(hadithNum)) continue;
        final text = (item['text'] as String? ?? '').trim();
        if (text.isEmpty) continue;

        list.add(
          NawawiHadith(
            number: hadithNum,
            title: 'حديث قدسي ($hadithNum)',
            narrator: 'حديث قدسي شريف',
            matn: text,
            source: 'الأربعون القدسية [رقم: $hadithNum]',
            fawaid: 'كلام الله تبارك وتعالى بلفظ رسول الله ﷺ.',
            book: 'qudsi',
            chapter: 'الأربعون القدسية',
          ),
        );
      }

      list.sort((a, b) => a.number.compareTo(b.number));
      _qudsiAll = list;
    } catch (_) {
      _qudsiAll = kQudsiHadiths;
    } finally {
      _isLoadingQudsi = false;
    }
  }

  static Future<void> ensureBukhariLoaded() async {
    if (_bukhariHadiths != null && _bukhariHadiths!.isNotEmpty) return;
    if (_isLoadingBukhari) {
      while (_isLoadingBukhari) {
        await Future.delayed(const Duration(milliseconds: 40));
      }
      return;
    }

    _isLoadingBukhari = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/bukhari_full.json', cache: false);
      final data = jsonDecode(jsonStr);
      final rawList = data['hadiths'] as List;

      final list = <NawawiHadith>[];
      for (final item in rawList) {
        final hadithNum = (item['hadithnumber'] as num?)?.toInt() ?? 0;
        final text = (item['text'] as String? ?? '').trim();
        if (text.isEmpty) continue;

        int bookIdx = 0;
        if (item['reference'] != null && item['reference']['book'] != null) {
          bookIdx = (item['reference']['book'] as num?)?.toInt() ?? 0;
        }

        final chapterName = BukhariSections.getChapterName(bookIdx, hadithNum);

        list.add(
          NawawiHadith(
            number: hadithNum,
            title: 'حديث ($hadithNum) - $chapterName',
            narrator: 'الإمام البخاري رحمه الله',
            matn: text,
            source: 'صحيح البخاري [رقم: $hadithNum] - $chapterName',
            fawaid: '',
            book: 'bukhari',
            chapter: chapterName,
          ),
        );
      }

      list.sort((a, b) => a.number.compareTo(b.number));
      _bukhariHadiths = list;
    } finally {
      _isLoadingBukhari = false;
    }
  }

  static Future<void> ensureMuslimLoaded() async {
    if (_muslimHadiths != null && _muslimHadiths!.isNotEmpty) return;
    if (_isLoadingMuslim) {
      while (_isLoadingMuslim) {
        await Future.delayed(const Duration(milliseconds: 40));
      }
      return;
    }

    _isLoadingMuslim = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/muslim_full.json', cache: false);
      final data = jsonDecode(jsonStr);
      final rawList = data['hadiths'] as List;

      final list = <NawawiHadith>[];
      for (final item in rawList) {
        final hadithNum = (item['hadithnumber'] as num?)?.toInt() ?? 0;
        final text = (item['text'] as String? ?? '').trim();
        if (text.isEmpty) continue;

        int bookIdx = 0;
        if (item['reference'] != null && item['reference']['book'] != null) {
          bookIdx = (item['reference']['book'] as num?)?.toInt() ?? 0;
        }

        final chapterName = MuslimSections.getChapterName(bookIdx, hadithNum);

        list.add(
          NawawiHadith(
            number: hadithNum,
            title: 'حديث ($hadithNum) - $chapterName',
            narrator: 'الإمام مسلم رحمه الله',
            matn: text,
            source: 'صحيح مسلم [رقم: $hadithNum] - $chapterName',
            fawaid: '',
            book: 'muslim',
            chapter: chapterName,
          ),
        );
      }

      list.sort((a, b) => a.number.compareTo(b.number));
      _muslimHadiths = list;
    } finally {
      _isLoadingMuslim = false;
    }
  }

  static Future<void> ensureBookLoaded(String book) async {
    switch (book) {
      case 'bukhari':
        await ensureBukhariLoaded();
        break;
      case 'muslim':
        await ensureMuslimLoaded();
        break;
      case 'qudsi':
        await ensureQudsiLoaded();
        break;
      case 'nawawi':
        await ensureLoaded();
        break;
      case 'muttafaq':
      case 'riyad':
      default:
        break;
    }
  }

  static List<NawawiHadith> getAllHadiths() {
    return _hadiths ?? const [];
  }

  static List<NawawiHadith> getRiyadHadiths() {
    return kRiyadHadiths;
  }

  static List<NawawiHadith> getQudsiHadiths() {
    return _qudsiAll ?? kQudsiHadiths;
  }

  static List<NawawiHadith> getMuttafaqHadiths() {
    return kMuttafaqHadiths;
  }

  static List<NawawiHadith> getBukhariHadiths() {
    return _bukhariHadiths ?? const [];
  }

  static List<NawawiHadith> getMuslimHadiths() {
    return _muslimHadiths ?? const [];
  }

  static List<NawawiHadith> getHadithsByBook(String book) {
    switch (book) {
      case 'bukhari':
        return _bukhariHadiths ?? const [];
      case 'muslim':
        return _muslimHadiths ?? const [];
      case 'qudsi':
        return _qudsiAll ?? kQudsiHadiths;
      case 'muttafaq':
        return kMuttafaqHadiths;
      case 'riyad':
        return kRiyadHadiths;
      case 'nawawi':
      default:
        return getAllHadiths();
    }
  }

  static int getTotalCountByBook(String book) {
    switch (book) {
      case 'bukhari':
        return _bukhariHadiths?.length ?? 7589;
      case 'muslim':
        return _muslimHadiths?.length ?? 7360;
      case 'qudsi':
        return _qudsiAll?.length ?? 40;
      case 'nawawi':
        return 42;
      case 'muttafaq':
        return kMuttafaqHadiths.length;
      case 'riyad':
        return kRiyadHadiths.length;
      default:
        return 0;
    }
  }

  static List<String> getRiyadChapters() {
    return kRiyadHadiths.map((h) => h.chapter).toSet().toList();
  }

  static List<String> getChaptersByBook(String book) {
    if (book == 'bukhari') {
      return BukhariSections.arabicNames.values.toList();
    }
    if (book == 'muslim') {
      return MuslimSections.arabicNames.values.toList();
    }
    return getHadithsByBook(book).map((h) => h.chapter).toSet().toList();
  }

  static final Map<int, _DefaultMetadata> _hadithMetadata = {
    1: _DefaultMetadata(1,
      title: 'الأعمال بالنيات',
      narrator: 'أمير المؤمنين عمر بن الخطاب رضي الله عنه',
      source: 'رواه البخاري ومسلم',
      fawaid: 'النية شرط صحة وقبول سائر الأعمال الصالحة وتمييز العبادات عن العادات.',
    ),
    2: _DefaultMetadata(2,
      title: 'مراتب الدين (الإسلام والإيمان والإحسان)',
      narrator: 'عمر بن الخطاب رضي الله عنه (حديث جبريل الطويل)',
      source: 'رواه مسلم',
      fawaid: 'بيان قواعد الإسلام، وأركان الإيمان الستة، ومرتبة الإحسان العظمى، وعلامات الساعة.',
    ),
    3: _DefaultMetadata(3,
      title: 'أركان الإسلام ودعائمه العظام',
      narrator: 'عبد الله بن عمر بن الخطاب رضي الله عنهما',
      source: 'رواه البخاري ومسلم',
      fawaid: 'بني الإسلام على خمس دعائم أساسية تمثل قوام دين المسلم.',
    ),
    4: _DefaultMetadata(4,
      title: 'مراحل خلق الإنسان وكتابة الأجل والرزق والعمل',
      narrator: 'عبد الله بن مسعود رضي الله عنه',
      source: 'رواه البخاري ومسلم',
      fawaid: 'الإيمان بقدر الله ومشيئته في خلق الإنسان وأجله ورزقه وخاتمته.',
    ),
    5: _DefaultMetadata(5,
      title: 'النهي عن الابتداع في الدين ورد المحدثات',
      narrator: 'أم المؤمنين عائشة رضي الله عنها',
      source: 'رواه البخاري ومسلم',
      fawaid: 'ميزان الأعمال الظاهرة، فكل عبادة تخالف هدي النبي ﷺ مردودة على صاحبها.',
    ),
    6: _DefaultMetadata(6,
      title: 'الحلال بيّن والحرام بيّن وصلاح القلب بالمضغة',
      narrator: 'النعمان بن بشير رضي الله عنهما',
      source: 'رواه البخاري ومسلم',
      fawaid: 'استبراء الدين والعرض باجتناب الشبهات، والحرص على نقاء القلب وصلاحه.',
    ),
    7: _DefaultMetadata(7,
      title: 'الدين النصيحة لله ولكتابه ورسوله ولأئمة المسلمين وعامتهم',
      narrator: 'تميم بن أوس الداري رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'النصيحة هي عماد الدين وإخلاص القول والعمل لجميع المسلمين.',
    ),
    8: _DefaultMetadata(8,
      title: 'حرمة دم المسلم وماله وأداء حق الشهادتين والصلاة والزكاة',
      narrator: 'عبد الله بن عمر رضي الله عنهما',
      source: 'رواه البخاري ومسلم',
      fawaid: 'عصمة دم ومال من أتى بأركان الإسلام الظاهرة وسريرته إلى الله تعالى.',
    ),
    9: _DefaultMetadata(9,
      title: 'التكليف بما يستطاع واجتناب المنهيات وترك كثرة المسائل',
      narrator: 'أبو هريرة عبد الرحمن بن صخر رضي الله عنه',
      source: 'رواه البخاري ومسلم',
      fawaid: 'المنهي عنه يترك كلياً، والمأمور به يفعل قدر الوسع والاستطاعة.',
    ),
    10: _DefaultMetadata(10,
      title: 'أكل الحلال والإنفاق الطيب وأثرهما في إجابة الدعاء',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'الله طيب لا يقبل إلا طيباً، والمال الحرام مانع من إجابة الدعوات.',
    ),
    11: _DefaultMetadata(11,
      title: 'الورع وترك الشبهات (دع ما يريبك إلى ما لا يريبك)',
      narrator: 'الحسن بن علي بن أبي طالب رضي الله عنهما',
      source: 'رواه الترمذي والنسائي وقال الترمذي: حديث حسن صحيح',
      fawaid: 'طمأنينة النفس وركونها إلى الحق واليقين واجتناب الريبة والشك.',
    ),
    12: _DefaultMetadata(12,
      title: 'من حسن إسلام المرء تركه ما لا يعنيه',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه الترمذي وغيره',
      fawaid: 'حفظ اللسان والوقت والانشغال بما ينفع في الدين والدنيا.',
    ),
    13: _DefaultMetadata(13,
      title: 'كمال الإيمان بمحبة الخير للأخ المسلم كالنفس',
      narrator: 'أنس بن مالك رضي الله عنه خادم رسول الله ﷺ',
      source: 'رواه البخاري ومسلم',
      fawaid: 'سلامة الصدر من الحسد وإيثار الخير لكافة المسلمين كالنفس.',
    ),
    14: _DefaultMetadata(14,
      title: 'حرمة دم المسلم المعصوم وموجبات إهداره',
      narrator: 'عبد الله بن مسعود رضي الله عنه',
      source: 'رواه البخاري ومسلم',
      fawaid: 'قدسية الدماء في الإسلام وتحديد الحالات التي يقيم فيها ولي الأمر الحد.',
    ),
    15: _DefaultMetadata(15,
      title: 'خصال الإيمان: قل خيراً أو اصمت، وإكرام الجار والضيف',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه البخاري ومسلم',
      fawaid: 'التحلي بمحاسن الأخلاق وكف الأذى وإكرام الجيران والضيوف.',
    ),
    16: _DefaultMetadata(16,
      title: 'النهي عن الغضب والوصية بالحلم والتؤدة (لا تغضب)',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه البخاري',
      fawaid: 'ملك النفس عند الغضب والابتعاد عن أسباب الطيش والانفعال.',
    ),
    17: _DefaultMetadata(17,
      title: 'وجوب الإحسان في كل شيء حتى في الذبح والقتل',
      narrator: 'شداد بن أوس رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'شريعة الإسلام مبنية على الرحمة والرفق والإحسان حتى مع الحيوان.',
    ),
    18: _DefaultMetadata(18,
      title: 'التقوى في كل حال، وإتباع السيئة الحسنة، وحسن الخلق',
      narrator: 'أبو ذر الغفاري ومعاذ بن جبل رضي الله عنهما',
      source: 'رواه الترمذي وقال: حديث حسن',
      fawaid: 'مراقبة الله سراً وجهراً، ومحو الذنوب بالطاعات، وحسن معاشرة الناس.',
    ),
    19: _DefaultMetadata(19,
      title: 'الوصية الجامعة: احفظ الله يحفظك (يا غلام إني أعلمك كلمات)',
      narrator: 'عبد الله بن عباس رضي الله عنهما',
      source: 'رواه الترمذي وقال: حديث حسن صحيح',
      fawaid: 'التوكل التام على الله، والاستعانة به وحده، والإيمان التام بجريان الأقدار.',
    ),
    20: _DefaultMetadata(20,
      title: 'الحياء من الإيمان (إذا لم تستحِ فاصنع ما شئت)',
      narrator: 'أبو مسعود عقبة بن عمرو الأنصاري البدري رضي الله عنه',
      source: 'رواه البخاري',
      fawaid: 'الحياء هو الرادع الأساسي عن المعاصي وقبائح الأفعال والأقوال.',
    ),
    21: _DefaultMetadata(21,
      title: 'الاستقامة في الإيمان (قل آمنت بالله ثم استقم)',
      narrator: 'سفيان بن عبد الله الثقفي رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'الثبات على عقيدة التوحيد ولزوم طاعة الله ظاهراً وباطناً.',
    ),
    22: _DefaultMetadata(22,
      title: 'دخول الجنة بالفرائض واجتناب المحرمات دون زيادة',
      narrator: 'جابر بن عبد الله الأنصاري رضي الله عنهما',
      source: 'رواه مسلم',
      fawaid: 'كفاية أداء الفرائض واجتناب المحرمات لتحقيق النجاة ودخول الجنة.',
    ),
    23: _DefaultMetadata(23,
      title: 'الطهور شطر الإيمان، والحمد لله تملأ الميزان، والقرآن حجة لك أو عليك',
      narrator: 'أبو مالك الحارث بن عاصم الأشعري رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'عظم شأن الطهارة، وفضل الذكر، والصلاة نور، والصدقة برهان، والصبر ضياء.',
    ),
    24: _DefaultMetadata(24,
      title: 'حديث قدسي في تحريم الظلم وسعة فضل الله (يا عبادي إني حرمت الظلم على نفسي)',
      narrator: 'أبو ذر الغفاري رضي الله عنه عن النبي ﷺ فيما روى عن ربه عز وجل',
      source: 'رواه مسلم',
      fawaid: 'تنزيه الله عن الظلم، وفقر العباد إلى هدايته ومغفرته ورزقه، وتحريم البغي.',
    ),
    25: _DefaultMetadata(25,
      title: 'سعة أبواب الصدقات وفضل التسبيح والتحميد والأمر بالمعروف',
      narrator: 'أبو ذر رضي الله عنه أيضاً',
      source: 'رواه مسلم',
      fawaid: 'الصدقة لا تقتصر على المال بل تشمل كل عمل طيب وتكبيرة وتهليلة.',
    ),
    26: _DefaultMetadata(26,
      title: 'الصدقة عن كل سلامى من الناس كل يوم تطلع فيه الشمس',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه البخاري ومسلم',
      fawaid: 'شكر نعم الجسد بالإصلاح بين الناس، وإعانة المحتاج، والكلمة الطيبة، والخطى للمساجد.',
    ),
    27: _DefaultMetadata(27,
      title: 'البر حسن الخلق، والإثم ما حاك في النفس وكرهت أن يطلع عليه الناس',
      narrator: 'النواس بن سمعان ووابصة بن معبد رضي الله عنهما',
      source: 'رواه مسلم وأحمد والدارمي',
      fawaid: 'الاستفتاء بالقلب السليم لمعرفة خفايا الإثم والحرص على نقاء السريرة.',
    ),
    28: _DefaultMetadata(28,
      title: 'التمسك بالسنة ولزوم هدي الخلفاء الراشدين ومجانبة المحدثات',
      narrator: 'العرباض بن سارية رضي الله عنه',
      source: 'رواه أبو داود والترمذي وقال: حديث حسن صحيح',
      fawaid: 'موعظة بليغة توصي بالسمع والطاعة والاعتصام بالسنة والعض عليها بالنواجذ.',
    ),
    29: _DefaultMetadata(29,
      title: 'أبواب الخير وصلاة الليل وكف اللسان (وهل يكب الناس في النار إلا حصائد ألسنتهم)',
      narrator: 'معاذ بن جبل رضي الله عنه',
      source: 'رواه الترمذي وقال: حديث حسن صحيح',
      fawaid: 'رأس الأمر الإسلام وعموده الصلاة وذروة سنامه الجهاد وملاكه كف اللسان.',
    ),
    30: _DefaultMetadata(30,
      title: 'الوقوف عند حدود الله وفرائضه ونواهيه دون تعنت',
      narrator: 'أبو ثعلبة الخشني جرثوم بن ناشر رضي الله عنه',
      source: 'رواه الدارقطني وغيره وحسنه النووي',
      fawaid: 'أداء الفرائض وحفظ الحدود، وأن ما سكت الله عنه رحمة بالعباد فلا نبحث عنه.',
    ),
    31: _DefaultMetadata(31,
      title: 'حقيقة الزهد وأثره في نيل محبة الله ومحبة الناس',
      narrator: 'سهل بن سعد الساعدي رضي الله عنه',
      source: 'رواه ابن ماجه وغيره بأسانيد حسنة',
      fawaid: 'ازهد في الدنيا يحبك الله، وازهد فيما عند الناس يحبك الناس.',
    ),
    32: _DefaultMetadata(32,
      title: 'القاعدة الفقهية الكبرى: لا ضرر ولا ضرار',
      narrator: 'سعد بن مالك بن سنان الخدري رضي الله عنه',
      source: 'رواه ابن ماجه والدارقطني وغيرهما',
      fawaid: 'تحريم إلحاق الضرر بالنفس أو بالغير ورفع الحرج والضرر في الشريعة.',
    ),
    33: _DefaultMetadata(33,
      title: 'قضاء الدعاوى: البينة على المدعي واليمين على من أنكر',
      narrator: 'عبد الله بن عباس رضي الله عنهما',
      source: 'رواه البيهقي وغيره وبعضه في الصحيحين',
      fawaid: 'صيانة أموال الناس ودمائهم وإقامة أحكام القضاء على البينات الواضحة.',
    ),
    34: _DefaultMetadata(34,
      title: 'مراتب الأمر بالمعروف والنهي عن المنكر (من رأى منكم منكراً فليغيره بيده...)',
      narrator: 'أبو سعيد الخدري رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'درجات تغيير المنكر باليد للمستطيع، ثم باللسان، وأضعف الإيمان الإنكار بالقلب.',
    ),
    35: _DefaultMetadata(35,
      title: 'حقوق المسلم على أخيه وتحريم الحسد والتباغض والتناجش',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'المسلم أخو المسلم لا يظلمه ولا يخذله ولا يحقره، والتقوى هاهنا.',
    ),
    36: _DefaultMetadata(36,
      title: 'تفريج كربات المؤمنين، والستر عليهم، وفضل التماس العلم ومجالس الذكر',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه مسلم',
      fawaid: 'من نفس عن مؤمن كربة نفس الله عنه كربة من كرب يوم القيامة والله في عون العبد ما كان العبد في عون أخيه.',
    ),
    37: _DefaultMetadata(37,
      title: 'سعة فضل الله ورحمته في كتابة الحسنات ومضاعفتها والتجاوز عن السيئات',
      narrator: 'عبد الله بن عباس رضي الله عنهما عن رسول الله ﷺ فيما يروي عن ربه تبارك وتعالى',
      source: 'رواه البخاري ومسلم',
      fawaid: 'الهم بالحسنة يكتب حسنة كاملة، والهم بالسيئة إن تركت لوجه الله كتبت حسنة.',
    ),
    38: _DefaultMetadata(38,
      title: 'حديث الولاية الإلهية: من عادى لي ولياً فقد آذنته بالحرب، والتقرب بالنوافل',
      narrator: 'أبو هريرة رضي الله عنه',
      source: 'رواه البخاري',
      fawaid: 'أحب ما تقرب به العبد إلى الله ما افترضه عليه، ولا يزال يتقرب بالنوافل حتى يحبه الله.',
    ),
    39: _DefaultMetadata(39,
      title: 'رفع الحرج والتجاوز عن الخطأ والنسيان وما استكرهوا عليه',
      narrator: 'عبد الله بن عباس رضي الله عنهما',
      source: 'رواه ابن ماجه والبيهقي وغيرهما بإسناد حسن',
      fawaid: 'رحمة الله بهذه الأمة برفع الإثم والمؤاخذة في أحوال النسيان والخطأ والإكراه.',
    ),
    40: _DefaultMetadata(40,
      title: 'الزهد في الدنيا والاستعداد للآخرة (كن في الدنيا كأنك غريب أو عابر سبيل)',
      narrator: 'عبد الله بن عمر رضي الله عنهما',
      source: 'رواه البخاري',
      fawaid: 'قصر الأمل، واغتنام الصحة قبل السقم، والحياة قبل الموت، والعمل للقاء الله.',
    ),
    41: _DefaultMetadata(41,
      title: 'كمال الإيمان بتحكيم الشرع وانقياد الهوى لما جاء به الرسول ﷺ',
      narrator: 'أبو محمد عبد الله بن عمرو بن العاص رضي الله عنهما',
      source: 'رواه البغوي في شرح السنة بإسناد حسن',
      fawaid: 'لا يؤمن أحدكم حتى يكون هواه تبعاً لما جاء به النبي المصطفى ﷺ.',
    ),
    42: _DefaultMetadata(42,
      title: 'سعة مغفرة الله وفضله لمن أقبل عليه بالتوحيد والدعاء (يا ابن آدم إنك ما دعوتني ورجوتني)',
      narrator: 'أنس بن مالك رضي الله عنه',
      source: 'رواه الترمذي وقال: حديث حسن',
      fawaid: 'لو بلغت ذنوب العبد عنان السماء ثم استغفر الله ولم يشرك به شيئاً أتاه بقراب الأرض مغفرة.',
    ),
  };
}

class _DefaultMetadata {
  final int number;
  final String title;
  final String narrator;
  final String source;
  final String fawaid;

  _DefaultMetadata(
    this.number, {
    this.title = 'حديث من الأربعين النووية',
    this.narrator = 'صحابي جليل رضي الله عنه',
    this.source = 'الأربعون النووية',
    this.fawaid = 'فائدة نبوية شريفة في آداب وأحكام الإسلام.',
  });
}
