import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../services/telegram_media_resolver.dart';
import '../../../services/windows_audio_compressor.dart';

class SheikhLiveLessonScreen extends StatefulWidget {
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
    _initForegroundTask();
  }

  void _initForegroundTask() {
    // Platform-specific foreground task initialization (mobile only)
    if (!PlatformUtils.supportsForegroundTask) return;
  }

  Future<void> _startForegroundTask() async {
    // Platform-specific foreground task (mobile only)
    if (!PlatformUtils.supportsForegroundTask) return;
  }

  Future<void> _stopForegroundTask() async {
    // Platform-specific foreground task cleanup (mobile only)
    if (!PlatformUtils.supportsForegroundTask) return;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _stopForegroundTask();

    if (widget.event.eventStatus == 'live') {
      _dataService.changeEventStatus(widget.event.id, 'upcoming');
    }

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsElapsed++);
      _enforceRecordingLimit();
    });
    _pulseController.repeat(reverse: true);
  }

  /// تنبيه قبل 5 دقائق من الحد، ثم إنهاء وأرشفة تلقائية عند بلوغه.
  void _enforceRecordingLimit() {
    final max = MediaLimits.maxRecording.inSeconds;
    if (!_limitWarningShown && _secondsElapsed >= max - 5 * 60) {
      _limitWarningShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بقي 5 دقائق على الحد الأقصى للتسجيل (60 دقيقة)'),
          duration: Duration(seconds: 6),
        ),
      );
    }
    if (_isRecording && _secondsElapsed >= max) {
      _finishLesson(auto: true);
    }
  }

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
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final ext = _recordsWavThenCompresses ? 'wav' : 'm4a';
        final path = '${dir.path}/lesson_${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        // صوت كلام أحادي مضغوط: الساعة ≈ 14MB، تحت حد أرشيف تيليجرام (20MB).
        await _audioRecorder.start(
          _recordsWavThenCompresses
              // Windows: the recorder's default format (known to work with laptop mics);
              // the compressor downsamples it to mono 16kHz afterwards.
              ? const RecordConfig(encoder: AudioEncoder.wav)
              : const RecordConfig(
                  encoder: AudioEncoder.aacLc,
                  bitRate: MediaLimits.recordingBitRate,
                  sampleRate: MediaLimits.recordingSampleRate,
                  numChannels: 1,
                ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordedFilePath = path;
        });
        _startTimer();
        _startForegroundTask();

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
      await _audioRecorder.pause();
      _pauseTimer();
      setState(() => _isPaused = true);
    } else if (_isRecording && _isPaused) {
      await _audioRecorder.resume();
      _startTimer();
      setState(() => _isPaused = false);
    }
  }

  Future<void> _stopAndFinishLesson() => _finishLesson();

  /// ينهي الدرس ويؤرشفه. [auto] عند بلوغ الحد الأقصى: بلا سؤال تأكيد.
  Future<void> _finishLesson({bool auto = false}) async {
    if (!auto) {
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

    _pauseTimer();
    String? finalPath;
    if (_isRecording) {
      finalPath = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
    }
    finalPath ??= _recordedFilePath;

    if (finalPath == null || !File(finalPath).existsSync()) {
      if (mounted) {
        _dataService.finalizeLiveSession(widget.event.id);
        Navigator.pop(context);
      }
      return;
    }

    if (auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بلغ التسجيل الحد الأقصى (60 دقيقة) وتم إنهاؤه وحفظه')),
      );
    }

    if (_recordsWavThenCompresses) {
      setState(() {
        _isUploading = true;
        _busyMessage = 'جاري ضغط التسجيل...';
      });
      final compressed = await WindowsAudioCompressor.compress(finalPath);
      if (!mounted) return;
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
    _dataService.finalizeLiveSession(widget.event.id);
    await _addToUploadQueue(File(finalPath));
  }

  Future<void> _showArchiveProblem(String message) async {
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
    _dataService.finalizeLiveSession(widget.event.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addToUploadQueue(File file) async {
    setState(() {
      _isUploading = true;
      _busyMessage = 'جاري أرشفة الدرس الصوتي في السحابة...';
    });

    try {
      final data = context.read<DataService>();
      await data.audioUploadQueue.addToQueue(
        eventId: widget.event.id,
        title: widget.event.title,
        speaker: widget.event.organizerName,
        filePath: file.path,
        durationSeconds: _secondsElapsed,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم إنهاء الدرس وحفظ التسجيل ✨ سيُرفع لمكتبة الدروس تلقائياً فور توفر الإنترنت.',
            ),
            backgroundColor: AppColors.emeraldPrimary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _handleOnWillPop() async {
    if (!_isRecording && !_isUploading) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('التسجيل قيد العمل'),
        content: const Text('أنت في منتصف تسجيل مجلس العلم حالياً. هل تريد حقاً الخروج وإيقاف التسجيل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('البقاء في الدرس')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، الخروج'),
          ),
        ],
      ),
    );
    return result ?? false;
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

    final allQuestions = data.getEventQuestions(widget.event.id);
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
        final shouldPop = await _handleOnWillPop();
        if (!mounted) return;
        if (shouldPop) {
          if (_isRecording) {
            await _audioRecorder.stop();
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
                            'من أصل 60 دقيقة',
                            style: GoogleFonts.amiri(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
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
