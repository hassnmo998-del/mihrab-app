import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/quran_audio_service.dart';
import 'package:flutter_app/services/quran_service.dart';

/// القرآن السماعي: النطاق × تكرار كل آية × الإيقاف التلقائي، بكل تركيباتها، على
/// تسلسل الآيات الحقيقي في المصحف (لا مشغّل صوت: كل آية «تنتهي» حين يطلب الاختبار).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final audio = QuranAudioService.instance;
  final played = <String>[];

  setUpAll(() async {
    await QuranService.ensureLoaded();
  });

  setUp(() async {
    played.clear();
    audio.debugPlay = (tag) async => played.add(tag.key);
    await audio.stop();
    await audio.setScope(QuranRepeatScope.quran);
    audio.setRepeatCount(1);
    audio.setStopAfter(QuranStopAfter.never);
    await audio.setSpeed(1.0);
  });

  tearDown(() async {
    await audio.stop();
    audio.debugPlay = null;
    await audio.setScope(QuranRepeatScope.quran);
    audio.setRepeatCount(1);
    audio.setStopAfter(QuranStopAfter.never);
  });

  /// ينهي الآية الجارية [times] مرة (أو حتى تتوقف التلاوة) ويعيد ما شُغّل منذ البداية.
  Future<List<String>> finish(int times) async {
    for (var i = 0; i < times && audio.isPlayingNotifier.value; i++) {
      audio.debugCompleteCurrent();
      await Future<void>.delayed(Duration.zero);
    }
    return List.of(played);
  }

  Future<void> start(
    int surah,
    int ayah, {
    required QuranRepeatScope scope,
    required int repeat,
    required QuranStopAfter stop,
  }) async {
    // بداية نظيفة: تغيير النطاق والآية الجارية نشطة يعيد تشغيلها، وهذا يُختبر وحده
    await audio.stop();
    played.clear();
    await audio.setScope(scope);
    audio.setRepeatCount(repeat);
    audio.setStopAfter(stop);
    await audio.playAyah(surah, ayah);
  }

  List<String> keysOfPage(int page) =>
      [for (final a in QuranService.getPage(page)!.ayahs) '${a.surahNumber}:${a.ayahNumberInSurah}'];

  group('الحالة المبلَّغ عنها', () {
    test('نطاق «هذه الآية» + 3 مرات: تُتلى ثلاثاً ثم تقف، أياً كان خيار الإيقاف', () async {
      for (final stop in QuranStopAfter.values) {
        played.clear();
        await start(2, 255, scope: QuranRepeatScope.ayah, repeat: 3, stop: stop);
        final result = await finish(10);

        expect(result, ['2:255', '2:255', '2:255'], reason: '$stop');
        expect(audio.isPlayingNotifier.value, isFalse, reason: '$stop');
        expect(audio.activeAyahNotifier.value, isNull, reason: '$stop');
      }
    });

    test('ما كان يُراد: كل آية ثلاث مرات ثم التي بعدها بلا توقف (نطاق القرآن + لا تتوقف)', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 3, stop: QuranStopAfter.never);
      final result = await finish(11);

      expect(result, [
        '1:1', '1:1', '1:1',
        '1:2', '1:2', '1:2',
        '1:3', '1:3', '1:3',
        '1:4', '1:4', '1:4',
      ]);
      expect(audio.isPlayingNotifier.value, isTrue);
    });
  });

  group('تكرار كل آية', () {
    for (final count in QuranAudioService.repeatCounts.where((c) => c > 0)) {
      test('$count: كل آية تُتلى $count مرة بالضبط قبل الانتقال', () async {
        await start(1, 1, scope: QuranRepeatScope.page, repeat: count, stop: QuranStopAfter.never);
        final result = await finish(count * 7 - 1);

        expect(result, [
          for (final key in keysOfPage(1))
            for (var i = 0; i < count; i++) key,
        ]);
      });
    }

    test('بلا نهاية: الآية نفسها تُعاد ولا تنتقل ولا تقف، في كل نطاق ومع كل خيار إيقاف', () async {
      for (final scope in QuranRepeatScope.values) {
        for (final stop in QuranStopAfter.values) {
          played.clear();
          await start(36, 1, scope: scope, repeat: -1, stop: stop);
          final result = await finish(25);

          expect(result.toSet(), {'36:1'}, reason: '$scope $stop');
          expect(result, hasLength(26), reason: '$scope $stop');
          expect(audio.isPlayingNotifier.value, isTrue, reason: '$scope $stop');
        }
      }
    });

    test('تغيير العدد أثناء التلاوة يبدأ العدّ من جديد للآية الجارية', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 5, stop: QuranStopAfter.never);
      await finish(2); // شُغّلت ثلاث مرات حتى الآن
      audio.setRepeatCount(2);
      final result = await finish(2);

      expect(result, ['1:1', '1:1', '1:1', '1:1', '1:2']);
    });

    test('«التالي» و«السابق» يبدآن تكرار الآية الجديدة من أوله', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 3, stop: QuranStopAfter.never);
      await finish(1); // 1:1 مرتين
      await audio.skipNext();
      await finish(3);
      expect(played, ['1:1', '1:1', '1:2', '1:2', '1:2', '1:3']);

      played.clear();
      await audio.skipPrevious();
      await finish(3);
      expect(played, ['1:2', '1:2', '1:2', '1:3']);
    });

    test('الإيقاف المؤقت والمتابعة لا يضيّعان العدّ', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 3, stop: QuranStopAfter.never);
      await finish(1);
      await audio.pause();
      await audio.resume();
      final result = await finish(2);

      expect(result.where((k) => k == '1:1'), hasLength(3));
      expect(result.last, '1:2');
    });
  });

  group('النطاق', () {
    test('هذه الصفحة + لا تتوقف: تُتلى الصفحة ثم تُعاد من أولها (مرة لكل آية لا أكثر)', () async {
      final page = QuranService.getPageForAyah(2, 6)!;
      final keys = keysOfPage(page);
      await start(2, 6, scope: QuranRepeatScope.page, repeat: 1, stop: QuranStopAfter.never);
      final result = await finish(keys.length * 2);

      final fromStart = keys.sublist(keys.indexOf('2:6'));
      expect(result.take(fromStart.length), fromStart);
      // بعدها الصفحة كاملة من أولها
      expect(result.skip(fromStart.length).take(keys.length), keys);
      expect(audio.isPlayingNotifier.value, isTrue);
    });

    test('هذه الصفحة + تكرار 3: كل آية ثلاثاً والصفحة لا تتضاعف (كانت تُعاد ثلاث مرات فوقها)', () async {
      final keys = keysOfPage(1);
      await start(1, 1, scope: QuranRepeatScope.page, repeat: 3, stop: QuranStopAfter.surah);
      final result = await finish(200);

      expect(result, [
        for (final key in keys)
          for (var i = 0; i < 3; i++) key,
      ]);
      expect(audio.isPlayingNotifier.value, isFalse);
    });

    test('هذه الصفحة مع حدّ إيقاف: تقف عند آخر الصفحة ولا تتعداها', () async {
      final page = QuranService.getPageForAyah(2, 30)!;
      final keys = keysOfPage(page);
      for (final stop in [QuranStopAfter.surah, QuranStopAfter.juz]) {
        played.clear();
        await start(2, 30, scope: QuranRepeatScope.page, repeat: 1, stop: stop);
        final result = await finish(200);

        expect(result, keys.sublist(keys.indexOf('2:30')), reason: '$stop');
        expect(audio.isPlayingNotifier.value, isFalse, reason: '$stop');
      }
    });

    test('هذا الجزء + لا تتوقف: ينتقل بين صفحاته ثم يعود إلى أوله', () async {
      // الجزء الثلاثون: من 78:1 إلى 114:6
      await start(114, 1, scope: QuranRepeatScope.juz, repeat: 1, stop: QuranStopAfter.never);
      final result = await finish(8);

      expect(result.take(6), ['114:1', '114:2', '114:3', '114:4', '114:5', '114:6']);
      expect(result[6], '78:1');
      expect(result[7], '78:2');
    });

    test('القرآن كاملاً + لا تتوقف: بعد آخر آية يعود إلى الفاتحة', () async {
      await start(114, 5, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.never);
      final result = await finish(3);

      expect(result, ['114:5', '114:6', '1:1', '1:2']);
    });

    test('الانتقال من صفحة إلى التي بعدها داخل النطاق', () async {
      final lastOfPage1 = keysOfPage(1).last;
      final firstOfPage2 = keysOfPage(2).first;
      await start(1, 7, scope: QuranRepeatScope.quran, repeat: 2, stop: QuranStopAfter.never);
      final result = await finish(3);

      expect(result, [lastOfPage1, lastOfPage1, firstOfPage2, firstOfPage2]);
      expect(audio.activePageNotifier.value, 2);
    });

    test('تغيير النطاق أثناء التلاوة يُبقي الآية الجارية ويطبّق النطاق الجديد', () async {
      await start(1, 3, scope: QuranRepeatScope.quran, repeat: 2, stop: QuranStopAfter.never);
      await audio.setScope(QuranRepeatScope.ayah);
      final result = await finish(10);

      expect(audio.isPlayingNotifier.value, isFalse);
      expect(result.toSet(), {'1:3'});
      // بدأت من جديد بالنطاق الجديد: مرتان ثم وقوف
      expect(result.skip(1), ['1:3', '1:3']);
    });
  });

  group('الإيقاف التلقائي', () {
    test('بعد الآية: تُتمّ تكرارها ثم تقف، في أي نطاق أوسع', () async {
      for (final scope in [QuranRepeatScope.page, QuranRepeatScope.juz, QuranRepeatScope.quran]) {
        played.clear();
        await start(2, 255, scope: scope, repeat: 2, stop: QuranStopAfter.ayah);
        final result = await finish(10);

        expect(result, ['2:255', '2:255'], reason: '$scope');
        expect(audio.isPlayingNotifier.value, isFalse, reason: '$scope');
      }
    });

    test('بعد السورة: تقف عند آخر آية فيها بعد تكرارها، ولو كانت السورة التالية في الصفحة نفسها', () async {
      // الإخلاص والفلق والناس في صفحة واحدة
      await start(112, 3, scope: QuranRepeatScope.quran, repeat: 2, stop: QuranStopAfter.surah);
      final result = await finish(20);

      expect(result, ['112:3', '112:3', '112:4', '112:4']);
      expect(audio.isPlayingNotifier.value, isFalse);
    });

    test('بعد السورة: سورة تمتد على صفحات تُكمل حتى آخرها', () async {
      final total = QuranService.getUthmaniVerses(67).length; // الملك
      await start(67, 1, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.surah);
      final result = await finish(200);

      expect(result, [for (var a = 1; a <= total; a++) '67:$a']);
      expect(audio.isPlayingNotifier.value, isFalse);
    });

    test('بعد الجزء: تقف عند آخر آية في الجزء', () async {
      // آخر الجزء الأول 2:141، وأول الثاني 2:142
      await start(2, 140, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.juz);
      final result = await finish(20);

      expect(result, ['2:140', '2:141']);
      expect(audio.isPlayingNotifier.value, isFalse);
    });

    test('لا تتوقف: تتجاوز حدود السور والأجزاء', () async {
      await start(2, 141, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.never);
      final result = await finish(2);
      expect(result, ['2:141', '2:142', '2:143']);

      played.clear();
      await start(112, 4, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.never);
      expect(await finish(2), ['112:4', '113:1', '113:2']);
    });

    test('أزرار التالي والسابق لا يوقفها حدّ الإيقاف', () async {
      await start(112, 4, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.surah);
      await audio.skipNext();

      expect(audio.activeAyahNotifier.value, '113:1');
      expect(audio.isPlayingNotifier.value, isTrue);
    });
  });

  group('أزرار التشغيل', () {
    test('إيقاف ثم تشغيل: لا شيء يُشغَّل بعد الإيقاف التام', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 1, stop: QuranStopAfter.never);
      await audio.stop();
      played.clear();

      audio.debugCompleteCurrent(); // حدث انتهاء متأخر من المشغّل
      await audio.resume();
      await Future<void>.delayed(Duration.zero);

      expect(played, isEmpty);
      expect(audio.isPlayingNotifier.value, isFalse);
      expect(audio.ayahPassesDone, 0);
    });

    test('حدث انتهاء يصل والتلاوة موقوفة مؤقتاً لا يحرّك شيئاً', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 2, stop: QuranStopAfter.never);
      await audio.pause();
      audio.debugCompleteCurrent();
      await Future<void>.delayed(Duration.zero);

      expect(played, ['1:1']);
      expect(audio.activeAyahNotifier.value, '1:1');
    });

    test('التالي عند آخر آية في المصحف، والسابق عند أولها، لا يخرجان عنه', () async {
      await start(114, 6, scope: QuranRepeatScope.ayah, repeat: 1, stop: QuranStopAfter.never);
      await audio.skipNext();
      expect(audio.activeAyahNotifier.value, '114:6');

      await start(1, 1, scope: QuranRepeatScope.ayah, repeat: 1, stop: QuranStopAfter.never);
      await audio.skipPrevious();
      expect(audio.activeAyahNotifier.value, '1:1');
    });

    test('التالي والسابق يعبران حدود السور والصفحات في نطاق الآية', () async {
      await start(1, 7, scope: QuranRepeatScope.ayah, repeat: 1, stop: QuranStopAfter.never);
      await audio.skipNext();
      expect(audio.activeAyahNotifier.value, '2:1');
      await audio.skipPrevious();
      expect(audio.activeAyahNotifier.value, '1:7');
    });

    test('الضغط على آية أثناء تلاوة غيرها يبدأ منها فوراً', () async {
      await start(1, 1, scope: QuranRepeatScope.quran, repeat: 3, stop: QuranStopAfter.never);
      await finish(1);
      await audio.playAyah(2, 255);
      final result = await finish(2);

      expect(result.skip(2), ['2:255', '2:255', '2:255']);
      expect(audio.activePageNotifier.value, QuranService.getPageForAyah(2, 255));
    });
  });

  group('قرار ما بعد الآية (كل التركيبات)', () {
    QuranAyahAudioTag tag(int surah, int ayah) => QuranAyahAudioTag(
          surahNumber: surah,
          ayahNumber: ayah,
          surahName: QuranService.getSurahName(surah),
          pageNumber: QuranService.getPageForAyah(surah, ayah)!,
        );

    test('لا تركيبة تتلو الآية أقل أو أكثر من عدد تكرارها قبل الانتقال', () {
      for (final scope in QuranRepeatScope.values) {
        for (final stop in QuranStopAfter.values) {
          for (final count in QuranAudioService.repeatCounts.where((c) => c > 0)) {
            for (var done = 1; done <= count; done++) {
              final step = QuranAudioService.afterAyah(
                scope: scope,
                stopAfter: stop,
                repeatCount: count,
                playsDone: done,
                finished: tag(2, 5),
                nextInQueue: tag(2, 6),
              );
              if (done < count) {
                expect(step, QuranAfterAyah.repeatAyah, reason: '$scope $stop $count/$done');
              } else {
                expect(step, isNot(QuranAfterAyah.repeatAyah), reason: '$scope $stop $count/$done');
              }
            }
          }
        }
      }
    });

    test('نهاية النطاق: مع «لا تتوقف» يبدأ من أوله، ومع أي حدّ يقف', () {
      for (final scope in [QuranRepeatScope.page, QuranRepeatScope.juz, QuranRepeatScope.quran]) {
        for (final stop in QuranStopAfter.values) {
          final step = QuranAudioService.afterAyah(
            scope: scope,
            stopAfter: stop,
            repeatCount: 1,
            playsDone: 1,
            finished: tag(114, 6),
          );
          expect(
            step,
            stop == QuranStopAfter.never ? QuranAfterAyah.restartRange : QuranAfterAyah.stop,
            reason: '$scope $stop',
          );
        }
      }
    });
  });
}
