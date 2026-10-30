// قصة المسجد التجريبية: بيانات معقولة تُكتب عبر دوال التطبيق نفسها (لا JSON مصطنع)،
// فكل شاشة في الدليل تُعرض بما يعرضه التطبيق فعلاً لمسجد يعمل منذ أسابيع.
import 'package:intl/intl.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';

class DemoStory {
  late Mosque mosque;
  late Mosque otherMosque;
  late Mosque women;
  late Sheikh ahmad;
  late Sheikh mahmoud;
  late Sheikh yousef;
  late Halaqa fatiha;
  late Halaqa furqan;
  late Halaqa nour;
  late Student omar; // ابن ولي الأمر في الفاتحة
  late Student saeed; // أخوه في حلقة النور
  late Student abdullah; // أخوهما في مسجد آخر
  final List<Student> students = [];
  late RecitationTrack nawawi;
  late RecitationTrack jazariyya;
  final List<Reward> rewards = [];
}

const _surahs = <(String, int, int)>[
  // الاسم، عدد الآيات، الجزء: جزء عمّ كاملاً من آخره إلى أوله، كما يحفظه الطالب
  ('الناس', 6, 30), ('الفلق', 5, 30), ('الإخلاص', 4, 30), ('المسد', 5, 30), ('النصر', 3, 30),
  ('الكافرون', 6, 30), ('الكوثر', 3, 30), ('الماعون', 7, 30), ('قريش', 4, 30), ('الفيل', 5, 30),
  ('الهمزة', 9, 30), ('العصر', 3, 30), ('التكاثر', 8, 30), ('القارعة', 11, 30), ('العاديات', 11, 30),
  ('الزلزلة', 8, 30), ('البينة', 8, 30), ('القدر', 5, 30), ('العلق', 19, 30), ('التين', 8, 30),
  ('الشرح', 8, 30), ('الضحى', 11, 30), ('الليل', 21, 30), ('الشمس', 15, 30), ('البلد', 20, 30),
  ('الفجر', 30, 30), ('الغاشية', 26, 30), ('الأعلى', 19, 30), ('الطارق', 17, 30), ('البروج', 22, 30),
  ('الانشقاق', 25, 30), ('المطففين', 36, 30), ('الانفطار', 19, 30), ('التكوير', 29, 30), ('عبس', 42, 30),
  ('النازعات', 46, 30), ('النبأ', 40, 30),
];

const _firstNames = [
  'عمر', 'يوسف', 'أنس', 'محمود', 'ليث', 'بلال', 'حمزة', 'زيد', 'إبراهيم', 'مصعب', 'سلمان', 'ماهر',
];
const _lastNames = [
  'خالد', 'محمد', 'سامر', 'أيمن', 'هشام', 'ياسر', 'رامي', 'عدنان', 'وائل', 'فراس', 'طارق', 'نبيل',
];

/// الأكواد تُشتق من الميلي ثانية: التطبيق الحقيقي لا ينشئ شيخين في اللحظة نفسها، فنفصل بينهما هنا.
void _tick() {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < 3) {}
}

String dayStr(int daysAgo) => DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysAgo)));

DemoStory seedDemoStory(DataService data) {
  final s = DemoStory();

  _tick(); s.mosque = data.addMosque(name: 'جامع النور', address: 'حي الميدان، شارع الثورة', city: 'دمشق', gender: 'male', phone: '0933 120 450');
  _tick(); s.otherMosque = data.addMosque(name: 'جامع الهدى', address: 'حي المزة', city: 'دمشق', gender: 'male', phone: '0944 600 210');

  _tick(); s.ahmad = data.addSheikh(s.mosque.id, 'الشيخ أحمد الحلبي', '0944 111 222');
  _tick(); s.mahmoud = data.addSheikh(s.mosque.id, 'الشيخ محمود الشامي', '0955 222 333');
  _tick(); s.yousef = data.addSheikh(s.mosque.id, 'الشيخ يوسف العمري', '0966 333 444');
  _tick(); final otherSheikh = data.addSheikh(s.otherMosque.id, 'الشيخ عبد الرحمن الكردي', '0977 555 666');

  _tick(); s.fatiha = data.addHalaqa(
    mosqueId: s.mosque.id, sheikhId: s.ahmad.id, name: 'حلقة الفاتحة', ageGroupMin: 6, ageGroupMax: 10,
    schedule: 'السبت - الإثنين - الأربعاء (عصراً)', daysOfWeek: const [6, 1, 3], prayerName: 'asr',
  );
  _tick(); s.furqan = data.addHalaqa(
    mosqueId: s.mosque.id, sheikhId: s.mahmoud.id, name: 'حلقة الفرقان', ageGroupMin: 10, ageGroupMax: 14,
    schedule: 'الأحد - الثلاثاء - الخميس (بعد المغرب)', daysOfWeek: const [7, 2, 4], prayerName: 'maghrib',
  );
  _tick(); s.nour = data.addHalaqa(
    mosqueId: s.mosque.id, sheikhId: s.yousef.id, name: 'حلقة النور', ageGroupMin: 14, ageGroupMax: 18,
    schedule: 'السبت - الإثنين - الأربعاء (بعد العشاء)', daysOfWeek: const [6, 1, 3], prayerName: 'isha',
  );
  _tick(); final otherHalaqa = data.addHalaqa(
    mosqueId: s.otherMosque.id, sheikhId: otherSheikh.id, name: 'حلقة الإتقان', ageGroupMin: 8, ageGroupMax: 12,
  );

  final halaqat = [s.fatiha, s.furqan, s.nour];
  final sheikhOf = {s.fatiha.id: s.ahmad, s.furqan.id: s.mahmoud, s.nour.id: s.yousef};
  for (var i = 0; i < 12; i++) {
    final h = halaqat[i ~/ 4];
    _tick(); final st = data.addStudent(
      mosqueId: s.mosque.id,
      halaqaId: h.id,
      sheikhId: sheikhOf[h.id]!.id,
      fullName: '${_firstNames[i]} ${_lastNames[i]}',
      gender: 'male',
      phone: '09${33 + i} ${100 + i * 7} ${200 + i * 11}',
      welcomePoints: 20,
    );
    s.students.add(st);
  }
  s.omar = s.students[0];
  // أخوه في حلقة النور: يخصّ ولي الأمر نفسه
  _tick(); s.saeed = data.addStudent(
    mosqueId: s.mosque.id, halaqaId: s.nour.id, sheikhId: s.yousef.id,
    fullName: 'سعيد خالد', gender: 'male', phone: '0933 120 999', welcomePoints: 20,
  );
  _tick(); s.abdullah = data.addStudent(
    mosqueId: s.otherMosque.id, halaqaId: otherHalaqa.id, sheikhId: otherSheikh.id,
    fullName: 'عبد الله خالد', gender: 'male', phone: '0933 120 888', welcomePoints: 20,
  );
  s.students.add(s.saeed);

  // الحضور: آخر ثلاثة أسابيع على أيام الحلقة، بحالات متنوعة وثابتة لا عشوائية
  const statuses = ['present', 'present', 'present', 'late', 'present', 'present', 'excused', 'present', 'absent', 'present'];
  var n = 0;
  for (var d = 1; d <= 21; d++) {
    final date = DateTime.now().subtract(Duration(days: d));
    for (final st in s.students) {
      final h = halaqat.firstWhere((x) => x.id == st.halaqaId);
      if (!h.daysOfWeek.contains(date.weekday)) continue;
      final status = st == s.omar ? (n % 7 == 3 ? 'late' : 'present') : statuses[(n++) % statuses.length];
      data.recordAttendance(
        studentId: st.id, halaqaId: st.halaqaId, sessionDate: dayStr(d), status: status,
        pointsEarned: status == 'present' ? 5 : (status == 'late' ? 2 : 0),
      );
    }
  }

  // التسميع: عمر أتمّ جزء عمّ، وبدأ البقرة؛ والبقية بدرجات متفاوتة
  var j = 0;
  for (final (name, ayat, juz) in _surahs) {
    data.recordMemorization(
      studentId: s.omar.id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
      surahName: name, fromAyah: 1, toAyah: ayat, juzNumber: juz,
      sessionType: j % 5 == 4 ? 'review' : 'new_memorization',
      qualityRating: j % 6 == 0 ? 'good' : 'excellent', points: 10,
    );
    j++;
  }
  data.recordMemorization(
    studentId: s.omar.id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
    surahName: 'الملك', fromAyah: 1, toAyah: 30, juzNumber: 29, sessionType: 'new_memorization', points: 15,
  );
  data.recordMemorization(
    studentId: s.omar.id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
    surahName: 'القلم', fromAyah: 1, toAyah: 52, juzNumber: 29, sessionType: 'new_memorization', points: 15,
  );
  data.recordMemorization(
    studentId: s.omar.id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
    surahName: 'الفاتحة', fromAyah: 1, toAyah: 7, juzNumber: 1, sessionType: 'new_memorization', points: 10,
  );
  data.recordMemorization(
    studentId: s.omar.id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
    surahName: 'البقرة', fromAyah: 1, toAyah: 74, juzNumber: 1, sessionType: 'new_memorization', points: 20,
  );
  for (var i = 1; i < s.students.length; i++) {
    final st = s.students[i];
    for (var k = 0; k < (i % 5) + 2; k++) {
      final (name, ayat, juz) = _surahs[k + i % 4];
      data.recordMemorization(
        studentId: st.id, halaqaId: st.halaqaId, sheikhId: sheikhOf[st.halaqaId]?.id,
        surahName: name, fromAyah: 1, toAyah: ayat, juzNumber: juz,
        sessionType: k.isEven ? 'new_memorization' : 'review', points: 8,
      );
    }
  }

  // المناهج والمتون
  _tick(); s.nawawi = data.addRecitationTrack(
    mosqueId: s.mosque.id, name: 'الأربعون النووية', category: 'hadith', unitLabel: 'حديث', totalUnits: 42, pointsPerUnit: 3,
  );
  _tick(); s.jazariyya = data.addRecitationTrack(
    mosqueId: s.mosque.id, name: 'متن الجزرية في التجويد', category: 'custom', unitLabel: 'بيت', totalUnits: 109, pointsPerUnit: 1,
    targetHalaqaIds: [s.furqan.id],
  );
  data.recordSubjectRecitation(
    studentId: s.omar.id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
    trackId: s.nawawi.id, trackName: s.nawawi.name, fromUnit: 1, toUnit: 14, pointsEarned: 42,
  );
  data.recordSubjectRecitation(
    studentId: s.students[1].id, halaqaId: s.fatiha.id, sheikhId: s.ahmad.id,
    trackId: s.nawawi.id, trackName: s.nawawi.name, fromUnit: 1, toUnit: 6, pointsEarned: 18,
  );

  // بنك الجوائز
  for (final (title, cost) in [
    ('حقيبة مدرسية', 150), ('مصحف مفسَّر', 200), ('قلم حبر فاخر', 25), ('دفتر ملاحظات', 40), ('وجبة غداء', 60),
  ]) {
    _tick(); s.rewards.add(data.addReward(mosqueId: s.mosque.id, title: title, pointsCost: cost, description: 'من بنك جوائز جامع النور'));
  }

  // رحلات ودورات وفعاليات
  _tick(); data.addTrip(
    mosqueId: s.mosque.id, title: 'رحلة الغوطة الربيعية', destination: 'الغوطة الشرقية',
    tripDate: DateTime.now().add(const Duration(days: 12)), meetingTime: '08:00 صباحاً',
    deadlineDate: DateTime.now().add(const Duration(days: 8)), description: 'يوم ترفيهي وتربوي لطلاب الحلقات', costPoints: 30,
  );
  _tick(); data.addIntensiveCourse(
    mosqueId: s.mosque.id, name: 'دورة الختمة الصيفية المكثفة', description: 'ثلاثون يوماً من المراجعة والإتقان',
    startDate: DateTime.now().subtract(const Duration(days: 3)), endDate: DateTime.now().add(const Duration(days: 27)),
    sheikhIds: [s.ahmad.id, s.mahmoud.id], halaqaIds: [s.fatiha.id, s.furqan.id],
    studentIds: s.students.take(8).map((e) => e.id).toList(),
  );
  _tick(); data.addCommunityEvent(
    mosqueId: s.mosque.id, title: 'درس في تفسير جزء عمّ', description: 'شرح ميسّر لسور جزء عمّ',
    eventType: 'lesson', timingType: 'prayer_linked', prayerName: 'maghrib', prayerRelation: 'after',
    targetAudience: 'general', eventDateTime: DateTime.now().add(const Duration(days: 1)),
    organizerType: 'sheikh', organizerName: s.ahmad.fullName, sheikhId: s.ahmad.id, isQaEnabled: true,
    isRecurring: true, recurringDays: '6,3',
  );

  // رسائل بين الشيخ وولي الأمر
  data.sendMessage(
    studentId: s.omar.id, halaqaId: s.fatiha.id, senderType: 'sheikh', senderName: s.ahmad.fullName,
    content: 'بارك الله فيكم، عمر أتمّ حفظ جزء عمّ اليوم وأحسن التسميع.',
  );
  data.sendMessage(
    studentId: s.omar.id, halaqaId: s.fatiha.id, senderType: 'parent', senderName: 'ولي أمر عمر',
    content: 'جزاكم الله خيراً شيخنا، سنتابع معه المراجعة في البيت.',
  );

  // جائزة صُرفت وأخرى قسيمتها معلّقة
  data.sellReward(studentId: s.omar.id, rewardId: s.rewards[2].id, cashierName: 'أبو أحمد');
  data.claimReward(studentId: s.omar.id, rewardId: s.rewards[3].id);

  return s;
}
