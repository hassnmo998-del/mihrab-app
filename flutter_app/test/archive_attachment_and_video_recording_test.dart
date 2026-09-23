import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/utils/app_file_launcher.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/audio_upload_queue_manager.dart';
import 'package:flutter_app/services/telegram_media_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. AppFileLauncher & Attachment Type Intelligence Tests', () {
    test('Correctly classifies YouTube video links', () {
      final info = AppFileLauncher.getAttachmentInfo('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(info.type, AppAttachmentType.video);
      expect(info.title.contains('تسجيل مرئي'), isTrue);
      expect(info.actionLabel, 'مشاهدة الفيديو');
    });

    test('Correctly classifies direct web URLs', () {
      final info = AppFileLauncher.getAttachmentInfo('https://t.me/masjed_channel/123');
      expect(info.type, AppAttachmentType.link);
      expect(info.actionLabel, 'فتح الرابط');
    });

    test('Correctly classifies local MP4/MKV video files', () {
      final info = AppFileLauncher.getAttachmentInfo('/storage/emulated/0/Movies/lesson_01.mp4');
      expect(info.type, AppAttachmentType.video);
      expect(info.subtitle, 'lesson_01.mp4');
      expect(info.actionLabel, 'مشاهدة الفيديو');
    });

    test('Correctly classifies Windows video paths with backslashes', () {
      final info = AppFileLauncher.getAttachmentInfo(r'C:\Users\moham\Videos\tafseer_lesson.mkv');
      expect(info.type, AppAttachmentType.video);
      expect(info.actionLabel, 'مشاهدة الفيديو');
    });

    test('Correctly classifies PDF documents', () {
      final info = AppFileLauncher.getAttachmentInfo(r'C:\Documents\sharh_matn.pdf');
      expect(info.type, AppAttachmentType.document);
      expect(info.title.contains('PDF'), isTrue);
      expect(info.actionLabel, 'فتح المستند');
    });

    test('Correctly classifies audio recordings', () {
      final info = AppFileLauncher.getAttachmentInfo('/records/lesson_audio.m4a');
      expect(info.type, AppAttachmentType.audio);
      expect(info.actionLabel, 'تشغيل الصوت');
    });

    test('Correctly classifies generic archive files', () {
      final info = AppFileLauncher.getAttachmentInfo('/files/bundle.zip');
      expect(info.type, AppAttachmentType.generic);
      expect(info.actionLabel, 'فتح الملف');
    });
  });

  group('2. Strict Archive Management Permissions Tests', () {
    final testEvent = CommunityEvent(
      id: 'event-archived-101',
      mosqueId: 'mosque-umawi',
      title: 'شرح رياض الصالحين',
      description: 'المجلس الأسبوعي',
      eventType: 'lesson',
      targetAudience: 'general',
      eventDateTime: DateTime.now().subtract(const Duration(days: 2)),
      organizerType: 'sheikh',
      organizerName: 'الشيخ محمد راتب',
      sheikhId: 'sheikh-101',
      eventStatus: 'archived',
    );

    bool checkCanManage(CommunityEvent ev, ActiveSession? session) {
      if (session == null) return false;
      // 1. صاحب العنصر نفسه في الأرشيف
      final isOwner = (session.role == 'sheikh' && (
        (session.sheikhId != null && session.sheikhId == ev.sheikhId) ||
        session.name == ev.organizerName
      )) || (session.name == ev.organizerName);

      if (isOwner) return true;

      // 2. الإدارة المالكة لو كان الدرس بمسجدها
      final isMosqueAdmin = (session.role == 'mosque_admin' && session.mosqueId != null && session.mosqueId == ev.mosqueId);
      return isMosqueAdmin;
    }

    test('Sheikh owner matching sheikhId CAN manage the archive item', () {
      final session = ActiveSession(
        role: 'sheikh',
        code: 'SHK-101',
        name: 'الشيخ محمد راتب',
        sheikhId: 'sheikh-101',
        mosqueId: 'mosque-umawi',
      );
      expect(checkCanManage(testEvent, session), isTrue);
    });

    test('Sheikh owner matching organizer name CAN manage the archive item', () {
      final session = ActiveSession(
        role: 'sheikh',
        code: 'SHK-OTHER-CODE',
        name: 'الشيخ محمد راتب',
        sheikhId: null,
      );
      expect(checkCanManage(testEvent, session), isTrue);
    });

    test('Sheikh from another halaqa/mosque CANNOT manage this archive item', () {
      final otherSheikh = ActiveSession(
        role: 'sheikh',
        code: 'SHK-202',
        name: 'الشيخ خالد',
        sheikhId: 'sheikh-202',
        mosqueId: 'mosque-other',
      );
      expect(checkCanManage(testEvent, otherSheikh), isFalse);
    });

    test('Mosque admin of the host mosque CAN manage the archive item', () {
      final adminOfHostMosque = ActiveSession(
        role: 'mosque_admin',
        code: 'ADM-UMAWI',
        name: 'مدير المسجد الأموي',
        mosqueId: 'mosque-umawi',
      );
      expect(checkCanManage(testEvent, adminOfHostMosque), isTrue);
    });

    test('Mosque admin of ANOTHER mosque CANNOT manage the archive item', () {
      final adminOfOtherMosque = ActiveSession(
        role: 'mosque_admin',
        code: 'ADM-OTHER',
        name: 'مدير مسجد آخر',
        mosqueId: 'mosque-other',
      );
      expect(checkCanManage(testEvent, adminOfOtherMosque), isFalse);
    });

    test('Regular student CANNOT manage the archive item', () {
      final studentSession = ActiveSession(
        role: 'student',
        code: 'STD-11',
        name: 'أحمد الطالب',
        studentId: 'std-11',
        mosqueId: 'mosque-umawi',
      );
      expect(checkCanManage(testEvent, studentSession), isFalse);
    });

    test('Visitor CANNOT manage the archive item', () {
      final visitorSession = ActiveSession(
        role: 'visitor',
        code: 'VIS-01',
        name: 'زائر',
      );
      expect(checkCanManage(testEvent, visitorSession), isFalse);
    });
  });

  group('3. PendingUpload & Media Upload Queue Tests', () {
    test('PendingUpload serializes and deserializes isVideo flag accurately', () {
      final upload = PendingUpload(
        eventId: 'ev-video-1',
        title: 'درس التفسير المرئي',
        speaker: 'الشيخ أحمد',
        filePath: '/storage/lesson.mp4',
        durationSeconds: 3600,
        queuedAt: DateTime(2026, 9, 18, 10, 0),
        kind: UploadKind.video,
      );

      final json = upload.toJson();
      expect(json['isVideo'], isTrue);
      expect(json['eventId'], 'ev-video-1');
      expect(json['durationSeconds'], 3600);

      final deserialized = PendingUpload.fromJson(json);
      expect(deserialized.isVideo, isTrue);
      expect(deserialized.eventId, 'ev-video-1');
      expect(deserialized.filePath, '/storage/lesson.mp4');
    });

    test('PendingUpload maintains 100% backwards compatibility when isVideo is absent in json', () {
      final legacyJson = {
        'eventId': 'ev-audio-legacy',
        'title': 'درس صوتي قديم',
        'speaker': 'الشيخ عبد الله',
        'filePath': '/records/audio.m4a',
        'durationSeconds': 1800,
        'queuedAt': DateTime.now().toIso8601String(),
      };

      final parsed = PendingUpload.fromJson(legacyJson);
      expect(parsed.isVideo, isFalse);
      expect(parsed.kind, UploadKind.audio);
      expect(parsed.title, 'درس صوتي قديم');
    });

    test('Legacy queued video (isVideo only, no kind) still parses as video', () {
      final parsed = PendingUpload.fromJson({
        'eventId': 'ev-video-legacy',
        'title': 'فيديو قديم',
        'speaker': 'الشيخ',
        'filePath': '/records/lesson.mp4',
        'durationSeconds': 60,
        'queuedAt': DateTime.now().toIso8601String(),
        'isVideo': true,
      });
      expect(parsed.kind, UploadKind.video);
    });

    test('Document attachment keeps its kind and original file name', () {
      final upload = PendingUpload(
        eventId: 'ev-doc',
        title: 'درس الفقه',
        speaker: 'الشيخ',
        filePath: '/uploads/123_ملخص الدرس.pdf',
        durationSeconds: 0,
        queuedAt: DateTime(2026, 9, 23),
        kind: UploadKind.document,
        fileName: 'ملخص الدرس.pdf',
      );
      final parsed = PendingUpload.fromJson(upload.toJson());
      expect(parsed.kind, UploadKind.document);
      expect(parsed.fileName, 'ملخص الدرس.pdf');
      expect(parsed.isVideo, isFalse);
    });

    test('AudioUploadQueueManager queues and persists video items correctly', () async {
      final tempDir = Directory.systemTemp.createTempSync('upload_test');
      final tempFile = File('${tempDir.path}/test_video.mp4')..writeAsStringSync('dummy video content');

      try {
        final manager = AudioUploadQueueManager();
        await manager.addToQueue(
          eventId: 'ev-test-video',
          title: 'فيديو الفقه',
          speaker: 'الشيخ خالد',
          filePath: tempFile.path,
          durationSeconds: 2400,
          kind: UploadKind.video,
        );

        expect(manager.queue.length, 1);
        final item = manager.queue.first;
        expect(item.isVideo, isTrue);
        expect(item.eventId, 'ev-test-video');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('4. Archive references & size limits', () {
    test('File reference round-trips its id and original name', () {
      final ref = TelegramMediaResolver.buildFileRef(fileId: 'BQACAgQ-xyz_1', fileName: 'ملخص: الدرس|1.pdf');
      expect(TelegramMediaResolver.isRef(ref), isTrue);
      expect(TelegramMediaResolver.isFileRef(ref), isTrue);
      expect(TelegramMediaResolver.isVideoRef(ref), isFalse);
      expect(TelegramMediaResolver.fileIdOf(ref), 'BQACAgQ-xyz_1');
      expect(TelegramMediaResolver.fileNameOf(ref), 'ملخص: الدرس|1.pdf');
    });

    test('Audio/video references keep working as before', () {
      final ref = TelegramMediaResolver.buildRef(fileId: 'CQACAgQ', isVideo: false);
      expect(ref, 'tg:audio:CQACAgQ');
      expect(TelegramMediaResolver.fileIdOf(ref), 'CQACAgQ');
      expect(TelegramMediaResolver.fileNameOf(ref), isNull);
    });

    test('Attached file reference is classified by its original extension', () {
      final pdf = TelegramMediaResolver.buildFileRef(fileId: 'a', fileName: 'درس.pdf');
      final mp4 = TelegramMediaResolver.buildFileRef(fileId: 'b', fileName: 'مقطع.mp4');
      expect(AppFileLauncher.getAttachmentInfo(pdf).type, AppAttachmentType.document);
      expect(AppFileLauncher.getAttachmentInfo(pdf).subtitle, 'درس.pdf');
      expect(AppFileLauncher.getAttachmentInfo(mp4).type, AppAttachmentType.video);
    });

    test('One hour of compressed recording fits under the archive limit', () {
      final bytesPerHour = MediaLimits.recordingBitRate ~/ 8 * MediaLimits.maxRecording.inSeconds;
      expect(bytesPerHour, lessThan(MediaLimits.maxFileBytes));
      expect(MediaLimits.maxFileMbLabel, '20.0');
      expect(MediaLimits.formatMb(35 * 1024 * 1024 + 200 * 1024), '35.2');
    });
  });
}
