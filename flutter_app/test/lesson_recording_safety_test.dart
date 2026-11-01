import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/audio_upload_queue_manager.dart';
import 'package:flutter_app/services/lesson_recording_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ترويسة WAV كما يتركها مسجّل ويندوز إن أُغلق التطبيق قبل الإيقاف: الأحجام أصفار.
Uint8List _wavWithZeroSizes(int dataBytes) {
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  str('RIFF');
  u32(0);
  str('WAVE');
  str('fmt ');
  u32(18);
  u16(1); // PCM
  u16(2);
  u32(44100);
  u32(44100 * 4);
  u16(4);
  u16(16);
  u16(0); // cbSize
  str('data');
  u32(0);
  b.add(List.filled(dataBytes, 7));
  return b.toBytes();
}

Uint8List _box(String type, int payload) {
  final b = BytesBuilder();
  b.add((ByteData(4)..setUint32(0, 8 + payload)).buffer.asUint8List());
  b.add(type.codeUnits);
  b.add(List.filled(payload, 0));
  return b.toBytes();
}

void main() {
  late Directory dir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('mihrab_recording');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  group('إنقاذ تسجيل لم يُختم', () {
    test('ترويسة WAV تُصحَّح من طول الملف', () {
      final f = file('a.wav')..writeAsBytesSync(_wavWithZeroSizes(4000));
      expect(LessonRecordingJournal.repairWavSizes(f), isTrue);
      final bytes = ByteData.sublistView(f.readAsBytesSync());
      expect(bytes.getUint32(4, Endian.little), f.lengthSync() - 8);
      expect(bytes.getUint32(42, Endian.little), 4000);
      expect(f.lengthSync(), 46 + 4000, reason: 'التصحيح لا يضيف شيئاً إلى آخر الملف');
    });

    test('ملف ليس WAV لا يُمسّ', () {
      final f = file('b.wav')..writeAsBytesSync(List.filled(100, 1));
      expect(LessonRecordingJournal.repairWavSizes(f), isFalse);
      expect(f.readAsBytesSync(), everyElement(1));
    });

    test('m4a بلا فهرس moov (أُغلق قبل ختمه) يُعرف أنه لا يُفتح', () {
      final ok = file('ok.m4a')
        ..writeAsBytesSync([..._box('ftyp', 16), ..._box('mdat', 2000), ..._box('moov', 100)]);
      final broken = file('broken.m4a')..writeAsBytesSync([..._box('ftyp', 16), ..._box('mdat', 2000)]);
      expect(LessonRecordingJournal.hasMp4Index(ok), isTrue);
      expect(LessonRecordingJournal.hasMp4Index(broken), isFalse);
    });

    test('تسجيل مختوم بقي بلا رفع يُؤرشف ويدخل الطابور مرة واحدة', () async {
      final f = file('lesson.m4a')
        ..writeAsBytesSync([..._box('ftyp', 16), ..._box('moov', 100), ..._box('mdat', 4000)]);
      await LessonRecordingJournal.begin(ActiveLessonRecording(
        eventId: 'e1',
        path: f.path,
        part: 2,
        title: 'شرح الأربعين',
        speaker: 'الشيخ',
        seconds: 0,
      ));
      await LessonRecordingJournal.updateSeconds(f.path, 1230);

      final finalized = <String>[];
      final queued = <Map<String, Object>>[];
      Future<RecordingRecovery> run() => LessonRecordingJournal.recover(
            finalize: (id, part) {
              finalized.add('$id/p$part');
              return 'archived-$id-p$part-1';
            },
            enqueue: ({
              required String eventId,
              required String title,
              required String speaker,
              required String filePath,
              required int durationSeconds,
            }) async {
              queued.add({'id': eventId, 'title': title, 'path': filePath, 'sec': durationSeconds});
            },
          );

      expect(await run(), RecordingRecovery.recovered);
      expect(await run(), RecordingRecovery.none, reason: 'لا يُرفع مرتين');
      expect(finalized, ['e1/p2']);
      expect(queued, [
        {'id': 'archived-e1-p2-1', 'title': 'شرح الأربعين — الجزء 2', 'path': f.path, 'sec': 1230},
      ]);
    });

    test('ملف m4a معطوب لا يُرفع ويبقى على الجهاز', () async {
      final f = file('broken.m4a')..writeAsBytesSync([..._box('ftyp', 16), ..._box('mdat', 4000)]);
      await LessonRecordingJournal.begin(ActiveLessonRecording(
          eventId: 'e2', path: f.path, part: 1, title: 't', speaker: 's', seconds: 60));
      var queued = false;
      final r = await LessonRecordingJournal.recover(
        finalize: (_, __) => 'x',
        enqueue: ({
          required String eventId,
          required String title,
          required String speaker,
          required String filePath,
          required int durationSeconds,
        }) async =>
            queued = true,
      );
      expect(r, RecordingRecovery.unreadable);
      expect(queued, isFalse);
      expect(f.existsSync(), isTrue);
      expect(await LessonRecordingJournal.read(), isNull);
    });
  });

  group('ربط التسجيل بدرسه بعد الرفع', () {
    test('سجل الدرس لم يصل بعد: لا يُحذف الملف ولا يُرفع مرة ثانية، ويُربط حين يصل', () async {
      final queue = AudioUploadQueueManager()
        ..retryBase = const Duration(milliseconds: 20)
        ..linkRetry = const Duration(milliseconds: 30);
      var uploads = 0;
      queue.debugRefUploader = (_, __) async {
        uploads++;
        return 'tg:audio:FILE1';
      };
      var eventArrived = false;
      final linked = <String>[];
      queue.setOnMediaUploadSuccess((id, ref, isVideo) {
        if (!eventArrived) return false;
        linked.add('$id=$ref');
        return true;
      });

      final f = file('c.m4a')..writeAsBytesSync([1, 2, 3]);
      await queue.addToQueue(
        eventId: 'archived-e3-1',
        title: 'درس',
        speaker: 'الشيخ',
        filePath: f.path,
        durationSeconds: 60,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(queue.queue.single.uploadedRef, 'tg:audio:FILE1');
      expect(f.existsSync(), isTrue);

      eventArrived = true;
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (queue.queue.isNotEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(queue.queue, isEmpty);
      expect(uploads, 1);
      expect(linked, ['archived-e3-1=tg:audio:FILE1']);
      expect(f.existsSync(), isFalse);
    });

    test('ملف ينتظر الربط لا يوقف رفع ما بعده', () async {
      final queue = AudioUploadQueueManager()..linkRetry = const Duration(hours: 1);
      queue.debugRefUploader = (u, _) async => 'tg:audio:${u.eventId}';
      final linked = <String>[];
      queue.setOnMediaUploadSuccess((id, ref, _) {
        if (id == 'missing') return false;
        linked.add(id);
        return true;
      });
      for (final id in ['missing', 'present']) {
        await queue.addToQueue(
          eventId: id,
          title: 't',
          speaker: 's',
          filePath: (file('$id.m4a')..writeAsBytesSync([1])).path,
          durationSeconds: 1,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(linked, ['present']);
      expect(queue.queue.map((u) => u.eventId), ['missing']);
    });

    test('مرجع الرفع محفوظ مع الطابور بعد إعادة فتح التطبيق', () async {
      final first = AudioUploadQueueManager()..linkRetry = const Duration(hours: 1);
      first.debugRefUploader = (_, __) async => 'tg:audio:KEEP';
      first.setOnMediaUploadSuccess((_, __, ___) => false);
      await first.addToQueue(
        eventId: 'e4',
        title: 't',
        speaker: 's',
        filePath: (file('d.m4a')..writeAsBytesSync([1])).path,
        durationSeconds: 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reopened = AudioUploadQueueManager();
      var uploads = 0;
      reopened.debugRefUploader = (_, __) async {
        uploads++;
        return 'tg:audio:NEW';
      };
      final linked = <String>[];
      reopened.setOnMediaUploadSuccess((id, ref, _) {
        linked.add(ref);
        return true;
      });
      await reopened.init();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(uploads, 0);
      expect(linked, ['tg:audio:KEEP']);
    });
  });
}
