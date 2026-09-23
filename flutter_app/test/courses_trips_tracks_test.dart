import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Intensive Courses, Smart Timing & Custom Tracks Tests', () {
    test('Smart timing detection identifies course, regular halaqa and custom modes with ±30m window', () async {
      final data = DataService();
      await data.init();

      // Create a mosque, halaqa, and course
      final mosque = data.addMosque(name: 'جامع النور', address: 'وسط البلد', city: 'دمشق', gender: 'male');
      final sheikh = data.addSheikh(mosque.id, 'الشيخ سعيد', null);
      final halaqa = data.addHalaqa(
        mosqueId: mosque.id,
        name: 'حلقة الإتقان',
        sheikhId: sheikh.id,
        daysOfWeek: [1, 3], // Mon, Wed
        timingType: 'custom_time',
        customTime: '17:00',
      );
      final student = data.addStudent(
        fullName: 'أحمد الحلبي',
        mosqueId: mosque.id,
        halaqaId: halaqa.id,
        gender: 'male',
        phone: '0500000000',
      );

      // Add course on Saturday (6) from 16:00 to 18:00
      final now = DateTime.now();
      final course = data.addIntensiveCourse(
        mosqueId: mosque.id,
        name: 'دورة الهمة المكثفة',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 10)),
        studentIds: [student.id],
        daysOfWeek: [6], // Saturday
        startTime: '16:00',
        endTime: '18:00',
        countsTowardsQuranProgress: false,
      );

      // 1. Time at Saturday 15:35 (25 mins before course start -> within ±30m window)
      DateTime satDate = now;
      while (satDate.weekday != 6) {
        satDate = satDate.add(const Duration(days: 1));
      }
      final courseTime = DateTime(satDate.year, satDate.month, satDate.day, 15, 35);
      final courseDetection = data.detectSessionTimingMode(
        halaqaId: halaqa.id,
        studentId: student.id,
        currentTime: courseTime,
      );
      expect(courseDetection['mode'], equals('course'));
      expect(courseDetection['courseId'], equals(course.id));
      expect(courseDetection['countsTowardsQuran'], isFalse);

      // 2. Time at regular halaqa day (Monday=1) at 17:15 (within ±30m of 17:00)
      DateTime monDate = now;
      while (monDate.weekday != 1) {
        monDate = monDate.add(const Duration(days: 1));
      }
      final halaqaTime = DateTime(monDate.year, monDate.month, monDate.day, 17, 15);
      final halaqaDetection = data.detectSessionTimingMode(
        halaqaId: halaqa.id,
        studentId: student.id,
        currentTime: halaqaTime,
      );
      expect(halaqaDetection['mode'], equals('normal'));
      expect(halaqaDetection['countsTowardsQuran'], isTrue);

      // 3. Time completely outside (Sunday=7 at 23:00)
      DateTime sunDate = now;
      while (sunDate.weekday != 7) {
        sunDate = sunDate.add(const Duration(days: 1));
      }
      final customTime = DateTime(sunDate.year, sunDate.month, sunDate.day, 23, 0);
      final customDetection = data.detectSessionTimingMode(
        halaqaId: halaqa.id,
        studentId: student.id,
        currentTime: customTime,
      );
      expect(customDetection['mode'], equals('custom'));
    });

    test('Trips module filters target students and manages required baggage items', () async {
      final data = DataService();
      await data.init();

      final mosque = data.addMosque(name: 'جامع الإيمان', address: 'الميدان', city: 'دمشق', gender: 'male');
      final halaqa1 = data.addHalaqa(mosqueId: mosque.id, name: 'حلقة أ');
      final halaqa2 = data.addHalaqa(mosqueId: mosque.id, name: 'حلقة ب');

      final s1 = data.addStudent(fullName: 'بلال', mosqueId: mosque.id, halaqaId: halaqa1.id, gender: 'male', phone: '0500000000');
      final s2 = data.addStudent(fullName: 'ياسر', mosqueId: mosque.id, halaqaId: halaqa2.id, gender: 'male', phone: '0500000000');

      // Trip targeted specifically at halaqa1
      final trip = data.addTrip(
        mosqueId: mosque.id,
        title: 'رحلة حديقة تشرين',
        destination: 'حديقة تشرين',
        tripDate: DateTime.now().add(const Duration(days: 5)),
        requiredItems: 'حقيبة ظهر، مياه، مصحف',
        targetHalaqaIds: [halaqa1.id],
      );

      expect(trip.requiredItems, contains('مياه'));
      expect(trip.isStudentTargeted(s1), isTrue);
      expect(trip.isStudentTargeted(s2), isFalse);

      final s1Trips = data.getTrips(studentId: s1.id);
      expect(s1Trips.any((t) => t.id == trip.id), isTrue);

      final s2Trips = data.getTrips(studentId: s2.id);
      expect(s2Trips.any((t) => t.id == trip.id), isFalse);
    });

    test('Custom recitation tracks record progress and calculate correct unique completion', () async {
      final data = DataService();
      await data.init();

      final mosque = data.addMosque(name: 'جامع الصالحين', address: 'الصالحية', city: 'دمشق', gender: 'male');
      final halaqa = data.addHalaqa(mosqueId: mosque.id, name: 'حلقة الحديث');
      final student = data.addStudent(fullName: 'حمزة', mosqueId: mosque.id, halaqaId: halaqa.id, gender: 'male', phone: '0500000000');

      // Add Arbaeen track (42 hadiths)
      final track = data.addRecitationTrack(
        mosqueId: mosque.id,
        name: 'الأربعون النووية',
        category: 'hadith',
        unitLabel: 'حديث',
        totalUnits: 42,
        pointsPerUnit: 5,
      );

      // Recite Hadiths 1 to 10
      data.recordSubjectRecitation(
        trackId: track.id,
        trackName: track.name,
        studentId: student.id,
        halaqaId: halaqa.id,
        fromUnit: 1,
        toUnit: 10,
        pointsEarned: 50,
      );

      var progress = data.getStudentSubjectProgress(student.id, track.id);
      expect(progress['uniqueUnitsCount'], equals(10));
      expect(progress['totalUnits'], equals(42));
      expect(progress['progress'], closeTo(10 / 42, 0.001));

      // Reciting overlapping Hadiths 5 to 15: unique units should be 1..15 = 15 units (no duplication)
      data.recordSubjectRecitation(
        trackId: track.id,
        trackName: track.name,
        studentId: student.id,
        halaqaId: halaqa.id,
        fromUnit: 5,
        toUnit: 15,
        pointsEarned: 55,
      );

      progress = data.getStudentSubjectProgress(student.id, track.id);
      expect(progress['uniqueUnitsCount'], equals(15));
      expect(progress['progress'], closeTo(15 / 42, 0.001));
    });
  });
}
