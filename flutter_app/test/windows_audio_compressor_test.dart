import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/telegram_media_resolver.dart';
import 'package:flutter_app/services/windows_audio_compressor.dart';

/// A 16-bit PCM WAV like the Windows recorder produces (its default is 44.1kHz stereo).
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
  data.setUint16(20, 1, Endian.little); // PCM
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
  test(
    'Windows compressor turns a WAV recording into a small .m4a (≈14MB per hour)',
    () async {
      final dir = Directory.systemTemp.createTempSync('mihrab_compress_test');
      try {
        // Real user folders can contain spaces and Arabic letters.
        final sub = Directory('${dir.path}${Platform.pathSeparator}دروس المسجد')..createSync();
        final wav = _writeWav('${sub.path}${Platform.pathSeparator}lesson_test.wav');
        final out = await WindowsAudioCompressor.compress(wav.path);

        expect(out, isNotNull);
        expect(out, endsWith('.m4a'));
        expect(wav.existsSync(), isFalse, reason: 'the WAV is deleted after a successful compress');

        final bytes = File(out!).lengthSync();
        final bytesPerHour = bytes * 3600 ~/ 20;
        expect(bytesPerHour, lessThan(MediaLimits.maxFileBytes));
        expect(bytesPerHour, greaterThan(8 * 1024 * 1024), reason: 'sanity: real audio was encoded');
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
