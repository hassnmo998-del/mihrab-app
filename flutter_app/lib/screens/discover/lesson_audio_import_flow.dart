import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/app_notification_service.dart';
import '../../services/data_service.dart';
import '../../services/lesson_audio_engine.dart';
import '../../services/lesson_audio_importer.dart';
import 'sheikh_live_lesson_screen.dart';

/// ملف اختاره المستخدم.
class PickedLessonFile {
  final String path;
  final String name;
  const PickedLessonFile(this.path, this.name);
}

/// رفع تسجيل درس جاهز من ملف صوتي، لمن سجّل الدرس بجهاز آخر ويضع ملفه على الهاتف الذي
/// عليه صلاحية الأرشفة. يمرّ بقواعد التسجيل المباشر نفسها ([LessonAudioImporter]): صوت
/// فقط، ضغط 32kbps، جزء الساعة، حد حجم الأرشيف. وينتهي بما ينتهي به التسجيل المباشر:
/// الدرس يُؤرشف وكل جزء يدخل طابور الرفع بسجله.
class LessonAudioImportFlow {
  LessonAudioImportFlow._();

  static bool _busy = false;

  /// يفتح منتقي الملفات فوراً مفلتراً على الصوت. على أندرويد منتقي الصوت في النظام، وعلى
  /// ويندوز قائمة أنواع الصوت المقبولة (مرشح «الصوت» المدمج لا يضم m4a وflac وwma كلها).
  static Future<PickedLessonFile?> pickFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'اختر التسجيل الصوتي للدرس',
      type: Platform.isAndroid ? FileType.audio : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : LessonAudioImporter.audioExtensions.toList(),
      allowMultiple: false,
    );
    final file = result?.files.firstOrNull;
    if (file == null || file.path == null) return null;
    return PickedLessonFile(file.path!, file.name);
  }

  /// [picker] و[engine] و[outDir] للاختبارات فقط.
  static Future<void> start(
    BuildContext context,
    DataService data,
    CommunityEvent event, {
    Future<PickedLessonFile?> Function()? picker,
    LessonAudioEngine? engine,
    String? outDir,
  }) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    void say(String message, {bool error = false}) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: error ? Colors.redAccent[700] : AppColors.emeraldPrimary,
            duration: Duration(seconds: error ? 6 : 5),
          ),
        );
    }

    // المتصفح (نسخة الآيفون) لا يكتب ملفات ولا يضغط صوتاً
    if (engine == null && !PlatformLessonAudioEngine.isSupported) {
      say('رفع التسجيلات متاح من تطبيق أندرويد أو ويندوز');
      return;
    }
    // الحاجز نفسه الذي في شاشة التسجيل: القسم النسائي لا يؤرشف أبداً
    if (!data.canRecordArchive || data.branchOfMosque(event.mosqueId) == 'female') {
      say('تسجيل الدروس وأرشفتها غير متاح للقسم النسائي', error: true);
      return;
    }

    _busy = true;
    var dialogOpen = false;
    final status = ValueNotifier<String>('جاري قراءة التسجيل...');
    try {
      final PickedLessonFile? picked;
      try {
        picked = await (picker ?? pickFile)();
      } catch (e) {
        say('تعذّر اختيار الملف: $e', error: true);
        return;
      }
      if (picked == null || !navigator.mounted) return;

      unawaited(showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => _BusyDialog(status: status),
      ));
      dialogOpen = true;
      unawaited(AppNotificationService.instance.setKeepScreenOn(true));

      final docs = outDir ??
          '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}pending_uploads';
      final List<ImportedLessonPart> parts;
      try {
        parts = await LessonAudioImporter.prepare(
          sourcePath: picked.path,
          sourceName: picked.name,
          outDir: docs,
          outPrefix: 'lesson_${event.id}_${DateTime.now().millisecondsSinceEpoch}',
          engine: engine ?? const PlatformLessonAudioEngine(),
          partLimit: SheikhLiveLessonScreen.partLimit,
          onPart: (part, total) {
            status.value = total > 1 ? 'جاري ضغط الجزء $part من $total...' : 'جاري ضغط التسجيل...';
          },
        );
      } on LessonImportException catch (e) {
        navigator.pop();
        dialogOpen = false;
        if (navigator.mounted) await _showProblem(navigator.context, e.message);
        return;
      }

      status.value = 'جاري حفظ التسجيل في مكتبة الدروس...';
      var queued = 0;
      for (final part in parts) {
        // كل جزء سجل أرشيف مستقل كما في التسجيل المباشر («— الجزء n» من الثاني)
        final archiveId = data.finalizeLiveSession(event.id, part: part.number);
        if (archiveId == null) break;
        await data.audioUploadQueue.addToQueue(
          eventId: archiveId,
          title: part.number > 1 ? '${event.title} — الجزء ${part.number}' : event.title,
          speaker: event.organizerName,
          filePath: part.path,
          durationSeconds: part.duration.inSeconds,
        );
        queued++;
      }
      for (final left in parts.skip(queued)) {
        try {
          File(left.path).deleteSync();
        } catch (_) {}
      }

      navigator.pop();
      dialogOpen = false;
      if (queued == 0) {
        say('تعذّر حفظ التسجيل: لم يعد الدرس موجوداً', error: true);
      } else {
        say(
          queued > 1
              ? 'تم ضغط التسجيل وحفظه في $queued أجزاء ✨ ستُرفع لمكتبة الدروس تلقائياً فور توفر الإنترنت.'
              : 'تم ضغط التسجيل وحفظه ✨ سيُرفع لمكتبة الدروس تلقائياً فور توفر الإنترنت.',
        );
      }
    } finally {
      if (dialogOpen && navigator.mounted) navigator.pop();
      unawaited(AppNotificationService.instance.setKeepScreenOn(false));
      // أندرويد ينسخ الملف المختار إلى مجلد مؤقت للتطبيق (قد يبلغ مئات الميغابايت)
      if (picker == null && !kIsWeb && Platform.isAndroid) {
        try {
          await FilePicker.clearTemporaryFiles();
        } catch (_) {}
      }
      _busy = false;
    }
  }

  static Future<void> _showProblem(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Icon(Icons.error_outline_rounded, color: AppColors.terracottaPrimary, size: 40),
        title: const Text('لم يُرفع التسجيل', textAlign: TextAlign.center),
        content: SelectableText(message, textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
  }
}

class _BusyDialog extends StatelessWidget {
  final ValueListenable<String> status;
  const _BusyDialog({required this.status});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('lessonImportBusy'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            CircularProgressIndicator(color: AppColors.emeraldPrimary),
            const SizedBox(height: 18),
            ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (_, text, __) => Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'يرجى عدم إغلاق التطبيق حتى يكتمل الحفظ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
