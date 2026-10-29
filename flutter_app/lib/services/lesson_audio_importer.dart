import 'dart:io';
import 'package:flutter/foundation.dart';
import 'lesson_audio_engine.dart';
import 'telegram_media_resolver.dart';

/// سبب رفض الملف أو تعذّر تجهيزه، بنص يُعرض للمستخدم كما هو.
class LessonImportException implements Exception {
  final String message;
  const LessonImportException(this.message);

  @override
  String toString() => message;
}

/// قطعة من الملف الأصلي تصير جزءاً من الدرس: [length] بلا قيمة تعني حتى النهاية.
class AudioSlice {
  final Duration start;
  final Duration? length;
  const AudioSlice(this.start, this.length);

  @override
  String toString() => 'AudioSlice($start, $length)';
}

/// جزء جاهز للرفع من تسجيل مستورد.
class ImportedLessonPart {
  final int number;
  final String path;
  final Duration duration;
  final int bytes;
  const ImportedLessonPart({
    required this.number,
    required this.path,
    required this.duration,
    required this.bytes,
  });
}

/// يجهّز تسجيلاً صوتياً أُخذ من خارج التطبيق (مسجّل آخر، هاتف آخر) ليدخل مكتبة الدروس
/// بقواعد التسجيل المباشر نفسها:
///
/// - **النوع**: صوت فقط (لا فيديو ولا مستندات).
/// - **الضغط**: AAC أحادي 16kHz بـ32kbps ([MediaLimits.recordingBitRate])، فتبلغ الساعة نحو
///   14MB مهما كان الملف الأصلي (WAV بمئات الميغابايت أو MP3 عالي الجودة).
/// - **الحد**: الجزء الواحد ساعة على الأكثر ([MediaLimits.maxRecording])؛ الدرس الأطول
///   يُقطَّع إلى أجزاء ساعة، كل جزء سجل أرشيف «— الجزء n» كما لو سُجّل مباشرة.
/// - **الحجم**: ما يتجاوز [MediaLimits.maxFileBytes] بعد الضغط لا يمرّ (لا يُفتح من الأرشيف).
class LessonAudioImporter {
  LessonAudioImporter._();

  /// أنواع الصوت المقبولة. مسجّلات الصوت المستقلة تحفظ mp3/wav/wma، وتطبيقات الهاتف
  /// m4a/amr/3gp/ogg/opus. الفيديو (mp4، mkv...) والمستندات مرفوضة.
  static const Set<String> audioExtensions = {
    'mp3', 'm4a', 'aac', 'wav', 'wave', 'ogg', 'oga', 'opus', 'flac', 'wma',
    'amr', 'awb', '3gp', '3ga', 'mka', 'mp2', 'aif', 'aiff', 'aifc',
  };

  /// صوت إن كان امتداده صوتياً. ملف بلا امتداد (بعض أدوات الاختيار على أندرويد لا تعيده)
  /// يقرر المحرّك أمره بقراءة محتواه.
  static bool isAudioFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return true;
    return audioExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  static String get acceptedTypesLabel => 'MP3 و M4A و WAV و AAC و OGG و FLAC و WMA';

  /// يقسم [total] إلى أجزاء لا يزيد الواحد على [limit]. بقية قصيرة بعد آخر جزء كامل (حتى
  /// [tailFold]) تُضمّ إليه: لا يصير «الجزء 2» ثوانيَ معدودة. الجزء الأخير بلا طول محدد
  /// فيأخذ الملف حتى آخره، فلا يضيع منه شيء إن كانت المدة المقدَّرة أقصر من الحقيقة.
  static List<AudioSlice> planParts(
    Duration total, {
    required Duration limit,
    Duration tailFold = const Duration(minutes: 3),
  }) {
    if (total <= limit) return const [AudioSlice(Duration.zero, null)];
    var count = (total.inMicroseconds / limit.inMicroseconds).ceil();
    final tail = total - limit * (count - 1);
    if (count > 1 && tail <= tailFold) count -= 1;
    return [
      for (var i = 0; i < count; i++)
        AudioSlice(limit * i, i == count - 1 ? null : limit),
    ];
  }

  /// يقرأ [sourcePath] ويضغطه إلى أجزاء في [outDir] (تُسمّى `<outPrefix>_p<n>.m4a`).
  /// ملف المستخدم لا يُمسّ. عند أي فشل لا يبقى جزء مكتوب، ويُرمى [LessonImportException].
  static Future<List<ImportedLessonPart>> prepare({
    required String sourcePath,
    required String sourceName,
    required String outDir,
    required String outPrefix,
    LessonAudioEngine engine = const PlatformLessonAudioEngine(),
    Duration? partLimit,
    Duration tailFold = const Duration(minutes: 3),
    void Function(int part, int parts)? onPart,
  }) async {
    final limit = partLimit ?? MediaLimits.maxRecording;

    if (!isAudioFileName(sourceName)) {
      throw LessonImportException(
        'هذا الملف ليس تسجيلاً صوتياً.\nالأنواع المقبولة: $acceptedTypesLabel',
      );
    }
    if (!File(sourcePath).existsSync()) {
      throw const LessonImportException('تعذّر الوصول إلى الملف المختار، اختره من جديد');
    }

    final total = await engine.probe(sourcePath);
    if (total == null || total <= Duration.zero) {
      throw LessonImportException(
        'تعذّر قراءة الملف كتسجيل صوتي.\nجرّب ملفاً بصيغة MP3 أو M4A أو WAV.',
      );
    }

    final slices = planParts(total, limit: limit, tailFold: tailFold);
    await Directory(outDir).create(recursive: true);

    final parts = <ImportedLessonPart>[];
    Future<Never> fail(String message) async {
      for (final part in parts) {
        try {
          File(part.path).deleteSync();
        } catch (_) {}
      }
      throw LessonImportException(message);
    }

    for (var i = 0; i < slices.length; i++) {
      final number = parts.length + 1;
      onPart?.call(number, slices.length);
      final path = '$outDir${Platform.pathSeparator}${outPrefix}_p$number.m4a';
      final slice = slices[i];

      final written = await engine.compress(sourcePath, path, start: slice.start, length: slice.length);
      final file = File(path);
      if (written == null || !file.existsSync()) {
        await fail(
          slices.length > 1
              ? 'تعذّر ضغط التسجيل (الجزء $number من ${slices.length}).\nجرّب ملفاً بصيغة MP3 أو M4A.'
              : 'تعذّر ضغط التسجيل على هذا الجهاز.\nجرّب ملفاً بصيغة MP3 أو M4A.',
        );
      }

      final bytes = file.lengthSync();
      if (written < const Duration(seconds: 1) || bytes <= 0) {
        try {
          file.deleteSync();
        } catch (_) {}
        // بقية لا تبلغ ثانية (المدة المقدَّرة للملف زادت عن الحقيقة) ليست جزءاً من الدرس
        if (parts.isNotEmpty) break;
        await fail('لم يُعثر على صوت في هذا التسجيل');
      }
      if (bytes > MediaLimits.maxFileBytes) {
        try {
          file.deleteSync();
        } catch (_) {}
        await fail(
          'حجم التسجيل ${MediaLimits.formatMb(bytes)} ميغابايت بعد الضغط، والحد الأقصى ${MediaLimits.maxFileMbLabel} ميغابايت',
        );
      }

      debugPrint('🎙️ جزء $number: ${written.inSeconds}s، ${MediaLimits.formatMb(bytes)}MB');
      parts.add(ImportedLessonPart(number: number, path: path, duration: written, bytes: bytes));
    }

    return parts;
  }
}
