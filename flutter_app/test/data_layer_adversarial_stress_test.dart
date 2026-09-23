import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/data/datasources/datasources.dart';
import 'package:flutter_app/data/repositories/repositories.dart';
import 'package:flutter_app/data/quran_data.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/models/models.dart';

/// Test mock to simulate Supabase network failures during sync queue processing
class MockFailingRemoteDataSource extends SupabaseRemoteDataSource {
  int failAfterCount;
  int operationCount = 0;
  final List<Map<String, dynamic>> successfulUpserts = [];
  final List<String> successfulDeletes = [];

  MockFailingRemoteDataSource({this.failAfterCount = 999999});

  @override
  SupabaseClient? get client => Supabase.instance.client;

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    operationCount++;
    if (operationCount > failAfterCount) {
      throw Exception('Simulated network failure on upsert #$operationCount');
    }
    successfulUpserts.add({'table': table, 'data': data});
  }

  @override
  Future<void> delete(
    String table, {
    required String matchingColumn,
    required dynamic matchingValue,
  }) async {
    operationCount++;
    if (operationCount > failAfterCount) {
      throw Exception('Simulated network failure on delete #$operationCount');
    }
    successfulDeletes.add('$table:$matchingValue');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final ds = SupabaseRemoteDataSource();
    await ds.initialize();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // 1. OfflineSyncQueueManager Adversarial Stress Suite
  // =========================================================================
  group('1. OfflineSyncQueueManager Adversarial Stress Suite', () {
    test('High-volume FIFO enqueueing preserves exact order and payload metadata', () async {
      final queueManager = OfflineSyncQueueManager();
      await queueManager.loadQueue();
      expect(queueManager.pendingQueue, isEmpty);

      // Rapidly enqueue 100 mutations
      for (int i = 0; i < 100; i++) {
        queueManager.queueSync(
          table: 'test_table',
          action: i % 2 == 0 ? 'upsert' : 'delete',
          data: {'index': i, 'name': 'item_$i'},
          id: i % 2 == 1 ? 'id_$i' : null,
        );
      }

      expect(queueManager.pendingQueue.length, equals(100));
      for (int i = 0; i < 100; i++) {
        final item = queueManager.pendingQueue[i];
        expect(item['table'], equals('test_table'));
        expect(item['action'], equals(i % 2 == 0 ? 'upsert' : 'delete'));
        expect(item['data']['index'], equals(i));
        expect(item['data']['name'], equals('item_$i'));
        expect(item['queued_at'], isNotNull);
        if (i % 2 == 1) {
          expect(item['id'], equals('id_$i'));
        }
      }
    });

    test('Queue persistence round-trip survives cold-start and handles corrupted storage', () async {
      final q1 = OfflineSyncQueueManager();
      q1.queueSync(
        table: 'students',
        action: 'upsert',
        data: {'id': 'st-1', 'name': 'سلمان'},
      );
      q1.queueSync(
        table: 'attendance',
        action: 'delete',
        data: {},
        id: 'att-99',
      );
      await q1.saveQueue();

      // Cold start with second instance
      final q2 = OfflineSyncQueueManager();
      await q2.loadQueue();
      expect(q2.pendingQueue.length, equals(2));
      expect(q2.pendingQueue.first['table'], equals('students'));
      expect(q2.pendingQueue.last['id'], equals('att-99'));

      // Adversarial test: Corrupt SharedPreferences with unparseable JSON
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(OfflineSyncQueueManager.queueKey, '{{INVALID_JSON_CORRUPTED');

      final q3 = OfflineSyncQueueManager();
      // Must not throw uncaught error
      await q3.loadQueue();
      expect(q3.pendingQueue, isEmpty);

      // Adversarial test: Store non-map primitives in JSON array
      await prefs.setString(
        OfflineSyncQueueManager.queueKey,
        jsonEncode([123, 'random_string', null, false, {'table': 'valid_table', 'action': 'upsert', 'data': {}}]),
      );
      final q4 = OfflineSyncQueueManager();
      await q4.loadQueue();
      expect(q4.pendingQueue.length, equals(1));
      expect(q4.pendingQueue.first['table'], equals('valid_table'));
    });

    test('Network failure during sync stops dispatch, preserves unprocessed items, and resets flag', () async {
      final queueManager = OfflineSyncQueueManager();
      for (int i = 1; i <= 6; i++) {
        queueManager.queueSync(
          table: 'records',
          action: 'upsert',
          data: {'seq': i},
        );
      }
      expect(queueManager.pendingQueue.length, equals(6));

      // Mock that fails after 2 successful operations
      final mockRemote = MockFailingRemoteDataSource(failAfterCount: 2);
      await queueManager.processQueue(mockRemote);

      // First 2 should be processed, remaining 4 preserved in FIFO order
      expect(mockRemote.successfulUpserts.length, equals(2));
      expect(mockRemote.successfulUpserts[0]['data']['seq'], equals(1));
      expect(mockRemote.successfulUpserts[1]['data']['seq'], equals(2));
      expect(queueManager.isProcessingQueue, isFalse);
      expect(queueManager.pendingQueue.length, equals(4));
      expect(queueManager.pendingQueue.first['data']['seq'], equals(3));
      expect(queueManager.pendingQueue.last['data']['seq'], equals(6));

      // Subsequent call when network recovers
      final recoveryRemote = MockFailingRemoteDataSource(failAfterCount: 100);
      await queueManager.processQueue(recoveryRemote);
      expect(recoveryRemote.successfulUpserts.length, equals(4));
      expect(queueManager.pendingQueue, isEmpty);
      expect(queueManager.isProcessingQueue, isFalse);
    });

    test('Queue processing handles delete actions with matchingColumn and matchingValue', () async {
      final queueManager = OfflineSyncQueueManager();
      queueManager.queueSync(
        table: 'trips',
        action: 'delete',
        data: {},
        id: 'trip-42',
      );

      final mockRemote = MockFailingRemoteDataSource();
      await queueManager.processQueue(mockRemote);
      expect(mockRemote.successfulDeletes, contains('trips:trip-42'));
      expect(queueManager.pendingQueue, isEmpty);
    });
  });

  // =========================================================================
  // 2. LocalStorageDataSource In-Memory & Persistence Stress Suite
  // =========================================================================
  group('2. LocalStorageDataSource In-Memory & Persistence Stress Suite', () {
    test('17 collections persistence round-trip across SharedPreferences', () async {
      final ds = LocalStorageDataSource();

      // Populate sample items across collections
      ds.isDarkMode = true;
      ds.currentSession = ActiveSession(
        role: 'mosque_admin',
        code: 'ADM-99',
        name: 'أدمن المسجد',
        mosqueId: 'm-1',
      );
      ds.savedSessions.add(ds.currentSession!);
      ds.savedSessions.add(ActiveSession(
        role: 'student',
        code: 'STU-01',
        name: 'طالب مجتهد',
        mosqueId: 'm-1',
      ));

      ds.mosques.add(Mosque(id: 'm-1', name: 'جامع النور', address: 'دمشق', city: 'دمشق', gender: 'male', accessCode: 'MSQ-1'));
      ds.sheikhs.add(Sheikh(id: 'sh-1', mosqueId: 'm-1', fullName: 'الشيخ حسن', phone: '0912345678', code: 'SHK-1'));
      ds.halaqat.add(Halaqa(id: 'h-1', mosqueId: 'm-1', name: 'حلقة زيد'));
      ds.students.add(Student(id: 'st-1', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'بلال', gender: 'male', phone: '0500000000', code: 'STU-1'));
      ds.communityEvents.add(CommunityEvent(id: 'ev-1', mosqueId: 'm-1', title: 'محاضرة إيمانية', description: 'شرح العقيدة', eventType: 'general', targetAudience: 'all', eventDateTime: DateTime.now(), organizerType: 'sheikh', organizerName: 'الشيخ حسن'));
      ds.pointsLogs.add(PointsLog(id: 'pt-1', studentId: 'st-1', points: 10, reason: 'حفظ', category: 'memorization', createdAt: DateTime.now()));
      ds.competitions.add(Competition(id: 'cp-1', mosqueId: 'm-1', title: 'مسابقة رمضان', description: 'حفظ سورة البقرة', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 10)), genderBranch: 'male'));
      ds.memorizationRecords.add(MemorizationRecord(id: 'mr-1', studentId: 'st-1', surahName: 'الفاتحة', fromAyah: 1, toAyah: 7, juzNumber: 1, sessionType: 'new_memorization', qualityRating: 'excellent', pointsEarned: 10, recordedAt: DateTime.now()));
      ds.attendanceRecords.add(AttendanceRecord(id: 'at-1', studentId: 'st-1', halaqaId: 'h-1', sessionDate: '2026-09-12', status: 'present'));
      ds.messages.add(AppMessage(id: 'msg-1', studentId: 'st-1', halaqaId: 'h-1', senderType: 'sheikh', senderName: 'الشيخ حسن', content: 'موعد الحلقة', createdAt: DateTime.now()));
      ds.rewards.add(Reward(id: 'rw-1', mosqueId: 'm-1', title: 'مصحف مذهب', pointsCost: 50, createdAt: DateTime.now()));
      ds.redemptions.add(RewardRedemption(id: 'rd-1', studentId: 'st-1', studentName: 'بلال', mosqueId: 'm-1', mosqueName: 'جامع النور', rewardId: 'rw-1', rewardTitle: 'مصحف مذهب', pointsSpent: 50, redemptionCode: 'VCH-1234', status: 'pending', redeemedAt: DateTime.now()));
      ds.intensiveCourses.add(IntensiveCourse(id: 'ic-1', mosqueId: 'm-1', name: 'دورة صيفية', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 30)), createdAt: DateTime.now()));
      ds.trips.add(Trip(id: 'tr-1', mosqueId: 'm-1', title: 'رحلة حديقة تشرين', destination: 'دمشق', tripDate: DateTime.now().add(const Duration(days: 5)), meetingTime: '08:00', createdAt: DateTime.now()));
      ds.recitationTracks.add(RecitationTrack(id: 'rt-1', mosqueId: 'm-1', name: 'الأربعون النووية', totalUnits: 42, createdAt: DateTime.now()));
      ds.subjectRecitationRecords.add(SubjectRecitationRecord(id: 'sr-1', studentId: 'st-1', trackId: 'rt-1', trackName: 'الأربعون النووية', fromUnit: 1, toUnit: 5, unitsCount: 5, pointsEarned: 10, recordedAt: DateTime.now()));

      // Save to SharedPreferences
      await ds.saveToStorage();
      await ds.saveThemeMode();

      // Cold reload into brand new LocalStorageDataSource
      final dsLoaded = LocalStorageDataSource();
      await dsLoaded.loadAllFromStorage();

      expect(dsLoaded.isDarkMode, isTrue);
      expect(dsLoaded.currentSession?.code, equals('ADM-99'));
      expect(dsLoaded.savedSessions.length, equals(2));
      expect(dsLoaded.mosques.length, equals(1));
      expect(dsLoaded.sheikhs.length, equals(1));
      expect(dsLoaded.halaqat.length, equals(1));
      expect(dsLoaded.students.length, equals(1));
      expect(dsLoaded.communityEvents.length, equals(1));
      expect(dsLoaded.pointsLogs.length, equals(1));
      expect(dsLoaded.competitions.length, equals(1));
      expect(dsLoaded.memorizationRecords.length, equals(1));
      expect(dsLoaded.attendanceRecords.length, equals(1));
      expect(dsLoaded.messages.length, equals(1));
      expect(dsLoaded.rewards.length, equals(1));
      expect(dsLoaded.redemptions.length, equals(1));
      expect(dsLoaded.intensiveCourses.length, equals(1));
      expect(dsLoaded.trips.length, equals(1));
      expect(dsLoaded.recitationTracks.length, equals(1));
      expect(dsLoaded.subjectRecitationRecords.length, equals(1));
    });

    test('super_admin sessions are automatically stripped during session load', () async {
      final prefs = await SharedPreferences.getInstance();
      final sessions = [
        {'role': 'super_admin', 'code': 'SUPER-1', 'name': 'مشرف عام'},
        {'role': 'sheikh', 'code': 'SHK-55', 'name': 'شيخ مقرئ'},
      ];
      await prefs.setString('saved_sessions', jsonEncode(sessions));
      await prefs.setString('current_session_code', 'SHK-55');

      final ds = LocalStorageDataSource();
      await ds.loadAllFromStorage();

      expect(ds.savedSessions.any((s) => s.role == 'super_admin'), isFalse);
      expect(ds.savedSessions.length, equals(1));
      expect(ds.savedSessions.first.code, equals('SHK-55'));
      expect(ds.currentSession?.code, equals('SHK-55'));
    });

    test('ID generator produces strictly unique IDs in rapid high-throughput generation', () {
      final ids = <String>{};
      for (int i = 0; i < 1000; i++) {
        final id = LocalStorageDataSource.genId('test');
        expect(ids.contains(id), isFalse, reason: 'Collision detected for ID: $id at loop $i');
        ids.add(id);
      }
      expect(ids.length, equals(1000));
    });
  });

  // =========================================================================
  // 3. Authentic Quran Progress Deduplication across 30 Ajza Stress Suite
  // =========================================================================
  group('3. Authentic Quran Progress Deduplication across 30 Ajza Stress Suite', () {
    test('Quran metadata integrity: 30 Ajza exact 6,236 Ayahs, 0 overlaps, 114 Surahs', () {
      final allKeys = <String>{};
      int totalBoundaryAyahs = 0;

      for (int juz = 1; juz <= 30; juz++) {
        final juzKeys = getAllAyahKeysInJuz(juz);
        expect(juzKeys, isNotEmpty, reason: 'Juz $juz has no Ayahs');

        // Check for overlaps with prior Ajza
        final overlap = allKeys.intersection(juzKeys);
        expect(overlap, isEmpty, reason: 'Overlap found in Juz $juz with previous Ajza: $overlap');

        allKeys.addAll(juzKeys);
        totalBoundaryAyahs += juzKeys.length;
      }

      expect(totalBoundaryAyahs, equals(totalQuranAyahs));
      expect(allKeys.length, equals(6236));

      // Verify all 114 Surahs exist
      expect(quranSurahsInfo.length, equals(114));
      for (final surah in quranSurahsInfo) {
        expect(surah.number, inInclusiveRange(1, 114));
        expect(surah.ayahCount, greaterThan(0));
        // Verify first and last ayah of each Surah are present in the allKeys set
        expect(allKeys, contains('${surah.number}:1'));
        expect(allKeys, contains('${surah.number}:${surah.ayahCount}'));
      }
    });

    test('Deduplication prevents artificial inflation across repeated sessions (new, review, test)', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationRepositoryImpl(localDs, syncQueue);

      localDs.students.add(Student(id: 'st-dedup', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'زيد بن ثابت', gender: 'male', phone: '0500000000', code: 'Z-1'));

      // Student recites Surah Al-Fatihah (7 Ayahs) 10 times across different session types
      for (int i = 0; i < 10; i++) {
        final type = (i % 3 == 0) ? 'new_memorization' : (i % 3 == 1 ? 'review' : 'test');
        repo.recordMemorization(
          studentId: 'st-dedup',
          surahName: 'الفاتحة',
          fromAyah: 1,
          toAyah: 7,
          juzNumber: 1,
          sessionType: type,
          points: 10,
        );
      }

      // 10 records recorded in DB
      expect(localDs.memorizationRecords.length, equals(10));
      // BUT unique memorized keys MUST strictly be 7, NOT 70!
      final keys = repo.getStudentMemorizedAyahKeys('st-dedup');
      expect(keys.length, equals(7));

      final juz1Prog = repo.getStudentJuzProgress('st-dedup', 1);
      expect(juz1Prog['memorizedAyahs'], equals(7));
      expect(juz1Prog['isCompleted'], isFalse); // Juz 1 has 148 ayahs
    });

    test('Partial overlapping Ayah ranges correctly union without gaps or double-counting', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationRepositoryImpl(localDs, syncQueue);

      localDs.students.add(Student(id: 'st-overlap', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'علي', gender: 'male', phone: '0500000000', code: 'A-1'));

      // Session 1: Ayah 1 to 10
      repo.recordMemorization(studentId: 'st-overlap', surahName: 'البقرة', fromAyah: 1, toAyah: 10, juzNumber: 1, sessionType: 'new_memorization', points: 10);
      // Session 2: Ayah 5 to 15 (overlapping 5-10)
      repo.recordMemorization(studentId: 'st-overlap', surahName: 'البقرة', fromAyah: 5, toAyah: 15, juzNumber: 1, sessionType: 'new_memorization', points: 10);
      // Session 3: Ayah 12 to 20 (overlapping 12-15)
      repo.recordMemorization(studentId: 'st-overlap', surahName: 'البقرة', fromAyah: 12, toAyah: 20, juzNumber: 1, sessionType: 'new_memorization', points: 10);

      // Unique memorized should be exactly 20 Ayahs (1 through 20)
      final keys = repo.getStudentMemorizedAyahKeys('st-overlap');
      expect(keys.length, equals(20));
      for (int i = 1; i <= 20; i++) {
        expect(keys, contains('2:$i'));
      }
    });

    test('Cross-Juz boundary mapping accurately isolates Ayahs between Juz 1 and Juz 2', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationRepositoryImpl(localDs, syncQueue);

      localDs.students.add(Student(id: 'st-boundary', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'عمر', gender: 'male', phone: '0500000000', code: 'O-1'));

      // Surah Al-Baqarah Ayah 141 is the last Ayah in Juz 1
      // Surah Al-Baqarah Ayah 142 is the first Ayah in Juz 2
      repo.recordMemorization(studentId: 'st-boundary', surahName: 'البقرة', fromAyah: 140, toAyah: 141, juzNumber: 1, sessionType: 'new_memorization', points: 10);
      repo.recordMemorization(studentId: 'st-boundary', surahName: 'البقرة', fromAyah: 142, toAyah: 145, juzNumber: 2, sessionType: 'new_memorization', points: 10);

      final juz1 = repo.getStudentJuzProgress('st-boundary', 1);
      final juz2 = repo.getStudentJuzProgress('st-boundary', 2);

      expect(juz1['memorizedAyahs'], equals(2)); // Ayahs 140 and 141
      expect(juz2['memorizedAyahs'], equals(4)); // Ayahs 142, 143, 144, 145
    });

    test('countsTowardsStatistics toggle strictly excludes uncounted sessions from authentic progress', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationRepositoryImpl(localDs, syncQueue);

      final student = Student(id: 'st-stats', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'عثمان', gender: 'male', phone: '0500000000', code: 'U-1', totalPoints: 100);
      localDs.students.add(student);

      // Record with countsTowardsStatistics: false (e.g. trial / unverified / practice)
      repo.recordMemorization(
        studentId: 'st-stats',
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'review',
        points: 50,
        countsTowardsStatistics: false,
      );

      // Ayahs should NOT be counted in authentic keys
      final keys = repo.getStudentMemorizedAyahKeys('st-stats');
      expect(keys, isEmpty);

      // Points should NOT be awarded
      expect(student.totalPoints, equals(100));

      // Points log should have 0 points awarded
      expect(localDs.pointsLogs.first.points, equals(0));
      expect(localDs.pointsLogs.first.reason, contains('غير محسوب'));
    });

    test('Intensive course countsTowardsQuranProgress toggle controls inclusion in Quran deduplication', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationRepositoryImpl(localDs, syncQueue);

      localDs.students.add(Student(id: 'st-crs', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'معاذ', gender: 'male', phone: '0500000000', code: 'M-1'));

      // Course 1: does NOT count towards authentic Quran progress (e.g. speed reading course)
      localDs.intensiveCourses.add(IntensiveCourse(
        id: 'crs-no-quran',
        mosqueId: 'm-1',
        name: 'دورة قراءة سريعة',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
        countsTowardsQuranProgress: false,
        createdAt: DateTime.now(),
      ));

      // Course 2: counts towards authentic Quran progress
      localDs.intensiveCourses.add(IntensiveCourse(
        id: 'crs-quran',
        mosqueId: 'm-1',
        name: 'دورة الحفظ المكثف',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
        countsTowardsQuranProgress: true,
        createdAt: DateTime.now(),
      ));

      // Record under course 1
      repo.recordMemorization(
        studentId: 'st-crs',
        courseId: 'crs-no-quran',
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'new_memorization',
        points: 10,
      );
      expect(repo.getStudentMemorizedAyahKeys('st-crs'), isEmpty);

      // Record under course 2
      repo.recordMemorization(
        studentId: 'st-crs',
        courseId: 'crs-quran',
        surahName: 'الفاتحة',
        fromAyah: 1,
        toAyah: 7,
        juzNumber: 1,
        sessionType: 'new_memorization',
        points: 10,
      );
      expect(repo.getStudentMemorizedAyahKeys('st-crs').length, equals(7));
    });

    test('30 Ajza status map and complete 6,236 Ayahs Khatmah test', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationRepositoryImpl(localDs, syncQueue);

      localDs.students.add(Student(id: 'st-khatmah', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'القارئ المتقن', gender: 'male', phone: '0500000000', code: 'K-1'));

      // Record all 114 Surahs
      for (final s in quranSurahsInfo) {
        localDs.memorizationRecords.add(MemorizationRecord(
          id: 'mem-${s.number}',
          studentId: 'st-khatmah',
          surahName: s.name,
          fromAyah: 1,
          toAyah: s.ayahCount,
          juzNumber: s.startJuz,
          sessionType: 'new_memorization',
          qualityRating: 'excellent',
          pointsEarned: 10,
          recordedAt: DateTime.now(),
        ));
      }

      final overall = repo.getStudentOverallQuranProgress('st-khatmah');
      expect(overall['memorizedAyahs'], equals(6236));
      expect(overall['totalAyahs'], equals(6236));
      expect(overall['progress'], equals(1.0));
      expect(overall['completedAjza'], equals(30));

      final ajzaStatus = repo.getStudent30AjzaStatus('st-khatmah');
      expect(ajzaStatus.length, equals(30));
      for (int j = 1; j <= 30; j++) {
        expect(ajzaStatus[j]!['status'], equals('completed'));
        expect(ajzaStatus[j]!['isCompleted'], isTrue);
        expect(ajzaStatus[j]!['progress'], equals(1.0));
      }
      expect(repo.getStudentCompletedAjzaCount('st-khatmah'), equals(30));
    });
  });

  // =========================================================================
  // 4. Smart Recitation Timing Window (±30m) Adversarial Stress Suite
  // =========================================================================
  group('4. Smart Recitation Timing Window (±30m) Adversarial Stress Suite', () {
    test('Halaqa schedule window exact boundary edge-cases (-31m, -30m, mid, +30m, +31m)', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = CoursesRepositoryImpl(localDs, syncQueue);

      // Halaqa on Monday (weekday: 1), custom time 16:00 (duration: 16:00 to 18:00)
      final halaqa = Halaqa(
        id: 'h-timing',
        mosqueId: 'm-timing',
        name: 'حلقة التوقيت',
        daysOfWeek: [1], // Monday
        timingType: 'custom',
        customTime: '16:00',
      );
      localDs.halaqat.add(halaqa);

      // Find Monday
      DateTime monday = DateTime.now();
      while (monday.weekday != 1) {
        monday = monday.add(const Duration(days: 1));
      }

      // Case 1: 15:29:00 (31 minutes before start) -> OUTSIDE window -> 'custom'
      final tMinus31 = DateTime(monday.year, monday.month, monday.day, 15, 29);
      final r1 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tMinus31);
      expect(r1['mode'], equals('custom'));

      // Case 2: 15:30:00 (exact -30 minutes buffer start) -> INSIDE window -> 'normal'
      final tMinus30 = DateTime(monday.year, monday.month, monday.day, 15, 30);
      final r2 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tMinus30);
      expect(r2['mode'], equals('normal'));

      // Case 3: 17:00:00 (mid session) -> INSIDE window -> 'normal'
      final tMid = DateTime(monday.year, monday.month, monday.day, 17, 0);
      final r3 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tMid);
      expect(r3['mode'], equals('normal'));

      // Case 4: 18:00:00 (nominal end of 2hr session) -> INSIDE window -> 'normal'
      final tNominalEnd = DateTime(monday.year, monday.month, monday.day, 18, 0);
      final r4 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tNominalEnd);
      expect(r4['mode'], equals('normal'));

      // Case 5: 18:30:00 (exact +30 minutes buffer end) -> INSIDE window -> 'normal'
      final tPlus30 = DateTime(monday.year, monday.month, monday.day, 18, 30);
      final r5 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tPlus30);
      expect(r5['mode'], equals('normal'));

      // Case 6: 18:31:00 (31 minutes after session end) -> OUTSIDE window -> 'custom'
      final tPlus31 = DateTime(monday.year, monday.month, monday.day, 18, 31);
      final r6 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tPlus31);
      expect(r6['mode'], equals('custom'));

      // Case 7: Tuesday at 16:00:00 (wrong day of week) -> OUTSIDE window -> 'custom'
      final tuesday = monday.add(const Duration(days: 1));
      final tTuesday = DateTime(tuesday.year, tuesday.month, tuesday.day, 16, 0);
      final r7 = repo.detectSessionTimingMode(halaqaId: 'h-timing', currentTime: tTuesday);
      expect(r7['mode'], equals('custom'));
    });

    test('Precedence: Intensive Course overrides regular Halaqa when both windows overlap', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = CoursesRepositoryImpl(localDs, syncQueue);

      DateTime monday = DateTime.now();
      while (monday.weekday != 1) {
        monday = monday.add(const Duration(days: 1));
      }

      final halaqa = Halaqa(
        id: 'h-overlap',
        mosqueId: 'm-overlap',
        name: 'حلقة نظامية',
        daysOfWeek: [1],
        customTime: '16:00',
      );
      localDs.halaqat.add(halaqa);

      final course = IntensiveCourse(
        id: 'crs-overlap',
        mosqueId: 'm-overlap',
        name: 'دورة النخبة المكثفة',
        startDate: monday.subtract(const Duration(days: 1)),
        endDate: monday.add(const Duration(days: 10)),
        daysOfWeek: [1],
        startTime: '16:00',
        endTime: '18:00',
        halaqaIds: ['h-overlap'],
        createdAt: DateTime.now(),
      );
      localDs.intensiveCourses.add(course);

      // Testing at 16:15 on Monday
      final testTime = DateTime(monday.year, monday.month, monday.day, 16, 15);
      final result = repo.detectSessionTimingMode(
        halaqaId: 'h-overlap',
        currentTime: testTime,
      );

      // Course MUST take precedence over normal halaqa!
      expect(result['mode'], equals('course'));
      expect(result['courseId'], equals('crs-overlap'));
      expect(result['label'], contains('دورة النخبة المكثفة'));
    });

    test('Student and Halaqa filtering in Intensive Courses correctly falls through when not enrolled', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = CoursesRepositoryImpl(localDs, syncQueue);

      DateTime monday = DateTime.now();
      while (monday.weekday != 1) {
        monday = monday.add(const Duration(days: 1));
      }

      final halaqa = Halaqa(
        id: 'h-target',
        mosqueId: 'm-target',
        name: 'حلقة المستهدفين',
        daysOfWeek: [1],
        customTime: '16:00',
      );
      localDs.halaqat.add(halaqa);

      // Course only enrolled for student 'st-enrolled'
      final course = IntensiveCourse(
        id: 'crs-targeted',
        mosqueId: 'm-target',
        name: 'دورة خاصة للمتميزين',
        startDate: monday.subtract(const Duration(days: 1)),
        endDate: monday.add(const Duration(days: 10)),
        daysOfWeek: [1],
        startTime: '16:00',
        endTime: '18:00',
        halaqaIds: ['h-target'],
        studentIds: ['st-enrolled'],
        createdAt: DateTime.now(),
      );
      localDs.intensiveCourses.add(course);

      final testTime = DateTime(monday.year, monday.month, monday.day, 16, 15);

      // Student 1 (enrolled) -> matches course
      final r1 = repo.detectSessionTimingMode(halaqaId: 'h-target', studentId: 'st-enrolled', currentTime: testTime);
      expect(r1['mode'], equals('course'));

      // Student 2 (not enrolled) -> falls back to regular halaqa session
      final r2 = repo.detectSessionTimingMode(halaqaId: 'h-target', studentId: 'st-other', currentTime: testTime);
      expect(r2['mode'], equals('normal'));

      // Halaqa 2 (not linked to course) -> falls through
      final r3 = repo.detectSessionTimingMode(halaqaId: 'h-other', studentId: 'st-enrolled', currentTime: testTime);
      expect(r3['mode'], equals('custom'));
    });
  });

  // =========================================================================
  // 5. Rewards Voucher Generation & Cashier Dispensation Adversarial Stress Suite
  // =========================================================================
  group('5. Rewards Voucher Generation & Cashier Dispensation Adversarial Stress Suite', () {
    test('Voucher code generation matches VCH-XXXX 4-digit format and requires sufficient balance', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RewardsRepositoryImpl(localDs, syncQueue);

      localDs.mosques.add(Mosque(id: 'm-1', name: 'جامع الهدى', address: '', city: '', gender: 'male', accessCode: ''));
      final student = Student(id: 'st-rew', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'أحمد', gender: 'male', phone: '0500000000', code: 'A-1', totalPoints: 100);
      localDs.students.add(student);

      final reward = repo.addReward(mosqueId: 'm-1', title: 'ساعة يد رقمية', pointsCost: 80);

      // Claim reward with 100 points (cost: 80) -> Succeeds
      final redemption = repo.claimReward(studentId: 'st-rew', rewardId: reward.id);
      expect(redemption, isNotNull);
      expect(redemption!.status, equals('pending'));
      expect(RegExp(r'^VCH-\d{4}$').hasMatch(redemption.redemptionCode), isTrue);

      // Second claim attempt for expensive reward (cost 150) -> Fails (insufficient points)
      final expReward = repo.addReward(mosqueId: 'm-1', title: 'دراجة هوائية', pointsCost: 150);
      final failedRedemption = repo.claimReward(studentId: 'st-rew', rewardId: expReward.id);
      expect(failedRedemption, isNull);
    });

    test('Cashier dispensation flow: deductions, double-spend defense, and whitespace/case tolerance', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RewardsRepositoryImpl(localDs, syncQueue);

      localDs.mosques.add(Mosque(id: 'm-1', name: 'جامع الهدى', address: '', city: '', gender: 'male', accessCode: ''));
      final student = Student(id: 'st-cash', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'يحيى', gender: 'male', phone: '0500000000', code: 'Y-1', totalPoints: 100);
      localDs.students.add(student);

      final reward = repo.addReward(mosqueId: 'm-1', title: 'كتاب سيرة', pointsCost: 40);
      final redemption = repo.claimReward(studentId: 'st-cash', rewardId: reward.id)!;
      final voucherCode = redemption.redemptionCode;

      // 1. Dispense with lowercase and whitespace padding: "  vch-xxxx  "
      final paddedCode = '   ${voucherCode.toLowerCase()}   ';
      final disp1 = repo.dispenseReward(voucherCode: paddedCode, cashierName: 'أمين المستودع');
      expect(disp1['success'], isTrue);
      expect(disp1['pointsDeducted'], equals(40));
      expect(disp1['remainingPoints'], equals(60));
      expect(student.totalPoints, equals(60));

      // Check points log has negative entry
      final lastLog = localDs.pointsLogs.first;
      expect(lastLog.points, equals(-40));
      expect(lastLog.category, equals('reward'));

      // 2. Adversarial Double-Spend: Try to dispense the exact same voucher code again!
      final disp2 = repo.dispenseReward(voucherCode: voucherCode, cashierName: 'أمين المستودع');
      expect(disp2['success'], isFalse);
      expect(disp2['message'], contains('تم صرف هذه الجائزة مسبقاً'));
      // Points must NOT be deducted again
      expect(student.totalPoints, equals(60));

      // 3. Dispense non-existent code
      final disp3 = repo.dispenseReward(voucherCode: 'VCH-9999-FAKE', cashierName: 'أمين المستودع');
      expect(disp3['success'], isFalse);
      expect(disp3['message'], contains('رمز القسيمة غير صحيح'));
    });

    test('Dispensation defense when student points were spent elsewhere between claim and dispensation', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RewardsRepositoryImpl(localDs, syncQueue);

      localDs.mosques.add(Mosque(id: 'm-1', name: 'جامع الهدى', address: '', city: '', gender: 'male', accessCode: ''));
      final student = Student(id: 'st-drain', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'سعيد', gender: 'male', phone: '0500000000', code: 'S-1', totalPoints: 50);
      localDs.students.add(student);

      final reward = repo.addReward(mosqueId: 'm-1', title: 'حقيبة مدرسية', pointsCost: 50);
      final redemption = repo.claimReward(studentId: 'st-drain', rewardId: reward.id)!;

      // Student points drained by penalty / another redemption before cashier confirms
      student.totalPoints = 10;

      // Cashier attempts dispensation
      final result = repo.dispenseReward(voucherCode: redemption.redemptionCode, cashierName: 'الكاشير');
      expect(result['success'], isFalse);
      expect(result['message'], contains('رصيد نقاط الطالب غير كافٍ'));
      // Status remains pending
      expect(redemption.status, equals('pending'));
      expect(student.totalPoints, equals(10));
    });
  });

  // =========================================================================
  // 6. Attendance Commitment Rate Formula & Replacement Logic Suite
  // =========================================================================
  group('6. Attendance Commitment Rate Formula & Replacement Logic Suite', () {
    test('Commitment rate formula: (present + late * 0.5) / total * 100 handles all statuses', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = AttendanceRepositoryImpl(localDs, syncQueue);

      // Student with 0 records -> 100.0% initial rate
      final sum0 = repo.getStudentAttendanceSummary('st-none');
      expect(sum0['total'], equals(0));
      expect(sum0['attendanceRate'], equals('100.0'));

      // Add 1 present, 1 late, 1 absent -> (1 + 0.5) / 3 * 100 = 50.0%
      repo.recordAttendance(studentId: 'st-att', halaqaId: 'h-1', sessionDate: '2026-09-01', status: 'present');
      repo.recordAttendance(studentId: 'st-att', halaqaId: 'h-1', sessionDate: '2026-09-02', status: 'late');
      repo.recordAttendance(studentId: 'st-att', halaqaId: 'h-1', sessionDate: '2026-09-03', status: 'absent');

      final sum1 = repo.getStudentAttendanceSummary('st-att');
      expect(sum1['total'], equals(3));
      expect(sum1['present'], equals(1));
      expect(sum1['late'], equals(1));
      expect(sum1['absent'], equals(1));
      expect(sum1['attendanceRate'], equals('50.0'));

      // Re-recording on same date replaces existing record instead of duplicating
      repo.recordAttendance(studentId: 'st-att', halaqaId: 'h-1', sessionDate: '2026-09-03', status: 'present');
      final sum2 = repo.getStudentAttendanceSummary('st-att');
      expect(sum2['total'], equals(3)); // Still 3 records!
      expect(sum2['present'], equals(2));
      expect(sum2['absent'], equals(0));
      // (2 + 0.5) / 3 * 100 = 83.3%
      expect(sum2['attendanceRate'], equals('83.3'));
    });
  });

  // =========================================================================
  // 7. Custom Recitation Tracks Progress Deduplication Suite
  // =========================================================================
  group('7. Custom Recitation Tracks Progress Deduplication Suite', () {
    test('Track unit progress deduplicates overlapping and reversed ranges up to totalUnits', () {
      final localDs = LocalStorageDataSource();
      final syncQueue = OfflineSyncQueueManager();
      final repo = RecitationTracksRepositoryImpl(localDs, syncQueue);

      final track = repo.addRecitationTrack(
        mosqueId: 'm-1',
        name: 'الأربعون النووية',
        unitLabel: 'حديث',
        totalUnits: 42,
        pointsPerUnit: 5,
      );

      localDs.students.add(Student(id: 'st-trk', mosqueId: 'm-1', halaqaId: 'h-1', fullName: 'عمار', gender: 'male', phone: '0500000000', code: 'AM-1'));

      // Session 1: units 1..10
      repo.recordSubjectRecitation(studentId: 'st-trk', trackId: track.id, trackName: track.name, fromUnit: 1, toUnit: 10, pointsEarned: 50);
      // Session 2: reversed range units 15 down to 5 (overlaps 5..10)
      repo.recordSubjectRecitation(studentId: 'st-trk', trackId: track.id, trackName: track.name, fromUnit: 15, toUnit: 5, pointsEarned: 50);
      // Session 3: units beyond total (40..50) -> should cap at 42
      repo.recordSubjectRecitation(studentId: 'st-trk', trackId: track.id, trackName: track.name, fromUnit: 40, toUnit: 50, pointsEarned: 15);

      final progress = repo.getStudentSubjectProgress('st-trk', track.id);
      // Units covered: 1..15 (15 units) + 40..42 (3 units: 40, 41, 42) = 18 units
      expect(progress['uniqueUnitsCount'], equals(18));
      expect(progress['totalUnits'], equals(42));
      expect(progress['isCompleted'], isFalse);
      expect(progress['progress'], closeTo(18 / 42, 0.001));
    });
  });

  // =========================================================================
  // 8. DataService Facade Parity & Notification Suite
  // =========================================================================
  group('8. DataService Facade Parity & Notification Suite', () {
    test('DataService triggers notifyListeners and maintains parity with modular repos', () async {
      final ds = DataService();
      await ds.init();

      int listenerNotificationCount = 0;
      ds.addListener(() {
        listenerNotificationCount++;
      });

      // Toggle theme -> notifies listeners
      ds.toggleTheme();
      expect(listenerNotificationCount, greaterThanOrEqualTo(1));

      // Adding student through facade awards welcome points and notifies
      final mosque = ds.addMosque(name: 'مسجد الفرقان', address: 'حلب', city: 'حلب', gender: 'male');
      final student = ds.addStudent(
        mosqueId: mosque.id,
        halaqaId: 'h-1',
        fullName: 'مصعب بن عمير',
        gender: 'male',
        phone: '0500000000',
        welcomePoints: 200,
      );
      expect(student.totalPoints, equals(200));

      // Querying through modular repository getter in facade returns same entity
      final fetched = ds.studentsRepository
          .getStudents(mosqueId: mosque.id)
          .firstWhere((s) => s.id == student.id);
      expect(fetched.fullName, equals('مصعب بن عمير'));
      expect(fetched.totalPoints, equals(200));
    });
  });
}
