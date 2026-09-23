import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/models/models.dart';

/// Verifies the manual points mode (minus/plus) used by the admin students page
/// and the halaqa management (sheikh) students page: local mutation, points log
/// entry with `manual` category, clamping at zero, and local persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(DataService, Student)> seed({int welcomePoints = 50}) async {
    final service = DataService();
    await service.init();
    final mosque = service.addMosque(
      name: 'جامع الهدى',
      address: 'الميدان',
      city: 'دمشق',
      gender: 'male',
    );
    final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة عاصم');
    final student = service.addStudent(
      mosqueId: mosque.id,
      halaqaId: halaqa.id,
      fullName: 'زيد بن ثابت',
      gender: 'male',
      phone: '0500000000',
      welcomePoints: welcomePoints,
    );
    return (service, student);
  }

  group('Manual points adjustment (± buttons)', () {
    test('Positive delta increments balance and logs a manual entry', () async {
      final (service, student) = await seed(welcomePoints: 50);

      final result = service.adjustStudentPoints(
        studentId: student.id,
        delta: 15,
        reason: 'حسن خلق وانتظام',
        actorName: 'الشيخ عمر',
      );

      expect(result['success'], isTrue);
      expect(result['applied'], 15);
      expect(result['previousTotal'], 50);
      expect(result['total'], 65);
      expect(result['clamped'], isFalse);

      final updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, 65);

      final logs = service.getStudentPointsLog(student.id);
      final manualLogs = logs.where((l) => l.category == 'manual').toList();
      // نقاط الترحيب تُسجَّل أيضاً بتصنيف manual، فنبحث عن حركة الإضافة اليدوية
      final addLog = manualLogs.firstWhere((l) => l.points == 15);
      expect(addLog.reason, contains('حسن خلق وانتظام'));
      expect(addLog.reason, contains('الشيخ عمر'));
      expect(addLog.studentId, student.id);
    });

    test('Negative delta decrements balance and logs a negative entry', () async {
      final (service, student) = await seed(welcomePoints: 50);

      final result = service.adjustStudentPoints(studentId: student.id, delta: -20);

      expect(result['success'], isTrue);
      expect(result['applied'], -20);
      expect(result['total'], 30);
      expect(result['clamped'], isFalse);

      final updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, 30);

      final deductLog = service
          .getStudentPointsLog(student.id)
          .firstWhere((l) => l.points == -20);
      expect(deductLog.category, 'manual');
      expect(deductLog.reason, contains('خصم نقاط يدوي'));
    });

    test('Deduction beyond the balance clamps at zero instead of going negative',
        () async {
      final (service, student) = await seed(welcomePoints: 10);

      final result = service.adjustStudentPoints(studentId: student.id, delta: -500);

      expect(result['success'], isTrue);
      expect(result['applied'], -10);
      expect(result['requested'], -500);
      expect(result['total'], 0);
      expect(result['clamped'], isTrue);

      final updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, 0);
    });

    test('Deducting from a zero balance is rejected without a log', () async {
      final (service, student) = await seed(welcomePoints: 0);

      final logsBefore = service.getStudentPointsLog(student.id).length;
      final result = service.adjustStudentPoints(studentId: student.id, delta: -5);

      expect(result['success'], isFalse);
      expect(result['applied'], 0);
      expect(service.getStudentPointsLog(student.id).length, logsBefore);
      final updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, 0);
    });

    test('Zero delta and unknown student are rejected safely', () async {
      final (service, student) = await seed(welcomePoints: 40);

      final zero = service.adjustStudentPoints(studentId: student.id, delta: 0);
      expect(zero['success'], isFalse);

      final missing =
          service.adjustStudentPoints(studentId: 'std-does-not-exist', delta: 10);
      expect(missing['success'], isFalse);

      final updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, 40);
    });

    test('Repeated rapid adjustments accumulate with unique log ids', () async {
      final (service, student) = await seed(welcomePoints: 0);

      for (var i = 0; i < 8; i++) {
        service.adjustStudentPoints(studentId: student.id, delta: 5);
      }

      final updated = service.getStudents().firstWhere((s) => s.id == student.id);
      expect(updated.totalPoints, 40);

      final logs = service
          .getStudentPointsLog(student.id)
          .where((l) => l.points == 5)
          .toList();
      expect(logs.length, 8);
      expect(logs.map((l) => l.id).toSet().length, 8);
    });

    test('Adjustment survives a local reload (offline-first persistence)',
        () async {
      final (service, student) = await seed(welcomePoints: 20);

      service.adjustStudentPoints(
        studentId: student.id,
        delta: 30,
        reason: 'مسابقة الحلقة',
      );
      // السماح لعملية الحفظ غير المتزامنة بالاكتمال قبل إعادة التحميل
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reloaded = DataService();
      await reloaded.init();

      final persisted =
          reloaded.getStudents().firstWhere((s) => s.id == student.id);
      expect(persisted.totalPoints, 50);

      final persistedLog = reloaded
          .getStudentPointsLog(student.id)
          .firstWhere((l) => l.points == 30);
      expect(persistedLog.category, 'manual');
      expect(persistedLog.reason, contains('مسابقة الحلقة'));
    });

    test('Points log round-trips through JSON with a negative value', () {
      final log = PointsLog(
        id: 'pts-1',
        studentId: 'std-1',
        points: -25,
        reason: 'خصم نقاط يدوي — بواسطة: إدارة جامع الهدى',
        category: 'manual',
        createdAt: DateTime(2026, 3, 14, 9, 30),
      );

      final revived = PointsLog.fromJson(log.toJson());
      expect(revived.points, -25);
      expect(revived.category, 'manual');
      expect(revived.reason, log.reason);
      expect(revived.createdAt, log.createdAt);
    });
  });
}
