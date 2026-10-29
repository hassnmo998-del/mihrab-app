import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/lesson_audio_engine.dart';
import 'package:flutter_app/services/lesson_audio_importer.dart';
import 'package:flutter_app/services/telegram_media_resolver.dart';

/// محرّك وهمي: يقيس مدة محددة ويكتب ملفاً بحجم يتناسب مع ما طُلب ضغطه.
class _FakeEngine implements LessonAudioEngine {
  final Duration? total;
  final int bytesPerSecond;
  final Set<int> failingCalls;

  /// مدة تُكتب فعلاً في استدعاء معيّن (رقمه من 1) بدل المطلوب، كملف أقصر من تقدير مدته.
  final Map<int, Duration> actualWrites;
  final List<({Duration start, Duration? length})> calls = [];

  _FakeEngine(
    this.total, {
    this.bytesPerSecond = 100,
    this.failingCalls = const {},
    this.actualWrites = const {},
  });

  @override
  Future<Duration?> probe(String path) async => total;

  @override
  Future<Duration?> compress(String input, String output, {Duration start = Duration.zero, Duration? length}) async {
    calls.add((start: start, length: length));
    if (failingCalls.contains(calls.length)) return null;
    final written = actualWrites[calls.length] ?? length ?? (total! - start);
    File(output).writeAsBytesSync(List.filled(max(1, written.inSeconds * bytesPerSecond), 7));
    return written;
  }
}

/// A 16-bit PCM WAV, like a voice recorder or another phone would hand over.
File _writeWav(String path, {int seconds = 20, int sampleRate = 44100, int channels = 2}) {
  final frames = sampleRate * seconds;
  final samples = frames * channels;
  final data = ByteData(44 + samples * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2 * channels, Endian.little);
  data.setUint16(32, 2 * channels, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  final rnd = Random(1);
  for (var i = 0; i < frames; i++) {
    final t = i / sampleRate;
    final v = sin(2 * pi * (180 + 60 * sin(t * 3)) * t) * 8000 + (rnd.nextDouble() - 0.5) * 1500;
    for (var c = 0; c < channels; c++) {
      data.setInt16(44 + (i * channels + c) * 2, v.round(), Endian.little);
    }
  }
  return File(path)..writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  group('نوع الملف', () {
    test('الصوت مقبول مهما كان حجم الأحرف، والفيديو والمستندات والصور مرفوضة', () {
      for (final name in ['درس.mp3', 'LESSON.M4A', 'a.b.wav', 'x.flac', 'x.wma', 'x.opus', 'x.ogg', 'x.amr', 'x.aac']) {
        expect(LessonAudioImporter.isAudioFileName(name), isTrue, reason: name);
      }
      for (final name in ['درس.mp4', 'x.mkv', 'x.mov', 'x.pdf', 'x.docx', 'x.jpg', 'x.exe', 'x.txt', 'x.zip']) {
        expect(LessonAudioImporter.isAudioFileName(name), isFalse, reason: name);
      }
    });

    test('ملف بلا امتداد لا يُرفض مسبقاً: المحرّك يقرر بقراءة محتواه', () {
      expect(LessonAudioImporter.isAudioFileName('voice_note'), isTrue);
      expect(LessonAudioImporter.isAudioFileName('voice_note.'), isTrue);
    });
  });

  group('تقسيم الدرس الطويل إلى أجزاء ساعة', () {
    const hour = Duration(minutes: 60);
    List<AudioSlice> plan(int minutes) => LessonAudioImporter.planParts(Duration(minutes: minutes), limit: hour);

    test('ساعة فأقل: جزء واحد هو الملف كله', () {
      for (final m in [1, 30, 59, 60]) {
        final slices = plan(m);
        expect(slices, hasLength(1), reason: '$m min');
        expect(slices.single.start, Duration.zero);
        expect(slices.single.length, isNull);
      }
    });

    test('بقية قصيرة (حتى 3 دقائق) بعد الساعة تبقى في الجزء الأول لا جزءاً ثانياً بثوانٍ', () {
      expect(plan(61), hasLength(1));
      expect(plan(63), hasLength(1));
      expect(plan(64), hasLength(2));
    });

    test('ساعتان وبضع دقائق وثلاث ساعات: أجزاء ساعة، والأخير يكمل الملف حتى آخره', () {
      final two = plan(125);
      expect(two, hasLength(3));
      expect(two.map((s) => s.start), [Duration.zero, hour, hour * 2]);
      expect(two.map((s) => s.length), [hour, hour, null]);

      final three = plan(180);
      expect(three, hasLength(3));
      expect(three.last.length, isNull);
      expect(three.where((s) => s.length != null).every((s) => s.length == hour), isTrue);
    });

    test('لا جزء يتجاوز الحد إلا بالبقية المضمومة: الأرشيف لا يرفع ما فوق 20MB', () {
      // أطول جزء ممكن = ساعة + 3 دقائق بـ32kbps
      final worst = (hour + const Duration(minutes: 3)).inSeconds * MediaLimits.recordingBitRate ~/ 8;
      expect(worst, lessThan(MediaLimits.maxFileBytes));
    });
  });

  group('تجهيز التسجيل (محرّك وهمي)', () {
    late Directory dir;
    late File source;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('mihrab_import_test');
      source = File('${dir.path}${Platform.pathSeparator}source.mp3')..writeAsBytesSync([1, 2, 3]);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<List<ImportedLessonPart>> prepare(_FakeEngine engine, {String name = 'source.mp3'}) => LessonAudioImporter.prepare(
          sourcePath: source.path,
          sourceName: name,
          outDir: '${dir.path}${Platform.pathSeparator}out',
          outPrefix: 'lesson_x',
          engine: engine,
        );

    test('درس ساعتان ونصف: ثلاثة أجزاء، كل جزء بملفه ومدته، وملف المستخدم لا يُمسّ', () async {
      final engine = _FakeEngine(const Duration(minutes: 150));
      final parts = await prepare(engine);

      expect(parts.map((p) => p.number), [1, 2, 3]);
      expect(parts.map((p) => p.duration.inMinutes), [60, 60, 30]);
      expect(parts.map((p) => p.path.split(Platform.pathSeparator).last), ['lesson_x_p1.m4a', 'lesson_x_p2.m4a', 'lesson_x_p3.m4a']);
      expect(parts.every((p) => File(p.path).existsSync()), isTrue);
      expect(engine.calls.map((c) => c.start.inMinutes), [0, 60, 120]);
      expect(engine.calls.map((c) => c.length?.inMinutes), [60, 60, null]);
      expect(source.readAsBytesSync(), [1, 2, 3]);
    });

    test('درس قصير: جزء واحد', () async {
      final parts = await prepare(_FakeEngine(const Duration(minutes: 40)));
      expect(parts, hasLength(1));
      expect(parts.single.duration, const Duration(minutes: 40));
    });

    test('الفيديو أو المستند يُرفض قبل أي معالجة', () async {
      final engine = _FakeEngine(const Duration(minutes: 40));
      await expectLater(
        prepare(engine, name: 'lesson.mp4'),
        throwsA(isA<LessonImportException>().having((e) => e.message, 'message', contains('ليس تسجيلاً صوتياً'))),
      );
      expect(engine.calls, isEmpty);
    });

    test('ملف لا يقرؤه المحرّك كصوت: رسالة واضحة ولا شيء يُكتب', () async {
      await expectLater(
        prepare(_FakeEngine(null)),
        throwsA(isA<LessonImportException>().having((e) => e.message, 'message', contains('تعذّر قراءة الملف'))),
      );
      expect(Directory('${dir.path}${Platform.pathSeparator}out').existsSync(), isFalse);
    });

    test('فشل ضغط الجزء الثاني: يُحذف الجزء الأول ولا يبقى نصف درس', () async {
      final engine = _FakeEngine(const Duration(minutes: 150), failingCalls: {2});
      await expectLater(
        prepare(engine),
        throwsA(isA<LessonImportException>().having((e) => e.message, 'message', contains('الجزء 2 من 3'))),
      );
      expect(Directory('${dir.path}${Platform.pathSeparator}out').listSync(), isEmpty);
    });

    test('ناتج أكبر من حد الأرشيف لا يمرّ ويُحذف', () async {
      // 25MB لجزء من ثلاث دقائق: المحرّك لم يضغط كما يجب
      final engine = _FakeEngine(const Duration(minutes: 3), bytesPerSecond: 140000);
      await expectLater(
        prepare(engine),
        throwsA(isA<LessonImportException>().having((e) => e.message, 'message', contains('${MediaLimits.maxFileMbLabel} ميغابايت'))),
      );
      expect(Directory('${dir.path}${Platform.pathSeparator}out').listSync(), isEmpty);
    });

    test('بقية لا تبلغ ثانية (مدة مقدَّرة أطول من الحقيقة) لا تصير جزءاً', () async {
      final engine = _FakeEngine(
        const Duration(minutes: 125),
        actualWrites: {3: const Duration(milliseconds: 400)},
      );
      final parts = await prepare(engine);
      expect(parts, hasLength(2));
      expect(Directory('${dir.path}${Platform.pathSeparator}out').listSync(), hasLength(2));
    });
  });

  // ويندوز: الضغط الحقيقي بمحوّل الوسائط المدمج، على ملف WAV كما يسلّمه مسجّل صوت.
  group('ضغط حقيقي على ويندوز', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mihrab_import_real'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'WAV ستيريو 44.1kHz يتحول إلى أجزاء m4a أحادية مضغوطة بالمدة الصحيحة، وأصله سليم',
      () async {
        // مجلد بمسافة وحروف عربية كمجلدات المستخدمين الحقيقية
        final sub = Directory('${dir.path}${Platform.pathSeparator}تسجيلات الدرس')..createSync();
        final wav = _writeWav('${sub.path}${Platform.pathSeparator}lesson.wav', seconds: 25);
        final originalSize = wav.lengthSync();

        final parts = await LessonAudioImporter.prepare(
          sourcePath: wav.path,
          sourceName: 'lesson.wav',
          outDir: '${dir.path}${Platform.pathSeparator}out',
          outPrefix: 'lesson_real',
          // حد مصغّر ليمرّ المسار كله بثلاثة أجزاء بدل ساعات من الصوت
          partLimit: const Duration(seconds: 10),
          tailFold: Duration.zero,
        );

        expect(parts, hasLength(3));
        for (var i = 0; i < parts.length; i++) {
          final expected = [10, 10, 5][i];
          expect(parts[i].duration.inMilliseconds, inInclusiveRange(expected * 1000 - 1500, expected * 1000 + 1500), reason: 'part ${i + 1}');
          expect(parts[i].path, endsWith('.m4a'));
          // 32kbps ≈ 4000 بايت/ثانية: مضغوط فعلاً (الأصل 176400 بايت/ثانية) ومشفَّر فعلاً
          final perSecond = parts[i].bytes / parts[i].duration.inSeconds;
          expect(perSecond, inInclusiveRange(2400, 6500), reason: 'part ${i + 1} bytes/s');
        }
        expect(parts.fold<int>(0, (a, p) => a + p.bytes), lessThan(originalSize ~/ 20));
        expect(wav.existsSync(), isTrue);
        expect(wav.lengthSync(), originalSize);
      },
      skip: !Platform.isWindows,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'ملف m4a مضغوط أصلاً يُعاد ضغطه بالإعدادات نفسها كجزء واحد',
      () async {
        final wav = _writeWav('${dir.path}${Platform.pathSeparator}in.wav', seconds: 12);
        final first = await LessonAudioImporter.prepare(
          sourcePath: wav.path,
          sourceName: 'in.wav',
          outDir: '${dir.path}${Platform.pathSeparator}one',
          outPrefix: 'a',
        );
        final again = await LessonAudioImporter.prepare(
          sourcePath: first.single.path,
          sourceName: 'a_p1.m4a',
          outDir: '${dir.path}${Platform.pathSeparator}two',
          outPrefix: 'b',
        );

        expect(again, hasLength(1));
        expect(again.single.duration.inMilliseconds, inInclusiveRange(10500, 13500));
        expect(File(first.single.path).existsSync(), isTrue);
      },
      skip: !Platform.isWindows,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'ملف ليس صوتاً (مجرد بايتات) يُرفض برسالة ولا يترك شيئاً',
      () async {
        final fake = File('${dir.path}${Platform.pathSeparator}notes.mp3')..writeAsBytesSync(List.filled(4096, 65));
        await expectLater(
          LessonAudioImporter.prepare(
            sourcePath: fake.path,
            sourceName: 'notes.mp3',
            outDir: '${dir.path}${Platform.pathSeparator}out',
            outPrefix: 'x',
          ),
          throwsA(isA<LessonImportException>()),
        );
        final out = Directory('${dir.path}${Platform.pathSeparator}out');
        expect(!out.existsSync() || out.listSync().isEmpty, isTrue);
      },
      skip: !Platform.isWindows,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
