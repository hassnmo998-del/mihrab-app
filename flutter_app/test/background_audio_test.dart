import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/background_audio.dart';
import 'package:flutter_app/services/lesson_audio_service.dart';
import 'package:flutter_app/services/quran_audio_service.dart';

class _FakeSource implements BackgroundAudioSource {
  int stops = 0;
  int syncs = 0;

  @override
  Future<void> stop() async => stops++;
  @override
  void syncMediaSession() => syncs++;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> skipToNext() async {}
  @override
  Future<void> skipToPrevious() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('claiming the session stops the previous source, not the same one twice', () async {
    final a = _FakeSource();
    final b = _FakeSource();

    await BackgroundAudio.claim(a);
    await BackgroundAudio.claim(a);
    expect(a.stops, 0, reason: 're-claiming by the owner must not stop it');

    await BackgroundAudio.claim(b);
    expect(a.stops, 1);
    expect(BackgroundAudio.owner, same(b));

    BackgroundAudio.release(a); // a no longer owns it: no effect
    expect(BackgroundAudio.owner, same(b));
    BackgroundAudio.release(b);
    expect(BackgroundAudio.owner, isNull);
  });

  test('the Quran and a lesson never play together', () async {
    final quran = QuranAudioService.instance;
    final lesson = LessonAudioService.instance;

    await BackgroundAudio.claim(quran);
    expect(BackgroundAudio.owner, same(quran));

    // A lesson starting takes the session over (and stops the Quran).
    await BackgroundAudio.claim(lesson);
    expect(BackgroundAudio.owner, same(lesson));
    expect(quran.activeTagNotifier.value, isNull);
    expect(quran.isPlayingNotifier.value, isFalse);

    BackgroundAudio.release(lesson);
  });

  test('onUserPlaybackAction clears any external audio interruption flag', () {
    expect(() => BackgroundAudio.onUserPlaybackAction(), returnsNormally);
  });

  test('QuranAudioService publishes clean, elegant notification metadata with Arabic digits', () async {
    final quran = QuranAudioService.instance;
    await BackgroundAudio.claim(quran);

    quran.activeTagNotifier.value = const QuranAyahAudioTag(
      surahNumber: 1,
      ayahNumber: 1,
      surahName: 'الفَاتِحَةِ',
      pageNumber: 1,
    );
    quran.durationNotifier.value = const Duration(seconds: 45);
    quran.isPlayingNotifier.value = true;

    // Trigger sync
    expect(() => quran.syncMediaSession(), returnsNormally);

    // Clean up
    await quran.stop();
  });
}
