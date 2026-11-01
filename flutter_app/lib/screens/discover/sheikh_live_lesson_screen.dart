import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../models/models.dart';
import '../../../services/app_notification_service.dart';
import '../../../services/data_service.dart';
import '../../../services/lesson_recording_guard.dart';
import '../../../services/lesson_recording_journal.dart';
import '../../../services/telegram_media_resolver.dart';
import '../../../services/windows_audio_compressor.dart';

/// ما يختاره الشيخ حين يحاول مغادرة شاشة درس يُسجَّل.
enum _LeaveChoice { stay, save, discard }

class SheikhLiveLessonScreen extends StatefulWidget {
  /// أطول جزء تسجيل قبل أن يُحفظ وحده ويُسأل الشيخ أيتابع. حدّه [MediaLimits.maxRecording]
  /// (ساعة: ملف تقبله أرشفة تيليجرام)؛ يُقصَّر فقط لتجربة المسار كاملاً على جهاز حقيقي.
  static Duration partLimit = MediaLimits.maxRecording;

  final CommunityEvent event;

  const SheikhLiveLessonScreen({
    super.key,
    required this.event,
  });

  @override
  State<SheikhLiveLessonScreen> createState() => _SheikhLiveLessonScreenState();
}

class _SheikhLiveLessonScreenState extends State<SheikhLiveLessonScreen>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AnimationController _pulseController;
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordedFilePath;
  bool _isUploading = false;

  /// النص المعروض أثناء الضغط والأرشفة.
  String _busyMessage = 'جاري أرشفة الدرس الصوتي في السحابة...';
  bool _showUnansweredOnly = false;
  bool _limitWarningShown = false;

  /// رقم الجزء الجاري: الجزء الواحد ساعة على الأكثر ([MediaLimits.maxRecording])، فإن
  /// طال الدرس تابع الشيخ في جزء ثانٍ يُحفظ في المكتبة مستقلاً.
  int _part = 1;

  /// إنهاء جارٍ (يدوي أو عند الحد): يمنع إنهاءً ثانياً من نبضة المؤقت التالية.
  bool _finishing = false;

  /// مستوى الصوت الذي يلتقطه الميكروفون الآن (0..1)، يُعرض شريطاً تحت العدّاد.
  double _level = 0;

  /// الميكروفون لا يلتقط شيئاً منذ [_silenceLimit]: النظام أسكته أو الميكروفون معطّل.
  bool _micSilent = false;
  DateTime? _silentSince;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<RecordState>? _stateSub;

  /// تحت هذا المستوى لا صوت إطلاقاً (ميكروفون أسكته النظام يعطي نحو -160)؛ ضجيج قاعة
  /// هادئة نفسه أعلى منه بكثير، فلا ينبّه سكوت الشيخ بين جملتين.
  static const double _silenceDb = -75;
  static const Duration _silenceLimit = Duration(seconds: 15);

  int get _maxMinutes => SheikhLiveLessonScreen.partLimit.inMinutes;
  late DataService _dataService;

  /// الويندوز يسجّل WAV ثم يُضغط، لأن مرمّز AAC فيه لا ينزل تحت 96kbps.
  bool get _recordsWavThenCompresses => Platform.isWindows;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dataService = context.read<DataService>();
  }

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _listenToRecorder();
  }

  /// يراقب المسجّل نفسه لا الأزرار وحدها: المستوى لكشف ميكروفون صامت، والحالة لاستئناف
  /// تسجيل أوقفه النظام من غير أن يطلبه الشيخ.
  void _listenToRecorder() {
    if (PlatformUtils.isWeb) return;
    try {
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 300))
          .listen(_onAmplitude, onError: (_) {});
      _stateSub = _audioRecorder.onStateChanged().listen((state) {
        if (state == RecordState.pause && _isRecording && !_isPaused && !_finishing) {
          // إيقاف لم يطلبه الشيخ (مقاطعة من النظام): يُستأنف فوراً
          unawaited(_audioRecorder.resume().catchError((_) {}));
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted || !_isRecording || _isPaused) return;
    final db = amp.current.isFinite ? amp.current : -160.0;
    // -60..0 dBFS على شريط من 0 إلى 1
    final level = ((db + 60) / 60).clamp(0.0, 1.0);
    final now = DateTime.now();
    var silent = _micSilent;
    if (db < _silenceDb) {
      _silentSince ??= now;
      if (now.difference(_silentSince!) >= _silenceLimit) silent = true;
    } else {
      _silentSince = null;
      silent = false;
    }
    if (silent && !_micSilent) HapticFeedback.heavyImpact();
    if ((level - _level).abs() > 0.02 || silent != _micSilent) {
      setState(() {
        _level = level;
        _micSilent = silent;
      });
    }
  }

  void _resetMicMonitor() {
    _level = 0;
    _micSilent = false;
    _silentSince = null;
  }

  Future<void> _startForegroundTask() => LessonRecordingGuard.start(widget.event.title);

  Future<void> _stopForegroundTask() => LessonRecordingGuard.stop();

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _amplitudeSub?.cancel();
    _stateSub?.cancel();
    unawaited(AppNotificationService.instance.setKeepScreenOn(false));

    if (widget.event.eventStatus == 'live') {
      // جزء ثانٍ تُرك: الجزء الأول أرشف درس المرة الواحدة، فيبقى مؤرشفاً
      _dataService.changeEventStatus(
        widget.event.id,
        _part > 1 && !widget.event.isRecurring ? 'archived' : 'upcoming',
      );
    }

    final recorder = _audioRecorder;
    if (_isRecording && !_finishing) {
      // الشاشة أُغلقت والتسجيل جارٍ (لا عبر زر الرجوع): لا يضيع الدرس، يُختم ويُرفع
      final data = _dataService;
      unawaited(() async {
        try {
          await recorder.stop();
        } catch (_) {}
        await recorder.dispose();
        await _stopForegroundTask();
        await data.recoverUnfinishedRecording();
      }());
    } else {
      recorder.dispose();
      _stopForegroundTask();
    }

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsElapsed++);
      // المدة تُحفظ مع التسجيل: إن أُغلق التطبيق يُرفع بمدته الصحيحة
      final path = _recordedFilePath;
      if (path != null && _secondsElapsed % 10 == 0) {
        unawaited(LessonRecordingJournal.updateSeconds(path, _secondsElapsed));
      }
      _enforceRecordingLimit();
    });
    _pulseController.repeat(reverse: true);
  }

  /// قبل 5 دقائق من الحد: شريط ظاهر في الشاشة نفسها (لا إشعار يختفي) واهتزاز. عند
  /// الحد: يُحفظ الجزء وحده ويُسأل الشيخ أيتابع أم انتهى الدرس.
  void _enforceRecordingLimit() {
    final max = SheikhLiveLessonScreen.partLimit.inSeconds;
    if (!_limitWarningShown && _secondsElapsed >= max - 5 * 60) {
      _limitWarningShown = true;
      HapticFeedback.mediumImpact();
    }
    if (_isRecording && !_finishing && _secondsElapsed >= max) {
      _finishLesson(auto: true);
    }
  }

  /// الثواني الباقية من الجزء الجاري.
  int get _secondsLeft => SheikhLiveLessonScreen.partLimit.inSeconds - _secondsElapsed;

  void _pauseTimer() {
    _timer?.cancel();
    _pulseController.stop();
  }

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return totalSeconds >= 3600 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    // التسجيل يكتب ملفاً على الجهاز ثم يرفعه؛ المتصفح (نسخة الآيفون) لا يكتب ملفات
    if (PlatformUtils.isWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تسجيل الدروس متاح من تطبيق أندرويد أو ويندوز')),
      );
      return;
    }
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final ext = _recordsWavThenCompresses ? 'wav' : 'm4a';
        final path = '${dir.path}${Platform.pathSeparator}'
            'lesson_${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        // صوت كلام أحادي مضغوط: الساعة ≈ 14MB، تحت حد أرشيف تيليجرام (20MB).
        // audioInterruption: none — الافتراضي في حزمة record يوقف التسجيل عند أي صوت
        // آخر على الجهاز (رنة إشعار، رسالة صوتية، الأذان) ولا يستأنفه أبداً، والعدّاد
        // يكمل فيظن الشيخ أنه يسجّل. الدرس لا يتنازل عن الميكروفون لأي صوت.
        await _audioRecorder.start(
          _recordsWavThenCompresses
              // Windows: the recorder's default format (known to work with laptop mics);
              // the compressor downsamples it to mono 16kHz afterwards.
              ? const RecordConfig(
                  encoder: AudioEncoder.wav,
                  audioInterruption: AudioInterruptionMode.none,
                )
              : const RecordConfig(
                  encoder: AudioEncoder.aacLc,
                  bitRate: MediaLimits.recordingBitRate,
                  sampleRate: MediaLimits.recordingSampleRate,
                  numChannels: 1,
                  audioInterruption: AudioInterruptionMode.none,
                ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordedFilePath = path;
          _resetMicMonitor();
        });
        _startTimer();
        // التسجيل محفوظ منذ بدئه: إن أُغلق التطبيق يُختم ويُرفع عند الفتح التالي
        unawaited(LessonRecordingJournal.begin(ActiveLessonRecording(
          eventId: widget.event.id,
          path: path,
          part: _part,
          title: widget.event.title,
          speaker: widget.event.organizerName,
          seconds: 0,
        )));
        // خدمة أمامية «ميكروفون»: بدونها يُسكت أندرويد الميكروفون حين تُقفل الشاشة
        unawaited(_startForegroundTask());
        // وتبقى الشاشة مضاءة أيضاً، احتياطاً للأجهزة التي تشدّ على التطبيقات بالخلفية
        unawaited(AppNotificationService.instance.setKeepScreenOn(true));

        if (mounted) {
          context.read<DataService>().changeEventStatus(widget.event.id, 'live');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى منح صلاحية استخدام الميكروفون لبدء تسجيل الدرس')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء بدء التسجيل: $e')),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    if (_isRecording && !_isPaused) {
      // تُعلَّم قبل الطلب: حدث «إيقاف» من المسجّل يصل قبل أن ينتهي الطلب، فلا يُستأنف وحده
      _isPaused = true;
      await _audioRecorder.pause();
      _pauseTimer();
      setState(() => _isPaused = true);
    } else if (_isRecording && _isPaused) {
      await _audioRecorder.resume();
      _startTimer();
      setState(() {
        _isPaused = false;
        _silentSince = null;
      });
    }
  }

  Future<void> _stopAndFinishLesson() => _finishLesson();

  /// ينهي الدرس ويؤرشفه. [auto] عند بلوغ الحد الأقصى: بلا سؤال تأكيد، ثم يُسأل الشيخ
  /// أيتابع في جزء ثانٍ. [confirmed]: الشيخ اختار الحفظ من نافذة المغادرة.
  Future<void> _finishLesson({bool auto = false, bool confirmed = false}) async {
    if (_finishing) return;
    if (!auto && !confirmed) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إنهاء الدرس وحفظه بالمكتبة'),
          content: const Text('هل انتهى مجلس العلم بالفعل؟ سيتم حفظ التسجيل ورفعه إلى مكتبة الدروس مع إبقائه في قائمة الدروس.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('متابعة الدرس')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، إنهاء الدرس والحفظ بالمكتبة'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _finishing = true;
    _pauseTimer();
    String? finalPath;
    if (_isRecording) {
      finalPath = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
    }
    unawaited(AppNotificationService.instance.setKeepScreenOn(false));
    finalPath ??= _recordedFilePath;

    if (finalPath == null || !File(finalPath).existsSync()) {
      await LessonRecordingJournal.clear();
      if (mounted) {
        _dataService.finalizeLiveSession(widget.event.id, part: _part);
        Navigator.pop(context);
      }
      return;
    }

    if (_recordsWavThenCompresses) {
      setState(() {
        _isUploading = true;
        _busyMessage = 'جاري ضغط التسجيل...';
      });
      final compressed = await WindowsAudioCompressor.compress(finalPath);
      if (!mounted) {
        // أُغلقت الشاشة أثناء الضغط: التسجيل يُحفظ ويُرفع بلا واجهة
        if (compressed != null) await _queueDetached(compressed);
        return;
      }
      if (compressed == null) {
        setState(() => _isUploading = false);
        await _showArchiveProblem(
          'تعذّر ضغط التسجيل على هذا الجهاز، فلم يُرفع. الملف محفوظ هنا:\n$finalPath',
        );
        return;
      }
      finalPath = compressed;
    }

    final size = File(finalPath).lengthSync();
    if (size > MediaLimits.maxFileBytes) {
      setState(() => _isUploading = false);
      await _showArchiveProblem(
        'حجم التسجيل ${MediaLimits.formatMb(size)} ميغابايت، والحد الأقصى ${MediaLimits.maxFileMbLabel} ميغابايت، فلم يُرفع. الملف محفوظ هنا:\n$finalPath',
      );
      return;
    }

    _stopForegroundTask();
    // التسجيل يُربط بلقطة الأرشيف التي أُنشئت لهذه الجلسة بعينها، لا بالدرس
    // المتكرر: جلستان تنتظران الرفع لا تكتبان على لقطة واحدة.
    final archiveId = _dataService.finalizeLiveSession(widget.event.id, part: _part) ?? widget.event.id;
    final queued = await _addToUploadQueue(File(finalPath), archiveId, closeAfter: !auto);
    if (!auto || !queued || !mounted) return;

    // بلغ الجزء الحد: حُفظ. الشيخ يقرر، والنافذة تبقى حتى يضغط (قد لا ينظر إلى الهاتف)
    final continueRecording = await _showPartSavedDialog();
    if (!mounted) return;
    if (continueRecording) {
      setState(() {
        _part += 1;
        _secondsElapsed = 0;
        _limitWarningShown = false;
        _isUploading = false;
        _finishing = false;
      });
      await _startRecording();
    } else {
      Navigator.pop(context);
      _showSavedSnackBar();
    }
  }

  /// يُعرض عند بلوغ الجزء ساعة: ماذا حدث، وماذا يفعل الآن.
  Future<bool> _showPartSavedDialog() async {
    HapticFeedback.heavyImpact();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(Icons.check_circle_rounded, color: AppColors.emeraldPrimary, size: 44),
          title: Text('اكتملت ساعة التسجيل وحُفظت', textAlign: TextAlign.center),
          content: Text(
            'التسجيل الواحد ساعة على الأكثر، فتوقف التسجيل الآن.\n\n'
            '✅ ${_part == 1 ? 'الساعة الأولى من الدرس' : 'الجزء $_part من الدرس'} محفوظة، '
            'وستُرفع إلى مكتبة الدروس وحدها فور توفر الإنترنت.\n\n'
            'هل ما زال الدرس مستمراً؟ تابع التسجيل في جزء جديد يُحفظ في المكتبة بعد هذا الجزء.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            ElevatedButton.icon(
              key: const ValueKey('continueNextPart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.mic_rounded),
              label: Text('نعم، تابع التسجيل (الجزء ${_part + 1})'),
            ),
            TextButton(
              key: const ValueKey('lessonEndedAtLimit'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا، انتهى الدرس'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _part > 1
              ? 'تم إنهاء الدرس وحفظ أجزائه الـ$_part ✨ ستُرفع لمكتبة الدروس تلقائياً فور توفر الإنترنت.'
              : 'تم إنهاء الدرس وحفظ التسجيل ✨ سيُرفع لمكتبة الدروس تلقائياً فور توفر الإنترنت.',
        ),
        backgroundColor: AppColors.emeraldPrimary,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _showArchiveProblem(String message) async {
    // الملف باقٍ في مكانه والمسار معروض للشيخ: لا يُعاد إنقاذه عند الفتح التالي
    await LessonRecordingJournal.clear();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('لم يُرفع التسجيل'),
        content: SelectableText(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
        ],
      ),
    );
    _dataService.finalizeLiveSession(widget.event.id, part: _part);
    if (mounted) Navigator.pop(context);
  }

  /// حفظ ورفع بعد أن أُغلقت الشاشة (لا `context` ولا `setState`).
  Future<void> _queueDetached(String path) async {
    final archiveId = _dataService.finalizeLiveSession(widget.event.id, part: _part) ?? widget.event.id;
    await _dataService.audioUploadQueue.addToQueue(
      eventId: archiveId,
      title: _part > 1 ? '${widget.event.title} — الجزء $_part' : widget.event.title,
      speaker: widget.event.organizerName,
      filePath: path,
      durationSeconds: _secondsElapsed,
    );
    await LessonRecordingJournal.clear();
  }

  /// يضع التسجيل في طابور الرفع. [closeAfter]: يغلق الشاشة بعدها (إنهاء يدوي)؛ عند حد
  /// الساعة تبقى الشاشة ليُسأل الشيخ. يعيد true إن دخل الطابور.
  Future<bool> _addToUploadQueue(File file, String archiveId, {bool closeAfter = true}) async {
    setState(() {
      _isUploading = true;
      _busyMessage = 'جاري حفظ التسجيل في مكتبة الدروس...';
    });

    try {
      final data = context.read<DataService>();
      await data.audioUploadQueue.addToQueue(
        eventId: archiveId,
        title: _part > 1 ? '${widget.event.title} — الجزء $_part' : widget.event.title,
        speaker: widget.event.organizerName,
        filePath: file.path,
        durationSeconds: _secondsElapsed,
      );
      // دخل الطابور (والطابور محفوظ على القرص): لم يعد تسجيلاً غير مختوم
      await LessonRecordingJournal.clear();

      if (mounted && closeAfter) {
        Navigator.pop(context);
        _showSavedSnackBar();
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.pop(context);
      }
      return false;
    }
  }

  /// الخروج أثناء التسجيل لا يحذف الدرس إلا باختيار صريح ثانٍ: «نعم، الخروج» وحدها كانت
  /// تحذف ملف الدرس كله بضغطة رجوع خاطئة.
  Future<_LeaveChoice> _askLeaveChoice() async {
    // الحفظ جارٍ (ضغط أو دخول الطابور): يكمل وحده بعد إغلاق الشاشة
    if (!_isRecording) return _isUploading ? _LeaveChoice.save : _LeaveChoice.stay;

    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('التسجيل قيد العمل'),
        content: const Text(
          'أنت في منتصف تسجيل مجلس العلم. إن انتهى الدرس احفظه ليُرفع إلى مكتبة الدروس.',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.discard),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('حذف التسجيل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.stay),
            child: const Text('البقاء في الدرس'),
          ),
          ElevatedButton(
            key: const ValueKey('leaveAndSave'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.save),
            child: const Text('إنهاء الدرس وحفظه'),
          ),
        ],
      ),
    );
    if (choice != _LeaveChoice.discard || !mounted) return choice ?? _LeaveChoice.stay;

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف تسجيل الدرس؟'),
        content: Text('سيُحذف ما سُجّل (${_formatTime(_secondsElapsed)}) نهائياً ولن يُرفع إلى المكتبة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، احذفه'),
          ),
        ],
      ),
    );
    return sure == true ? _LeaveChoice.discard : _LeaveChoice.stay;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // حاجز صلب: القسم النسائي لا يسجّل ولا يؤرشف بأي حال، حتى لو وصل لهذه
    // الشاشة من مسار لم يُحدَّث.
    if (!data.canRecordArchive ||
        data.branchOfMosque(widget.event.mosqueId) == 'female') {
      return _RecordingNotPermittedView(isDark: isDark);
    }

    final allQuestions = data.getCurrentEventQuestions(widget.event, forSpeaker: true);
    final displayedQuestions = _showUnansweredOnly
        ? allQuestions.where((q) => !q.isAnswered).toList()
        : allQuestions;

    final backgroundColor = isDark ? AppColors.darkSurface : const Color(0xFFF9F6F0);
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return PopScope(
      canPop: !_isRecording && !_isUploading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final choice = await _askLeaveChoice();
        if (!mounted) return;
        switch (choice) {
          case _LeaveChoice.stay:
            return;
          case _LeaveChoice.save:
            if (_isRecording) {
              // الإنهاء نفسه الذي يجري بزر «ختام وأرشفة المجلس»، وهو يغلق الشاشة
              await _finishLesson(confirmed: true);
            } else {
              nav.pop();
            }
          case _LeaveChoice.discard:
            _finishing = true;
            _pauseTimer();
            final abandoned = await _audioRecorder.stop() ?? _recordedFilePath;
            if (mounted) setState(() => _isRecording = false);
            await LessonRecordingJournal.clear();
            unawaited(_stopForegroundTask());
            unawaited(AppNotificationService.instance.setKeepScreenOn(false));
            if (abandoned != null) {
              try {
                await File(abandoned).delete();
              } catch (_) {}
            }
            nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event.title,
                style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'المحاضر: ${widget.event.organizerName} • إدارة مجلس العلم',
                style: AppTypography.font(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        body: _isUploading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.emeraldPrimary),
              const SizedBox(height: 16),
              Text(
                _busyMessage,
                style: AppTypography.titleBold(context, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'يرجى عدم إغلاق التطبيق حتى اكتمال الأرشفة',
                style: AppTypography.verveSubtitle(context),
              ),
            ],
          ),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;

            final circleSize = (constraints.maxWidth - 48.0).clamp(200.0, 290.0);
            final timerWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    // واجهة تسجيل الصوت
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulseVal = _isRecording && !_isPaused ? _pulseController.value : 0.0;
                        final activeColor = _isPaused
                            ? Colors.amber[700]!
                            : AppColors.emeraldPrimary;

                        return Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardColor,
                            boxShadow: [
                              BoxShadow(
                                color: _isRecording
                                    ? activeColor.withValues(alpha: 0.08 + (pulseVal * 0.12))
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 30 + (pulseVal * 15),
                                spreadRadius: pulseVal * 3,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: _isRecording
                                  ? activeColor.withValues(alpha: 0.35 + (pulseVal * 0.25))
                                  : (isDark ? Colors.white12 : AppColors.gold.withValues(alpha: 0.3)),
                              width: 2,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? (_isPaused
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : AppColors.emeraldPrimary.withValues(alpha: 0.12))
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isRecording
                                        ? (_isPaused ? Colors.amber[700] : AppColors.emeraldPrimary)
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  !_isRecording
                                      ? 'المجلس جاهز للبدء'
                                      : (_isPaused ? 'التسجيل موقوف مؤقتاً' : 'مجلس العلم جارٍ'),
                                  style: GoogleFonts.amiri(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _isRecording
                                        ? (_isPaused
                                        ? (isDark ? Colors.amber[300] : Colors.amber[900])
                                        : (isDark ? const Color(0xFF6EE7B7) : AppColors.emeraldPrimary))
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _formatTime(_secondsElapsed),
                            style: AppTypography.font(
                              fontSize: 48,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ).copyWith(
                              letterSpacing: 2,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _part > 1 ? 'الجزء $_part • من أصل $_maxMinutes دقيقة' : 'من أصل $_maxMinutes دقيقة',
                            style: GoogleFonts.amiri(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isRecording && !_isPaused) ...[
                      const SizedBox(height: 16),
                      _MicLevelMeter(level: _level, silent: _micSilent, isDark: isDark),
                    ],
                    if (_isRecording && !_isPaused && _micSilent) ...[
                      const SizedBox(height: 14),
                      Container(
                        key: const ValueKey('micSilentBanner'),
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mic_off_rounded, color: Colors.red.shade400),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'الميكروفون لا يلتقط أي صوت منذ ${_silenceLimit.inSeconds} ثانية. '
                                'تأكد أن الميكروفون غير مغطّى، وأن تطبيقاً آخر (اتصال أو تسجيل) لا يستعمله.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isRecording && _secondsLeft <= 5 * 60) ...[
                      const SizedBox(height: 18),
                      Container(
                        key: const ValueKey('recordingLimitBanner'),
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, color: Colors.amber.shade800),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'بقي ${_formatTime(_secondsLeft.clamp(0, 5 * 60))} على تمام الساعة. '
                                'عندها يُحفظ هذا الجزء وحده، ويمكنك متابعة الدرس في جزء جديد.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amber.shade200 : Colors.brown.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        if (!_isRecording)
                          ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: const Icon(Icons.mic, size: 20),
                            label: Text(
                              'بدء مجلس العلم والتسجيل',
                              style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: const StadiumBorder(),
                              elevation: 2,
                            ),
                          )
                        else ...[
                          OutlinedButton.icon(
                            onPressed: _pauseRecording,
                            icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
                            label: Text(
                              _isPaused ? 'استئناف' : 'إيقاف مؤقت',
                              style: AppTypography.font(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.amber[300] : Colors.amber[900],
                              side: BorderSide(
                                color: (isDark ? Colors.amber[400] : Colors.amber[800])!.withValues(alpha: 0.6),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _stopAndFinishLesson,
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                            label: Text(
                              'ختام وأرشفة المجلس',
                              style: AppTypography.font(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.terracottaPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: const StadiumBorder(),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );

            final qaWidget = widget.event.isQaEnabled
                ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (allQuestions.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'أسئلة الحضور (${allQuestions.length})',
                          style: GoogleFonts.amiri(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        ActionChip(
                          avatar: Icon(
                            _showUnansweredOnly ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          label: Text(
                            _showUnansweredOnly ? 'كل الأسئلة' : 'غير المجاب فقط',
                            style: AppTypography.font(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() => _showUnansweredOnly = !_showUnansweredOnly);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: displayedQuestions.isEmpty
                        ? Center(
                      child: Text(
                        'لم تُطرح أسئلة بعد في هذا المجلس.\nستظهر أسئلة الحاضرين مباشرة هنا.',
                        style: GoogleFonts.amiri(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : ListView.separated(
                      itemCount: displayedQuestions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final q = displayedQuestions[idx];

                        return Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: q.isAnswered
                                  ? Colors.transparent
                                  : AppColors.gold.withValues(alpha: 0.25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: q.isAnswered
                                      ? Colors.grey.withValues(alpha: 0.2)
                                      : AppColors.emeraldPrimary.withValues(alpha: 0.15),
                                  child: Text(
                                    '${idx + 1}',
                                    style: AppTypography.font(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: q.isAnswered
                                          ? Colors.grey
                                          : AppColors.emeraldPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q.content,
                                    style: AppTypography.font(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: q.isAnswered
                                          ? Colors.grey
                                          : (isDark ? Colors.white : Colors.black87),
                                    ).copyWith(
                                      decoration: q.isAnswered ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: q.isAnswered ? 'تحديد كغير مجاب' : 'تحديد كتمت الإجابة',
                                  icon: Icon(
                                    q.isAnswered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: q.isAnswered ? AppColors.emeraldPrimary : Colors.grey[400],
                                  ),
                                  onPressed: () => data.toggleQuestionAnswered(q.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink();

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: Center(child: timerWidget)),
                  if (widget.event.isQaEnabled) ...[
                    VerticalDivider(
                      width: 1,
                      color: isDark ? Colors.white12 : AppColors.gold.withValues(alpha: 0.2),
                    ),
                    Expanded(flex: 6, child: qaWidget),
                  ],
                ],
              );
            } else {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: widget.event.isQaEnabled ? null : constraints.maxHeight,
                      child: Center(child: timerWidget),
                    ),
                    if (widget.event.isQaEnabled) ...[
                      Divider(
                        height: 1,
                        color: isDark ? Colors.white12 : AppColors.gold.withValues(alpha: 0.2),
                      ),
                      SizedBox(height: 420, child: qaWidget),
                    ],
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

}

/// شاشة بديلة تُعرض إذا حاول القسم النسائي الوصول لواجهة التسجيل والأرشفة.
/// شريط ما يلتقطه الميكروفون الآن: يرى الشيخ أن صوته يُسجَّل فعلاً، لا العدّاد وحده.
class _MicLevelMeter extends StatelessWidget {
  final double level;
  final bool silent;
  final bool isDark;

  const _MicLevelMeter({required this.level, required this.silent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = silent ? Colors.red.shade400 : AppColors.emeraldPrimary;
    return ConstrainedBox(
      key: const ValueKey('micLevelMeter'),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        children: [
          Icon(silent ? Icons.mic_off_rounded : Icons.mic_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: level,
                minHeight: 8,
                color: color,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingNotPermittedView extends StatelessWidget {
  final bool isDark;

  const _RecordingNotPermittedView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF9F6F0),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        title: Text('التسجيل غير متاح', style: AppTypography.titleBold(context, fontSize: 16)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_off_rounded, size: 52, color: AppColors.terracottaPrimary),
              const SizedBox(height: 16),
              Text(
                'تسجيل الدروس وأرشفتها غير متاح للقسم النسائي',
                textAlign: TextAlign.center,
                style: AppTypography.titleBold(context, fontSize: 15.5),
              ),
              const SizedBox(height: 10),
              Text(
                'يمكن للقسم النسائي إعلان دروسه وإدارتها ومتابعتها، أما حفظ التسجيلات في المكتبة العامة فهو محجوب كلياً.',
                textAlign: TextAlign.center,
                style: AppTypography.verveSubtitle(context).copyWith(fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
                ),
                child: Text('رجوع', style: AppTypography.buttonText()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
