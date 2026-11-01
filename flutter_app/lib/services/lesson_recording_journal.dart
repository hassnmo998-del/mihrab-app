import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telegram_media_resolver.dart';

/// التسجيل الجاري، محفوظ على القرص منذ لحظة بدئه.
class ActiveLessonRecording {
  final String eventId;
  final String path;
  final int part;
  final String title;
  final String speaker;
  final int seconds;

  const ActiveLessonRecording({
    required this.eventId,
    required this.path,
    required this.part,
    required this.title,
    required this.speaker,
    required this.seconds,
  });

  ActiveLessonRecording withSeconds(int s) => ActiveLessonRecording(
        eventId: eventId,
        path: path,
        part: part,
        title: title,
        speaker: speaker,
        seconds: s,
      );

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'path': path,
        'part': part,
        'title': title,
        'speaker': speaker,
        'seconds': seconds,
      };

  static ActiveLessonRecording? fromJson(Map<String, dynamic> j) {
    final eventId = j['eventId'];
    final path = j['path'];
    if (eventId is! String || path is! String) return null;
    return ActiveLessonRecording(
      eventId: eventId,
      path: path,
      part: (j['part'] as num?)?.toInt() ?? 1,
      title: j['title'] as String? ?? '',
      speaker: j['speaker'] as String? ?? '',
      seconds: (j['seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// نتيجة محاولة إنقاذ تسجيل لم يُختم.
enum RecordingRecovery {
  /// لا شيء ينتظر.
  none,

  /// حُفظ ودخل طابور الرفع.
  recovered,

  /// الملف فارغ أو غير موجود.
  empty,

  /// الملف موجود لكنه لا يُفتح (أُغلق التطبيق قبل أن يُختم ملف m4a). يبقى على الجهاز.
  unreadable,

  /// أكبر من حد الأرشيف، أو لم يُضغط، أو لا يُسمح بأرشفته. يبقى على الجهاز.
  kept,
}

/// يحفظ «أي تسجيل يجري الآن» كي لا يضيع درس إن أُغلق التطبيق أو تُركت الشاشة بلا ختام:
/// عند الفتح التالي (أو فور مغادرة الشاشة) يُختم ويدخل طابور الرفع وحده.
class LessonRecordingJournal {
  LessonRecordingJournal._();

  static const String storageKey = 'active_lesson_recording';

  static bool _recovering = false;

  static Future<void> begin(ActiveLessonRecording rec) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(rec.toJson()));
    } catch (e) {
      debugPrint('⚠️ تعذّر حفظ سجل التسجيل الجاري: $e');
    }
  }

  /// يحدّث المدة المسجّلة (تُكتب كل بضع ثوانٍ، لا كل ثانية).
  static Future<void> updateSeconds(String path, int seconds) async {
    if (kIsWeb) return;
    final current = await read();
    if (current == null || current.path != path) return;
    await begin(current.withSeconds(seconds));
  }

  static Future<ActiveLessonRecording?> read() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      return ActiveLessonRecording.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }

  /// يختم تسجيلاً بقي بلا ختام ويضعه في طابور الرفع.
  ///
  /// [finalize] يؤرشف الجلسة ويعيد معرّف سجل الأرشيف (`DataService.finalizeLiveSession`).
  /// [compress] لملفات WAV (ويندوز).
  static Future<RecordingRecovery> recover({
    required String? Function(String eventId, int part) finalize,
    required Future<void> Function({
      required String eventId,
      required String title,
      required String speaker,
      required String filePath,
      required int durationSeconds,
    }) enqueue,
    Future<String?> Function(String wavPath)? compress,
  }) async {
    if (kIsWeb || _recovering) return RecordingRecovery.none;
    _recovering = true;
    try {
      final rec = await read();
      if (rec == null) return RecordingRecovery.none;

      final file = File(rec.path);
      if (!file.existsSync() || file.lengthSync() < 1024) {
        await clear();
        return RecordingRecovery.empty;
      }

      var path = rec.path;
      final lower = path.toLowerCase();
      if (lower.endsWith('.wav')) {
        repairWavSizes(file);
        final compressed = compress == null ? path : await compress(path);
        if (compressed == null) {
          await clear();
          return RecordingRecovery.kept;
        }
        path = compressed;
      } else if (lower.endsWith('.m4a') && !hasMp4Index(file)) {
        await clear();
        return RecordingRecovery.unreadable;
      }

      if (File(path).lengthSync() > MediaLimits.maxFileBytes) {
        await clear();
        return RecordingRecovery.kept;
      }

      final archiveId = finalize(rec.eventId, rec.part);
      if (archiveId == null) {
        await clear();
        return RecordingRecovery.kept;
      }

      await enqueue(
        eventId: archiveId,
        title: rec.part > 1 ? '${rec.title} — الجزء ${rec.part}' : rec.title,
        speaker: rec.speaker,
        filePath: path,
        durationSeconds: rec.seconds,
      );
      await clear();
      return RecordingRecovery.recovered;
    } catch (e) {
      debugPrint('⚠️ تعذّر إنقاذ التسجيل غير المختوم: $e');
      return RecordingRecovery.none;
    } finally {
      _recovering = false;
    }
  }

  /// ملف m4a يُكتب فهرسه (`moov`) عند ختمه فقط؛ ملف بلا فهرس لا يفتحه أي مشغّل.
  @visibleForTesting
  static bool hasMp4Index(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final length = raf.lengthSync();
      var pos = 0;
      for (var i = 0; i < 64 && pos + 8 <= length; i++) {
        raf.setPositionSync(pos);
        final header = raf.readSync(16);
        if (header.length < 8) break;
        final view = ByteData.sublistView(header);
        var size = view.getUint32(0);
        final type = String.fromCharCodes(header.sublist(4, 8));
        if (type == 'moov') return true;
        if (size == 1) {
          if (header.length < 16) break;
          size = view.getUint64(8);
        } else if (size == 0) {
          break; // يمتد إلى آخر الملف
        }
        if (size < 8) break;
        pos += size;
      }
    } catch (_) {
      return false;
    } finally {
      raf?.closeSync();
    }
    return false;
  }

  /// مسجّل ويندوز يكتب أحجام ترويسة WAV عند الإيقاف فقط؛ إن أُغلق التطبيق قبله تبقى
  /// الأحجام خاطئة. تُصحَّح من طول الملف. يعيد true إن وُجدت ترويسة صالحة.
  @visibleForTesting
  static bool repairWavSizes(File file) {
    RandomAccessFile? raf;
    try {
      raf = file.openSync(mode: FileMode.append);
      final length = raf.lengthSync();
      if (length < 44) return false;
      raf.setPositionSync(0);
      final head = raf.readSync(12);
      if (String.fromCharCodes(head.sublist(0, 4)) != 'RIFF' ||
          String.fromCharCodes(head.sublist(8, 12)) != 'WAVE') {
        return false;
      }
      var pos = 12;
      for (var i = 0; i < 16 && pos + 8 <= length; i++) {
        raf.setPositionSync(pos);
        final chunk = raf.readSync(8);
        final id = String.fromCharCodes(chunk.sublist(0, 4));
        final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
        if (id == 'data') {
          final dataSize = length - pos - 8;
          final riff = ByteData(4)..setUint32(0, length - 8, Endian.little);
          final data = ByteData(4)..setUint32(0, dataSize, Endian.little);
          raf.setPositionSync(4);
          raf.writeFromSync(riff.buffer.asUint8List());
          raf.setPositionSync(pos + 4);
          raf.writeFromSync(data.buffer.asUint8List());
          return true;
        }
        pos += 8 + size + (size.isOdd ? 1 : 0);
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      raf?.closeSync();
    }
  }
}
