import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/datasources.dart';
import 'package:flutter_app/data/repositories/repositories.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/points_ledger.dart';

/// نقاط الطلاب بكل سيناريوهاتها: كل موضع يمنح أو يخصم (الحضور، التسميع، الحديث،
/// المتون، اليدوي، الجوائز)، وكل ما يعرضها (الرصيد، سجل الحركات، الترتيب).
///
/// القاعدة التي يحرسها كل اختبار: **رصيد الطالب = مجموع حركاته في سجل النقاط**.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageDataSource local;
  late OfflineSyncQueueManager queue;
  late AttendanceRepositoryImpl attendance;
  late RecitationRepositoryImpl recitation;
  late RecitationTracksRepositoryImpl tracks;
  late StudentsRepositoryImpl students;
  late RewardsRepositoryImpl rewards;
  late CompetitionsRepositoryImpl competitions;
  late Student ali;
  late Student omar;

  const day1 = '2026-10-05';
  const day2 = '2026-10-06';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    local = LocalStorageDataSource();
    queue = OfflineSyncQueueManager();
    attendance = AttendanceRepositoryImpl(local, queue);
    recitation = RecitationRepositoryImpl(local, queue);
    tracks = RecitationTracksRepositoryImpl(local, queue);
    students = StudentsRepositoryImpl(local, queue);
    rewards = RewardsRepositoryImpl(local, queue);
    competitions = CompetitionsRepositoryImpl(local, syncQueueManager: queue);

    local.mosques.add(Mosque(id: 'm1', name: 'جامع النقاط', city: 'دمشق', gender: 'male', accessCode: 'MSQ-AAAA2222'));
    local.halaqat.add(Halaqa(id: 'h1', mosqueId: 'm1', name: 'حلقة نافع'));
    ali = students.addStudent(mosqueId: 'm1', halaqaId: 'h1', fullName: 'علي', gender: 'male', phone: '');
    omar = students.addStudent(mosqueId: 'm1', halaqaId: 'h1', fullName: 'عمر', gender: 'male', phone: '');
  });

  int ledgerSum(Student s) =>
      local.pointsLogs.where((l) => l.studentId == s.id).fold<int>(0, (sum, l) => sum + l.points);

  /// الرصيد المعروض في كل الشاشات يطابق مجموع الحركات، لكل طالب.
  void expectBalanced() {
    for (final s in local.students) {
      expect(s.totalPoints, ledgerSum(s), reason: 'رصيد ${s.fullName} لا يطابق سجل حركاته');
    }
  }

  void mark(Student s, String day, String status, int points) => attendance.recordAttendance(
        studentId: s.id,
        halaqaId: s.halaqaId,
        sessionDate: day,
        status: status,
        pointsEarned: points,
      );

  List<PointsLog> shown(Student s) => students.getStudentPointsLog(s.id);

  group('الحضور', () {
    test('«حاضر» مرتين لليوم نفسه: نقاط الحضور مرة واحدة', () {
      mark(ali, day1, 'present', 5);
      mark(ali, day1, 'present', 5);
      mark(ali, day1, 'present', 5);

      expect(ali.totalPoints, 5);
      expect(shown(ali), hasLength(1));
      expect(local.attendanceRecords.where((a) => a.studentId == ali.id), hasLength(1));
      expectBalanced();
    });

    test('تعديل الحالة يعدّل النقاط إلى قيمتها الجديدة: حاضر ← متأخر ← غائب ← حاضر', () {
      mark(ali, day1, 'present', 5);
      expect(ali.totalPoints, 5);

      mark(ali, day1, 'late', 2);
      expect(ali.totalPoints, 2);
      expect(shown(ali).single.points, 2);
      expect(shown(ali).single.reason, contains('متأخر'));

      mark(ali, day1, 'absent', 0);
      expect(ali.totalPoints, 0);
      // حركة بلا نقاط لا تُعرض في سجل الطالب
      expect(shown(ali), isEmpty);

      mark(ali, day1, 'present', 5);
      expect(ali.totalPoints, 5);
      expect(shown(ali).single.reason, contains('حضور نظامي'));

      final record = local.attendanceRecords.singleWhere((a) => a.studentId == ali.id);
      expect(record.status, 'present');
      expect(record.pointsEarned, 5);
      expectBalanced();
    });

    test('تعديل الحالة لا ينقل الحركة من يومها', () {
      mark(ali, day1, 'present', 5);
      final first = shown(ali).single.createdAt;
      mark(ali, day1, 'late', 2);
      expect(shown(ali).single.createdAt, first);
    });

    test('أيام مختلفة تتراكم، وكل يوم مستقل عن غيره', () {
      mark(ali, day1, 'present', 5);
      mark(ali, day2, 'present', 5);
      mark(ali, day2, 'late', 2);

      expect(ali.totalPoints, 7);
      expect(shown(ali), hasLength(2));
      expect(local.attendanceRecords.where((a) => a.studentId == ali.id), hasLength(2));
      expectBalanced();
    });

    test('رصد الحلقة كلها ثم إعادة الرصد: لكل طالب نقاطه مرة واحدة', () {
      final group = [
        for (var i = 0; i < 30; i++)
          students.addStudent(mosqueId: 'm1', halaqaId: 'h1', fullName: 'طالب $i', gender: 'male', phone: ''),
      ];
      for (var pass = 0; pass < 2; pass++) {
        for (final s in group) {
          mark(s, day1, 'present', 5);
        }
      }

      for (final s in group) {
        expect(s.totalPoints, 5);
      }
      expect(local.attendanceRecords.where((a) => a.sessionDate == day1), hasLength(30));
      expectBalanced();
    });

    test('نقاط الحضور معطّلة: يُسجَّل الحضور ولا حركة نقاط', () {
      mark(ali, day1, 'present', 0);

      expect(ali.totalPoints, 0);
      expect(local.pointsLogs.where((l) => l.studentId == ali.id), isEmpty);
      expect(local.attendanceRecords.single.status, 'present');
    });

    test('الحضور لا يخصم: قيمة سالبة تُعامَل صفراً', () {
      mark(ali, day1, 'present', 5);
      mark(ali, day2, 'absent', -3);

      expect(ali.totalPoints, 5);
      expect(local.attendanceRecords.firstWhere((a) => a.sessionDate == day2).pointsEarned, 0);
      expectBalanced();
    });

    test('شيخان يرصدان الطالب نفسه في اليوم نفسه من جهازين: سجل واحد وحركة واحدة', () {
      // المعرّف من (الطالب، اليوم) لا من الساعة، فالجهازان يكتبان الصف نفسه في السحابة
      mark(ali, day1, 'present', 5);
      final otherLocal = LocalStorageDataSource()..students.add(Student.fromJson(ali.toJson())..totalPoints = 0);
      final otherDevice = AttendanceRepositoryImpl(otherLocal, OfflineSyncQueueManager());
      otherDevice.recordAttendance(
          studentId: ali.id, halaqaId: 'h1', sessionDate: day1, status: 'present', pointsEarned: 5);

      expect(otherLocal.attendanceRecords.single.id, local.attendanceRecords.single.id);
      expect(otherLocal.pointsLogs.single.id, local.pointsLogs.firstWhere((l) => l.studentId == ali.id).id);
      expect(otherLocal.pointsLogs.single.id, PointsLedger.attendanceLogId(ali.id, day1));
    });

    test('يوم رُصد بنسخة قديمة ضاعفت نقاطه: إعادة رصده تصحّحه', () {
      // نسخة سابقة: ضغطتان على «حاضر» = حركتان بمعرّفين عشوائيين وعشر نقاط
      for (var i = 0; i < 2; i++) {
        local.pointsLogs.add(PointsLog(
          id: 'pts-old-$i',
          studentId: ali.id,
          points: 5,
          reason: 'حضور جلسة $day1 (حضور نظامي)',
          category: 'attendance',
          createdAt: DateTime(2026, 10, 5, 17),
        ));
      }
      local.attendanceRecords.add(AttendanceRecord(
          id: 'att-old', studentId: ali.id, halaqaId: 'h1', sessionDate: day1, status: 'present', pointsEarned: 5));
      ali.totalPoints = 10;

      mark(ali, day1, 'present', 5);

      expect(ali.totalPoints, 5);
      // السجل القديم يحتفظ بمعرّفه ولا يتكرر
      expect(local.attendanceRecords.single.id, 'att-old');
      expectBalanced();

      mark(ali, day1, 'absent', 0);
      expect(ali.totalPoints, 0);
      expectBalanced();
    });
  });

  group('التسميع والحديث والمتون', () {
    void recite(Student s, int points, {bool counted = true, int segments = 1}) => recitation.recordRecitationBatch(
          studentId: s.id,
          halaqaId: 'h1',
          items: [
            for (var i = 0; i < segments; i++)
              {'surahName': 'البقرة', 'fromAyah': 1 + i * 5, 'toAyah': 5 + i * 5, 'juzNumber': 1},
          ],
          sessionType: 'new_memorization',
          points: points,
          countsTowardsStatistics: counted,
        );

    test('تسميع من عدة مقاطع: النقاط تُمنح مرة واحدة للجلسة لا لكل مقطع', () {
      recite(ali, 20, segments: 4);

      expect(ali.totalPoints, 20);
      expect(local.memorizationRecords, hasLength(4));
      expect(local.memorizationRecords.fold<int>(0, (sum, m) => sum + m.pointsEarned), 20);
      expect(shown(ali).single.points, 20);
      expectBalanced();
    });

    test('جلسة خاصة غير محسوبة: تُحفظ في السجل ولا تمنح نقاطاً', () {
      recite(ali, 20, counted: false);

      expect(ali.totalPoints, 0);
      expect(shown(ali).single.points, 0);
      expect(local.memorizationRecords.single.countsTowardsStatistics, isFalse);
      expectBalanced();
    });

    test('الحديث والمتون يمنحان نقاطهما مرة لكل تسميع', () {
      recitation.recordHadith(studentId: ali.id, hadithTitle: 'إنما الأعمال بالنيات', points: 10);
      tracks.recordSubjectRecitation(
          studentId: ali.id, trackId: 't1', trackName: 'تحفة الأطفال', fromUnit: 1, toUnit: 5, pointsEarned: 15);
      tracks.recordSubjectRecitation(
          studentId: ali.id,
          trackId: 't1',
          trackName: 'تحفة الأطفال',
          fromUnit: 6,
          toUnit: 9,
          pointsEarned: 12,
          countsTowardsStatistics: false);

      expect(ali.totalPoints, 25);
      expect(shown(ali).map((l) => l.category), containsAll(['hadith', 'recitation']));
      expectBalanced();
    });

    test('التسميع لا يخصم: قيمة سالبة تُعامَل صفراً', () {
      recite(ali, 30);
      recite(ali, -10);
      recitation.recordHadith(studentId: ali.id, hadithTitle: 'حديث', points: -5);
      tracks.recordSubjectRecitation(
          studentId: ali.id, trackId: 't1', trackName: 'متن', fromUnit: 1, toUnit: 2, pointsEarned: -7);

      expect(ali.totalPoints, 30);
      expectBalanced();
    });

    test('طالب غير موجود: لا حركة ولا خطأ', () {
      recitation.recordHadith(studentId: 'nobody', hadithTitle: 'حديث', points: 10);
      mark(Student(id: 'ghost', mosqueId: 'm1', halaqaId: 'h1', fullName: 'x', gender: 'male', phone: '', code: 'X'),
          day1, 'present', 5);

      expect(local.pointsLogs.where((l) => l.studentId == 'nobody' || l.studentId == 'ghost'), isEmpty);
    });
  });

  group('الإضافة والخصم اليدويان', () {
    test('إضافة ثم خصم، والخصم لا ينزل بالرصيد تحت الصفر', () {
      expect(students.adjustStudentPoints(studentId: ali.id, delta: 30, reason: 'تميّز')['total'], 30);
      expect(students.adjustStudentPoints(studentId: ali.id, delta: -10, actorName: 'الشيخ')['total'], 20);

      final clamped = students.adjustStudentPoints(studentId: ali.id, delta: -100);
      expect(clamped['applied'], -20);
      expect(clamped['clamped'], isTrue);
      expect(ali.totalPoints, 0);

      final refused = students.adjustStudentPoints(studentId: ali.id, delta: -5);
      expect(refused['success'], isFalse);
      expect(students.adjustStudentPoints(studentId: ali.id, delta: 0)['success'], isFalse);

      expect(shown(ali).map((l) => l.points), [-20, -10, 30]);
      expectBalanced();
    });

    test('نقاط الترحيب عند التسجيل لها حركة في السجل', () {
      final welcomed = students.addStudent(
          mosqueId: 'm1', halaqaId: 'h1', fullName: 'خالد', gender: 'male', phone: '', welcomePoints: 50);

      expect(welcomed.totalPoints, 50);
      expect(shown(welcomed).single.points, 50);
      expectBalanced();
    });
  });

  group('الجوائز', () {
    late Reward bag;

    setUp(() {
      bag = rewards.addReward(mosqueId: 'm1', title: 'حقيبة', pointsCost: 50);
      students.adjustStudentPoints(studentId: ali.id, delta: 120);
    });

    test('طلب القسيمة لا يخصم، واستلامها يخصم مرة واحدة', () {
      final voucher = rewards.claimReward(studentId: ali.id, rewardId: bag.id)!;
      expect(ali.totalPoints, 120);

      expect(rewards.dispenseReward(voucherCode: voucher.redemptionCode, cashierName: 'أبو أحمد')['success'], isTrue);
      expect(ali.totalPoints, 70);

      final again = rewards.dispenseReward(voucherCode: voucher.redemptionCode, cashierName: 'أبو أحمد');
      expect(again['success'], isFalse);
      expect(ali.totalPoints, 70);
      expectBalanced();
    });

    test('القسيمة نفسها تُصرف من جهازين لم يتزامنا: حركة خصم واحدة بمعرّف القسيمة', () {
      final voucher = rewards.claimReward(studentId: ali.id, rewardId: bag.id)!;
      rewards.dispenseReward(voucherCode: voucher.redemptionCode, cashierName: 'الأول');
      final deduction = local.pointsLogs.firstWhere((l) => l.category == 'reward');
      expect(deduction.id, 'pts-rdm-${voucher.id}');

      // الجهاز الثاني ما زال يرى القسيمة معلّقة، ووصلته حركة الخصم بالمزامنة
      voucher.status = 'pending';
      rewards.dispenseReward(voucherCode: voucher.redemptionCode, cashierName: 'الثاني');

      expect(local.pointsLogs.where((l) => l.category == 'reward'), hasLength(1));
      expect(ali.totalPoints, 70);
      expectBalanced();
    });

    test('الصرف المباشر يخصم ويسجّل، ورصيد لا يكفي يُرفض بلا أي تغيير', () {
      expect(rewards.sellReward(studentId: ali.id, rewardId: bag.id, cashierName: 'ص')['success'], isTrue);
      expect(rewards.sellReward(studentId: ali.id, rewardId: bag.id, cashierName: 'ص')['success'], isTrue);
      expect(ali.totalPoints, 20);

      final refused = rewards.sellReward(studentId: ali.id, rewardId: bag.id, cashierName: 'ص');
      expect(refused['success'], isFalse);
      expect(ali.totalPoints, 20);
      expect(rewards.claimReward(studentId: ali.id, rewardId: bag.id), isNull);
      expect(local.redemptions, hasLength(2));
      expectBalanced();
    });
  });

  group('الرصيد يُشتق من سجل الحركات', () {
    test('عدّاد كتبه جهاز بنسخة قديمة فوق الرصيد يُصحَّح من السجل', () {
      mark(ali, day1, 'present', 5);
      students.adjustStudentPoints(studentId: ali.id, delta: 40);
      local.pointsLedgerComplete = true;

      // وصل سجل الطالب من السحابة بعدّاد قديم (جهاز آخر رفع نسخته)
      ali.totalPoints = 5;
      expect(local.recomputePointBalances(), isTrue);

      expect(ali.totalPoints, 45);
      expect(local.recomputePointBalances(), isFalse);
    });

    test('حركات جهازين تندمج: الرصيد مجموعها أياً كان ترتيب وصولها', () {
      local.pointsLedgerComplete = true;
      students.adjustStudentPoints(studentId: ali.id, delta: 100); // هذا الجهاز
      // جهاز الصراف صرف جائزة، وجهاز شيخ آخر منح نقاطاً: حركتاهما وصلتا بالمزامنة
      local.pointsLogs.addAll([
        PointsLog(id: 'pts-cashier', studentId: ali.id, points: -50, reason: 'استلام جائزة', category: 'reward', createdAt: DateTime.now()),
        PointsLog(id: 'pts-sheikh2', studentId: ali.id, points: 15, reason: 'تسميع', category: 'memorization', createdAt: DateTime.now()),
      ]);
      // ومع سجل الطالب عدّاد لا يعرف إلا إحداهما
      ali.totalPoints = 50;

      local.recomputePointBalances();

      expect(ali.totalPoints, 65);
    });

    test('جهاز جديد لم تصله الحركات بعد: يبقى العدّاد كما ورد ولا يُصفَّر', () {
      final fresh = LocalStorageDataSource()
        ..students.add(Student(
            id: 's9', mosqueId: 'm1', halaqaId: 'h1', fullName: 'ز', gender: 'male', phone: '', code: 'STD-9', totalPoints: 80));

      expect(fresh.pointsLedgerComplete, isFalse);
      expect(fresh.recomputePointBalances(), isFalse);
      expect(fresh.students.single.totalPoints, 80);
    });

    test('علامة اكتمال السجل تُحفظ وتعود بعد إعادة الفتح، ومعها الرصيد المشتق', () async {
      mark(ali, day1, 'present', 5);
      local.markPointsLedgerComplete();
      ali.totalPoints = 999; // عدّاد منحرف حُفظ على الجهاز
      await local.saveToStorage();
      await Future<void>.delayed(Duration.zero);

      final reopened = LocalStorageDataSource();
      await reopened.loadAllFromStorage();

      expect(reopened.pointsLedgerComplete, isTrue);
      expect(reopened.students.firstWhere((s) => s.id == ali.id).totalPoints, 5);
    });

    test('كل حركة تُرفع مع عمود الرصيد وحده، لا مع سجل الطالب كاملاً', () {
      queue.clearQueue();
      mark(ali, day1, 'present', 5);
      recitation.recordHadith(studentId: ali.id, hadithTitle: 'حديث', points: 10);
      students.adjustStudentPoints(studentId: ali.id, delta: -3);

      final studentWrites = queue.pendingQueue.where((i) => i['table'] == 'students').toList();
      expect(studentWrites, hasLength(3));
      for (final write in studentWrites) {
        expect(write['action'], 'patch');
        expect(write['id'], ali.id);
        // اسم الطالب وحلقته لا يُرسلان: نسخة قديمة على هذا الجهاز لا تكتب فوق تعديل جهاز آخر
        expect((write['data'] as Map).keys, ['total_points']);
      }
      expect((studentWrites.last['data'] as Map)['total_points'], 12);
      expect(queue.pendingQueue.where((i) => i['table'] == 'points_logs'), hasLength(3));
    });
  });

  group('الترتيب', () {
    List<String> order({DateTime? from, DateTime? to}) => [
          for (final row in competitions.getRankings(mosqueId: 'm1', startDate: from, endDate: to))
            '${(row['student'] as Student).fullName}:${row['score']}',
        ];

    test('صرف جائزة لا يُنزل الترتيب، والخصم اليدوي يُنزله', () {
      students.adjustStudentPoints(studentId: ali.id, delta: 100);
      students.adjustStudentPoints(studentId: omar.id, delta: 80);
      final bag = rewards.addReward(mosqueId: 'm1', title: 'حقيبة', pointsCost: 90);
      rewards.sellReward(studentId: ali.id, rewardId: bag.id, cashierName: 'ص');

      // رصيد علي 10 لكنه ما زال الأول بما اكتسبه
      expect(ali.totalPoints, 10);
      expect(order(), ['علي:100', 'عمر:80']);

      students.adjustStudentPoints(studentId: ali.id, delta: -8, reason: 'مخالفة');
      students.adjustStudentPoints(studentId: omar.id, delta: 15);
      expect(order(), ['عمر:95', 'علي:92']);
    });

    test('ترتيب الفترة: ما اكتُسب فيها فقط، بلا جوائز صُرفت فيها', () {
      PointsLog log(String id, Student s, int points, String category, DateTime at) =>
          PointsLog(id: id, studentId: s.id, points: points, reason: category, category: category, createdAt: at);
      local.pointsLogs.addAll([
        log('a', ali, 40, 'memorization', DateTime(2026, 9, 10)),
        log('b', ali, 30, 'attendance', DateTime(2026, 10, 3)),
        log('c', ali, -50, 'reward', DateTime(2026, 10, 4)),
        log('d', omar, 25, 'memorization', DateTime(2026, 10, 2)),
        log('e', omar, 60, 'hadith', DateTime(2026, 11, 1)),
      ]);

      expect(order(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31, 23, 59)), ['علي:30', 'عمر:25']);
      expect(order(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)), ['علي:40', 'عمر:0']);
      // حدّا الفترة داخلان فيها
      expect(order(from: DateTime(2026, 10, 3), to: DateTime(2026, 10, 3)), ['علي:30', 'عمر:0']);
      expect(order(), ['عمر:85', 'علي:70']);
    });

    test('المتساوون يثبت ترتيبهم بالاسم ولا يتبدل بين عرض وآخر', () {
      for (final name in ['زيد', 'بكر', 'أنس']) {
        final s = students.addStudent(mosqueId: 'm1', halaqaId: 'h1', fullName: name, gender: 'male', phone: '');
        students.adjustStudentPoints(studentId: s.id, delta: 10);
      }
      final first = order();
      for (var i = 0; i < 5; i++) {
        expect(order(), first);
      }
      expect(first.take(3), ['أنس:10', 'بكر:10', 'زيد:10']);
    });

    test('جهاز لم تصله الحركات بعد يرتّب بالرصيد مؤقتاً بدل أصفار', () {
      ali.totalPoints = 70;
      omar.totalPoints = 90;
      expect(local.pointsLedgerComplete, isFalse);
      expect(order(), ['عمر:90', 'علي:70']);

      local.pointsLedgerComplete = true;
      expect(order(), ['علي:0', 'عمر:0']);
    });

    test('ترتيب الدورة يحسب تسميع الدورة المحسوب فقط', () {
      local.intensiveCourses.add(IntensiveCourse(
        id: 'c1',
        mosqueId: 'm1',
        name: 'دورة صيفية',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 8, 1),
        studentIds: [ali.id, omar.id],
        createdAt: DateTime(2026, 6, 1),
      ));
      void recite(Student s, int points, {String? course, bool counted = true}) => recitation.recordRecitationBatch(
            studentId: s.id,
            courseId: course,
            items: [
              {'surahName': 'الملك', 'fromAyah': 1, 'toAyah': 5, 'juzNumber': 29},
            ],
            sessionType: 'review',
            points: points,
            countsTowardsStatistics: counted,
          );
      recite(ali, 30, course: 'c1');
      recite(ali, 99); // خارج الدورة
      recite(omar, 45, course: 'c1');
      recite(omar, 500, course: 'c1', counted: false);

      final rows = competitions.getRankings(mosqueId: 'm1', courseId: 'c1');
      expect([for (final r in rows) '${(r['student'] as Student).fullName}:${r['score']}'], ['عمر:45', 'علي:30']);
    });
  });

  group('سيناريو كامل', () {
    test('شهر من الحضور والتسميع والخصم والجوائز: الرصيد يطابق السجل بعد كل خطوة', () {
      final bag = rewards.addReward(mosqueId: 'm1', title: 'حقيبة', pointsCost: 60);
      for (var day = 1; day <= 20; day++) {
        final date = '2026-10-${day.toString().padLeft(2, '0')}';
        mark(ali, date, 'present', 5);
        if (day % 4 == 0) mark(ali, date, 'late', 2); // تصحيح الحالة
        if (day % 7 == 0) mark(ali, date, 'absent', 0);
        mark(omar, date, day.isEven ? 'present' : 'absent', day.isEven ? 5 : 0);
        if (day % 3 == 0) {
          recitation.recordRecitationBatch(
            studentId: ali.id,
            items: [
              {'surahName': 'يس', 'fromAyah': day, 'toAyah': day + 4, 'juzNumber': 23},
            ],
            sessionType: 'new_memorization',
            points: 20,
          );
        }
        if (day == 10) students.adjustStudentPoints(studentId: ali.id, delta: -15, reason: 'تأخر عن الواجب');
        if (day == 15) rewards.sellReward(studentId: ali.id, rewardId: bag.id, cashierName: 'ص');
        expectBalanced();
      }

      // حضور علي: 20 يوماً × 5، منها أيام 4,8,12,16,20 متأخر (2)، ويوما 7 و14 غياب (0)
      const aliAttendance = 13 * 5 + 5 * 2;
      const aliRecitation = 6 * 20;
      expect(ali.totalPoints, aliAttendance + aliRecitation - 15 - 60);
      expect(omar.totalPoints, 10 * 5);

      final rows = competitions.getRankings(mosqueId: 'm1');
      expect((rows.first['student'] as Student).id, ali.id);
      // الترتيب بالمكتسب: الجائزة لا تُطرح، والخصم اليدوي يُطرح
      expect(rows.first['score'], aliAttendance + aliRecitation - 15);
    });
  });
}
