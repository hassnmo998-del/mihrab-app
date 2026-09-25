import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/data/datasources/local_storage_datasource.dart';
import 'package:flutter_app/data/repositories/auth_session_repository_impl.dart';
import 'package:flutter_app/screens/student/widgets/student_multi_profile_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final service = DataService();
    service.disconnectRole('student');
    service.disconnectRole('sheikh');
    service.disconnectRole('mosque_admin');
    service.clearSession();
  });

  group('Student Multi-Profile Tests', () {
    test('Linking multiple students preserves all sessions without overwriting', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(
        name: 'جامع الهدى',
        address: 'دمشق',
        city: 'دمشق',
        gender: 'male',
      );
      final sheikh = service.addSheikh(mosque.id, 'الشيخ أحمد', null);
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة الفرقان', sheikhId: sheikh.id);

      final student1 = service.addStudent(
        fullName: 'أحمد المحمد',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0501111111',
        welcomePoints: 100,
      );

      final student2 = service.addStudent(
        fullName: 'عمر المحمد',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0502222222',
        welcomePoints: 150,
      );

      // Verify no student session initially
      expect(service.hasRole('student'), isFalse);
      expect(service.getStudentSessions(), isEmpty);

      // Link first son (أحمد)
      final session1 = ActiveSession(
        role: 'student',
        code: student1.code,
        name: student1.fullName,
        studentId: student1.id,
        halaqaId: student1.halaqaId,
        mosqueId: student1.mosqueId,
      );
      service.addStudentSession(session1);

      expect(service.hasRole('student'), isTrue);
      expect(service.getStudentSessions().length, equals(1));
      expect(service.getActiveStudentSession()?.studentId, equals(student1.id));
      expect(service.getActiveStudentSession()?.name, equals('أحمد المحمد'));

      // Link second son (عمر)
      final session2 = ActiveSession(
        role: 'student',
        code: student2.code,
        name: student2.fullName,
        studentId: student2.id,
        halaqaId: student2.halaqaId,
        mosqueId: student2.mosqueId,
      );
      service.addStudentSession(session2);

      // Verify BOTH sessions coexist in memory and storage
      final sessions = service.getStudentSessions();
      expect(sessions.length, equals(2));
      expect(sessions.any((s) => s.studentId == student1.id), isTrue);
      expect(sessions.any((s) => s.studentId == student2.id), isTrue);

      // Newly added student becomes active by default
      expect(service.getActiveStudentSession()?.studentId, equals(student2.id));
      expect(service.getActiveStudentSession()?.name, equals('عمر المحمد'));

      // Switch active student back to first son (أحمد)
      service.setActiveStudent(student1.id);
      expect(service.getActiveStudentSession()?.studentId, equals(student1.id));
      expect(service.getActiveStudentSession()?.name, equals('أحمد المحمد'));

      // Switch back to second son (عمر)
      service.setActiveStudent(student2.id);
      expect(service.getActiveStudentSession()?.studentId, equals(student2.id));
      expect(service.getActiveStudentSession()?.name, equals('عمر المحمد'));
    });

    test('Unlinking a student updates remaining active profiles gracefully', () async {
      final service = DataService();
      await service.init();

      final s1 = ActiveSession(role: 'student', code: 'STD-1', name: 'أحمد', studentId: 'id-1');
      final s2 = ActiveSession(role: 'student', code: 'STD-2', name: 'عمر', studentId: 'id-2');

      service.addStudentSession(s1);
      service.addStudentSession(s2);
      expect(service.getStudentSessions().length, equals(2));
      expect(service.getActiveStudentSession()?.studentId, equals('id-2'));

      // Remove the currently active student (عمر)
      service.removeStudentSession('id-2');

      // Remaining session is أحمد and becomes active
      expect(service.getStudentSessions().length, equals(1));
      expect(service.getActiveStudentSession()?.studentId, equals('id-1'));
      expect(service.getActiveStudentSession()?.name, equals('أحمد'));
      expect(service.hasRole('student'), isTrue);

      // Remove the last remaining student
      service.removeStudentSession('id-1');
      expect(service.getStudentSessions(), isEmpty);
      expect(service.getActiveStudentSession(), isNull);
      expect(service.hasRole('student'), isFalse);
    });

    test('Duplicate addition of the same student updates rather than duplicates', () async {
      final service = DataService();
      await service.init();

      final s1 = ActiveSession(role: 'student', code: 'STD-1', name: 'أحمد قديم', studentId: 'id-1');
      service.addStudentSession(s1);
      expect(service.getStudentSessions().length, equals(1));

      // Re-add same student with updated name
      final s1Updated = ActiveSession(role: 'student', code: 'STD-1', name: 'أحمد جديد', studentId: 'id-1');
      service.addStudentSession(s1Updated);

      expect(service.getStudentSessions().length, equals(1));
      expect(service.getActiveStudentSession()?.name, equals('أحمد جديد'));
    });

    test('Persistence across service reload retains all students and active selection', () async {
      final s1 = ActiveSession(role: 'student', code: 'STD-A', name: 'الطالب الأول', studentId: 'std-a');
      final s2 = ActiveSession(role: 'student', code: 'STD-B', name: 'الطالب الثاني', studentId: 'std-b');

      final local1 = LocalStorageDataSource();
      final repo1 = AuthSessionRepositoryImpl(local1);

      repo1.addStudentSession(s1);
      repo1.addStudentSession(s2);
      repo1.setActiveStudent('std-a');

      // Now create a fresh second instance simulating app relaunch
      final local2 = LocalStorageDataSource();
      await local2.loadAllFromStorage();
      final repo2 = AuthSessionRepositoryImpl(local2);

      final reloaded = repo2.getStudentSessions();
      expect(reloaded.length, equals(2));
      expect(repo2.getActiveStudentSession()?.studentId, equals('std-a'));
      expect(repo2.getActiveStudentSession()?.name, equals('الطالب الأول'));
    });

    test('Data isolation: Each student retains their independent points and logs', () async {
      final service = DataService();
      await service.init();

      final mosque = service.addMosque(name: 'المسجد الأموي', address: 'دمشق', city: 'دمشق', gender: 'male');
      final halaqa = service.addHalaqa(mosqueId: mosque.id, name: 'حلقة الإتقان');

      final student1 = service.addStudent(
        fullName: 'سامي',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0501111111',
        welcomePoints: 50,
      );

      final student2 = service.addStudent(
        fullName: 'ياسين',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0502222222',
        welcomePoints: 200,
      );

      final s1 = ActiveSession(role: 'student', code: student1.code, name: student1.fullName, studentId: student1.id);
      final s2 = ActiveSession(role: 'student', code: student2.code, name: student2.fullName, studentId: student2.id);
      service.addStudentSession(s1);
      service.addStudentSession(s2);

      final logs1 = service.getStudentPointsLog(student1.id);
      final logs2 = service.getStudentPointsLog(student2.id);

      expect(logs1.length, equals(1));
      expect(logs1.first.points, equals(50));

      expect(logs2.length, equals(1));
      expect(logs2.first.points, equals(200));

      // Adjust points for student 1 only
      service.adjustStudentPoints(studentId: student1.id, delta: 30, reason: 'حفظ سورة الكهف');

      final updatedSt1 = service.getStudents().firstWhere((s) => s.id == student1.id);
      final updatedSt2 = service.getStudents().firstWhere((s) => s.id == student2.id);

      expect(updatedSt1.totalPoints, equals(80));
      expect(updatedSt2.totalPoints, equals(200));
    });

    testWidgets('StudentMultiProfileBar widget renders and handles profile switching', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final s1 = ActiveSession(role: 'student', code: 'STD-1', name: 'أحمد', studentId: 'id-1');
      final s2 = ActiveSession(role: 'student', code: 'STD-2', name: 'عمر', studentId: 'id-2');

      String? switchedId;
      bool addTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentMultiProfileBar(
              studentSessions: [s1, s2],
              activeSession: s1,
              students: const [],
              mosques: const [],
              halaqat: const [],
              isDark: false,
              onSelectStudent: (id) => switchedId = id,
              onAddStudent: () => addTapped = true,
              onUnlinkStudent: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title with count, and student names are rendered
      expect(find.text('أبنائي في الحلقات (2)'), findsOneWidget);
      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('عمر'), findsOneWidget);
      expect(find.text('المعروض'), findsOneWidget); // For active student s1

      // Tap on the inactive student (عمر)
      await tester.tap(find.text('عمر'));
      await tester.pumpAndSettle();

      expect(switchedId, equals('id-2'));

      // Tap on the "إضافة ابن" button
      await tester.ensureVisible(find.text('إضافة ابن'));
      await tester.tap(find.text('إضافة ابن'));
      await tester.pumpAndSettle();

      expect(addTapped, isTrue);
    });
  });
}
