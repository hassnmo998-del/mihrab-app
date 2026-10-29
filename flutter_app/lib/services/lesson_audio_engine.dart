import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'telegram_media_resolver.dart';
import 'windows_audio_compressor.dart';

/// ما يفعله الجهاز بملف صوتي جاهز: قياس مدته وضغط جزء منه بإعدادات تسجيل الدرس نفسها
/// (AAC أحادي، 16kHz، 32kbps). أندرويد يستعمل مفكّكات النظام (`AudioTranscoder.kt`)،
/// وويندوز محوّل الوسائط المدمج ([WindowsAudioCompressor]).
abstract class LessonAudioEngine {
  /// مدة الملف، أو null إن لم يُقرأ كصوت.
  Future<Duration?> probe(String path);

  /// يضغط [start] .. [start] + [length] من [input] إلى [output] (.m4a) ويعيد مدة ما كُتب،
  /// أو null إن تعذّر (ولا يبقى شيء في [output]). [length] بلا قيمة: حتى نهاية الملف.
  /// ملف المستخدم الأصلي لا يُمسّ أبداً.
  Future<Duration?> compress(
    String input,
    String output, {
    Duration start = Duration.zero,
    Duration? length,
  });
}

class PlatformLessonAudioEngine implements LessonAudioEngine {
  const PlatformLessonAudioEngine();

  static const MethodChannel _channel = MethodChannel('com.masjed.mihrab/audio_transcoder');

  /// المنصات التي يعمل عليها ضغط الصوت: التطبيق على أندرويد وويندوز (المتصفح لا يكتب ملفات).
  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  @override
  Future<Duration?> probe(String path) async {
    if (kIsWeb) return null;
    if (Platform.isWindows) return WindowsAudioCompressor.probe(path);
    if (!Platform.isAndroid) return null;
    try {
      final ms = await _channel.invokeMethod<int>('durationMs', {'path': path});
      return ms == null || ms <= 0 ? null : Duration(milliseconds: ms);
    } catch (e) {
      debugPrint('⚠️ قراءة مدة الصوت فشلت: $e');
      return null;
    }
  }

  @override
  Future<Duration?> compress(
    String input,
    String output, {
    Duration start = Duration.zero,
    Duration? length,
  }) async {
    if (kIsWeb) return null;
    if (Platform.isWindows) {
      return WindowsAudioCompressor.transcode(input, output, start: start, length: length);
    }
    if (!Platform.isAndroid) return null;
    try {
      final ms = await _channel.invokeMethod<int>('transcode', {
        'input': input,
        'output': output,
        'bitRate': MediaLimits.recordingBitRate,
        'sampleRate': MediaLimits.recordingSampleRate,
        'startMs': start.inMilliseconds,
        'maxMs': length?.inMilliseconds ?? -1,
      });
      return ms == null ? null : Duration(milliseconds: ms);
    } catch (e) {
      debugPrint('⚠️ ضغط الصوت فشل: $e');
      try {
        final partial = File(output);
        if (partial.existsSync()) partial.deleteSync();
      } catch (_) {}
      return null;
    }
  }
}
