import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_file_launcher.dart';
import '../models/models.dart';
import '../presentation/widgets/widgets.dart';
import '../services/data_service.dart';
import '../services/audio_upload_queue_manager.dart';
import '../services/lesson_audio_service.dart';
import '../services/telegram_media_resolver.dart';
import '../widgets/app_user_avatar.dart';
import '../widgets/qr_dialogs.dart';
import 'discover/dialogs/discover_event_dialog.dart';
import 'discover/dialogs/lesson_speakers_field.dart';
import 'discover/sheikh_live_lesson_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'discover/widgets/prayer_times_qibla_view.dart';
import 'discover/widgets/mosque_donations_view.dart';
import 'discover/widgets/islamic_zad_hub_view.dart';

class DiscoverScreen extends StatefulWidget {
  final VoidCallback onOpenScanner;

  const DiscoverScreen({super.key, required this.onOpenScanner});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _activeMainTab = 'upcoming'; // 'upcoming' or 'archive'
  String _selectedFilter = 'all';
  String _selectedArchiveSheikh = 'all';
  String _selectedArchiveMosque = 'all';
  String _archiveSortType = 'newest';

  /// فلتر نوع التسجيل في الأرشيف: 'all' أو 'video' أو 'audio'.
  String _archiveMediaFilter = 'all';

  final TextEditingController _archiveSearchCtrl = TextEditingController();

  // مشغّل الدروس على مستوى التطبيق: يكمل التشغيل عند مغادرة هذا التبويب وبالخلفية
  final LessonAudioService _lesson = LessonAudioService.instance;
  String? get _activeAudioId => _lesson.activeEventId;
  bool get _isPlaying => _lesson.isPlaying;
  Duration get _position => _lesson.position;
  Duration get _duration => _lesson.duration;
  double get _playbackRate => _lesson.rate;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _lesson.addListener(_onLessonChanged);
    _lesson.onError = _showLessonError;
  }

  void _onLessonChanged() {
    if (mounted) setState(() {});
  }

  void _showLessonError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    // The lesson keeps playing; this screen just stops listening.
    _lesson.removeListener(_onLessonChanged);
    if (_lesson.onError == _showLessonError) _lesson.onError = null;
    _archiveSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        _currentPosition = pos;
        final data = Provider.of<DataService>(context, listen: false);
        final events = data.getCommunityEvents();
        for (var e in events) {
          e.distanceMeters = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            e.latitude,
            e.longitude,
          );
        }
        setState(() {});
      }
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _playOrPause(CommunityEvent ev) => _lesson.playOrPause(ev);

  /// هل مرفق الدرس تسجيل مرئي فعلاً؟
  ///
  /// حقل [CommunityEvent.videoRecordUrl] يُستخدم لأي مرفق (مستند أو رابط أيضاً)،
  /// لذلك لا يكفي [CommunityEvent.hasVideo] وحده لتصنيف الدرس كفيديو.
  bool _hasPlayableVideo(CommunityEvent e) {
    final url = e.videoRecordUrl;
    if (url == null || url.trim().isEmpty) return false;
    return AppFileLauncher.getAttachmentInfo(url).type ==
        AppAttachmentType.video;
  }

  /// يفتح مرفق الدرس بتطبيق الجهاز الافتراضي (مشغّل الفيديو، قارئ PDF...).
  ///
  /// نوقف صوت الدرس أولاً عند فتح فيديو كي لا يتداخل صوتان.
  Future<void> _openAttachment(
    CommunityEvent ev,
    AppAttachmentInfo info,
  ) async {
    final source = ev.videoRecordUrl;
    if (source == null || source.trim().isEmpty) return;

    if (info.type == AppAttachmentType.video && _activeAudioId != null) {
      _stopAndClosePlayer();
    }
    if (mounted) await AppFileLauncher.open(context, source);
  }

  void _stopAndClosePlayer() => _lesson.stop();

  void _seekRelative(int seconds) => _lesson.seekRelative(seconds);

  void _cyclePlaybackRate() => _lesson.cycleRate();

  void _showAskQuestionDialog(
    BuildContext context,
    CommunityEvent ev,
    DataService data,
  ) {
    final questionCtrl = TextEditingController();
    final existingQuestions = data.getEventQuestions(ev.id);
    final remainingQuestions = ev.maxQuestions - existingQuestions.length;

    showDialog(
      context: context,
      builder: (ctx) {
        final primaryColor = Theme.of(context).primaryColor;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(Icons.help_outline_rounded, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طرح سؤال مجهول الهوية',
                  style: AppTypography.titleBold(context, fontSize: 15),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'درس: ${ev.title} (${ev.organizerName})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'سؤالك سيظهر للشيخ مباشرة في شاشة الدرس بدون اسمك أو أي بيانات شخصية.',
                style: AppTypography.verveSubtitle(context),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: questionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك بوضوح وإيجاز هنا...',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'متبقي $remainingQuestions أسئلة متاحة لهذا الدرس',
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                final text = questionCtrl.text.trim();
                if (text.isEmpty) return;
                data.submitEventQuestion(ev.id, text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'تم إرسال سؤالك للشيخ بنجاح وستتم إجابته أثناء الدرس ✨',
                    ),
                    backgroundColor: AppColors.emeraldPrimary,
                  ),
                );
              },
              child: const Text('إرسال السؤال'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final session = data.currentSession;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    final adminSession = data.getSessionForRole('mosque_admin');
    final sheikhSession = data.getSessionForRole('sheikh');
    final effectiveSheikhSession = (session != null && session.role == 'sheikh')
        ? session
        : sheikhSession;
    final effectiveAdminSession =
        (session != null && session.role == 'mosque_admin')
        ? session
        : adminSession;
    final canManageEvents =
        effectiveSheikhSession != null || effectiveAdminSession != null;
    final effectiveSession = effectiveSheikhSession ?? effectiveAdminSession;

    // فرع المستخدم: الزائر بلا جلسة يُعامل كفرع الرجال، فلا يظهر له شيء نسائي
    final viewerBranch = data.branchOfSession(session);
    final isFemaleViewer = viewerBranch == 'female';

    /// ملكية الفعالية محصورة داخل نفس الفرع: مديرة القسم النسائي لا تدير دروس
    /// الرجال ولو تشابه الاسم أو كان المسجد الأم واحداً.
    bool ownsEvent(CommunityEvent e) {
      if (effectiveSession == null) return false;
      if (data.branchOfMosque(e.mosqueId) != viewerBranch) return false;
      if (effectiveSession.role == 'mosque_admin' &&
          effectiveSession.mosqueId == e.mosqueId) {
        return true;
      }
      // الشيخ يدير دروسه، ومنها الدروس الجماعية التي يشارك فيها
      if (e.involvesSheikh(sheikhId: effectiveSession.sheikhId)) {
        return true;
      }
      // مطابقة الاسم مقيَّدة بنفس المسجد حتى لا يدير شيخ درساً لشيخ آخر يشابهه اسمه
      return effectiveSession.mosqueId == e.mosqueId &&
          effectiveSession.name.trim() == e.organizerName.trim();
    }

    /// الدروس القادمة: النساء يرين الفعاليات العائلية (المختلطة) ودروس قسمهن،
    /// والرجال لا يرون أي شيء صادراً عن قسم نسائي ولا أي درس موجَّه للنساء.
    bool isUpcomingVisible(CommunityEvent e) {
      final eventBranch = data.branchOfMosque(e.mosqueId);
      if (isFemaleViewer) {
        if (eventBranch == 'female') return true;
        return e.targetAudience == 'general';
      }
      if (eventBranch == 'female') return false;
      return e.targetAudience == 'male' || e.targetAudience == 'general';
    }

    /// الأرشيف غير متماثل بشكل مقصود: للنساء أن يسمعن تسجيلات دروس الرجال،
    /// وللرجال لا يظهر أي تسجيل صادر عن قسم نسائي أو موجَّه للنساء.
    bool isArchiveVisible(CommunityEvent e) {
      if (isFemaleViewer) return true;
      if (data.branchOfMosque(e.mosqueId) == 'female') return false;
      return e.targetAudience == 'male' || e.targetAudience == 'general';
    }

    final everyEvent = data.getCommunityEvents();
    final allEvents = everyEvent
        .where((e) => isUpcomingVisible(e) || ownsEvent(e))
        .toList();
    final archiveScope = everyEvent.where(isArchiveVisible).toList();

    // 1. تبويب الدروس القادمة أو المباشرة حصراً (تستثني المؤرشف كلياً)
    final activeUpcomingBase = allEvents
        .where((e) => e.isActive && e.eventStatus != 'archived')
        .toList();

    // استخراج تصنيفات الدروس المتوفرة ديناميكياً والتي تحتوي على دروس قادمة
    final Map<String, String> availableCategories = {'all': 'الكل'};

    const standardCategoriesOrder = [
      'lesson',
      'mawlid',
      'tajweed',
      'dhikr_circle',
      'general',
    ];

    const standardCategoryLabels = {
      'lesson': 'دروس فقه وعلم',
      'mawlid': 'مجالس الصلاة على النبي ﷺ',
      'tajweed': 'دورات التجويد',
      'dhikr_circle': 'مجالس الذكر والتلاوة',
      'general': 'محاضرات عامة',
    };

    // إضافة التصنيفات القياسية الموجودة بالفعل في قائمة الدروس القادمة
    for (final catKey in standardCategoriesOrder) {
      if (activeUpcomingBase.any((e) => e.eventType == catKey)) {
        availableCategories[catKey] = standardCategoryLabels[catKey]!;
      }
    }

    // إضافة التصنيفات المخصصة أو أي أنواع أخرى تحتوي على دروس
    for (final ev in activeUpcomingBase) {
      if (ev.eventType == 'custom' &&
          (ev.customTypeName?.trim().isNotEmpty ?? false)) {
        final customName = ev.customTypeName!.trim();
        final key = 'custom:$customName';
        if (!availableCategories.containsKey(key)) {
          availableCategories[key] = customName;
        }
      } else if (!standardCategoriesOrder.contains(ev.eventType) &&
          ev.eventType != 'custom') {
        if (!availableCategories.containsKey(ev.eventType)) {
          final label = (ev.customTypeName?.trim().isNotEmpty ?? false)
              ? ev.customTypeName!.trim()
              : ev.eventType;
          availableCategories[ev.eventType] = label;
        }
      }
    }

    // التأكد من أن الفلتر المحدد حالياً لا يزال متوفراً، وإلا العودة لـ 'all'
    if (!availableCategories.containsKey(_selectedFilter)) {
      _selectedFilter = 'all';
    }

    final upcomingEvents = activeUpcomingBase.where((e) {
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter.startsWith('custom:')) {
        final cat = _selectedFilter.substring(7);
        return e.eventType == 'custom' && e.customTypeName?.trim() == cat;
      }
      return e.eventType == _selectedFilter;
    }).toList();

    // 2. تبويب الأرشيف للتسجيلات الصوتية
    final searchQuery = _archiveSearchCtrl.text.trim().toLowerCase();
    final archivedBase = archiveScope.where((e) {
      // الأرشيف يظهر دائماً بصرف النظر عن isActive — isActive لا تؤثر على المؤرشف
      final isArchived = e.eventStatus == 'archived' || e.hasAudio;
      if (!isArchived) return false;

      // فلترة حسب الشيخ
      if (_selectedArchiveSheikh != 'all' &&
          e.organizerName.trim() != _selectedArchiveSheikh) {
        return false;
      }

      // فلترة حسب المسجد
      if (_selectedArchiveMosque != 'all' &&
          e.mosqueId != _selectedArchiveMosque) {
        return false;
      }

      if (searchQuery.isNotEmpty) {
        final matchTitle = e.title.toLowerCase().contains(searchQuery);
        final matchDesc = e.description.toLowerCase().contains(searchQuery);
        return matchTitle || matchDesc;
      }

      return true;
    }).toList();

    // أعداد كل نوع تُحسب قبل فلتر النوع نفسه كي تبقى ثابتة على الشرائح
    final archiveVideoCount = archivedBase.where(_hasPlayableVideo).length;
    final archiveAudioCount = archivedBase.where((e) => e.hasAudio).length;

    // فلترة حسب نوع التسجيل (فيديو / صوت / الكل)
    final archivedEvents = archivedBase.where((e) {
      switch (_archiveMediaFilter) {
        case 'video':
          return _hasPlayableVideo(e);
        case 'audio':
          return e.hasAudio;
        default:
          return true;
      }
    }).toList();

    // فرز القائمة
    archivedEvents.sort((a, b) {
      if (_archiveSortType == 'newest') {
        return b.eventDateTime.compareTo(a.eventDateTime);
      } else if (_archiveSortType == 'oldest') {
        return a.eventDateTime.compareTo(b.eventDateTime);
      } else if (_archiveSortType == 'sheikh') {
        return a.organizerName.compareTo(b.organizerName);
      } else if (_archiveSortType == 'mosque') {
        final mosqueA = data.getMosqueById(a.mosqueId)?.name ?? '';
        final mosqueB = data.getMosqueById(b.mosqueId)?.name ?? '';
        return mosqueA.compareTo(mosqueB);
      }
      return 0;
    });

    final archiveSheikhNames = archiveScope
        .where((e) => e.isActive && (e.eventStatus == 'archived' || e.hasAudio))
        .map((e) => e.organizerName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    final archiveMosqueIds = archiveScope
        .where((e) => e.isActive && (e.eventStatus == 'archived' || e.hasAudio))
        .map((e) => e.mosqueId)
        .toSet()
        .toList();

    return RefreshIndicator(
      onRefresh: () => data.syncWithSupabase(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 14 : 24,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.sunsetTwilightGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppShadows.heroBanner,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.rPill),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: AppColors.goldBright,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'البوابة العلمية العامة',
                                style: AppTypography.font(
                                  color: AppColors.goldBright,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (canManageEvents && effectiveSession != null)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  DiscoverEventDialog.showManagementModal(
                                    context,
                                    data,
                                    effectiveSession,
                                  ),
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 16,
                              ),
                              label: Text(
                                'إدارة دروسي العامة',
                                style: AppTypography.buttonText(),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                side: const BorderSide(color: Colors.white30),
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () {
                              void openSheikhScanner() {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => UniversalQrScannerDialog(
                                    title: 'اعتماد الشيخ لإعلان درس عام',
                                    hintText:
                                        'امسح باركود بطاقة الشيخ الخاصة بك للبدء في إعلان دروسك العامة',
                                    onCodeScanned: (code) async {
                                      Navigator.pop(ctx);
                                      final verified = await data.verifyCode(
                                        code,
                                      );
                                      if (verified != null) {
                                        if (verified.role == 'sheikh') {
                                          if (context.mounted) {
                                            DiscoverEventDialog.showSheikhAddPublicEventModal(
                                              context,
                                              data,
                                              verified,
                                            );
                                          }
                                        } else if (verified.role ==
                                            'mosque_admin') {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'هذا الباركود لمدير مسجد. تم فتح نافذة الإعلان لإدارة المسجد.',
                                                ),
                                                backgroundColor: primaryColor,
                                              ),
                                            );
                                            DiscoverEventDialog.showAdminAddPublicEventModal(
                                              context,
                                              data,
                                              verified,
                                            );
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'عذراً، هذا الباركود غير معتمد لإعلان الدروس العامة.',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'رمز غير صحيح أو غير مسجل في النظام.',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              }

                              if (effectiveSheikhSession != null) {
                                DiscoverEventDialog.showSheikhAddPublicEventModal(
                                  context,
                                  data,
                                  effectiveSheikhSession,
                                );
                              } else if (effectiveAdminSession != null) {
                                showDialog(
                                  context: context,
                                  builder: (choiceCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.help_outline,
                                          color: AppColors.goldDark,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('نوع إعلان الدرس'),
                                      ],
                                    ),
                                    content: const Text(
                                      'أنت مسجل حالياً بحساب إدارة المسجد. هل تود إعلان الدرس بصفتك إدارة المسجد، أم تصوير باركود بطاقة الشيخ لإعلانه كشيخ؟',
                                      style: TextStyle(fontSize: 13.5),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(choiceCtx);
                                          DiscoverEventDialog.showAdminAddPublicEventModal(
                                            context,
                                            data,
                                            effectiveAdminSession,
                                          );
                                        },
                                        child: const Text('إعلان كإدارة مسجد'),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(choiceCtx);
                                          openSheikhScanner();
                                        },
                                        icon: const Icon(
                                          Icons.qr_code_scanner,
                                          size: 16,
                                        ),
                                        label: const Text('مسح باركود الشيخ'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                openSheikhScanner();
                              }
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              'إعلان درس عام',
                              style: AppTypography.buttonText(),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'منصة الدروس ومجالس العلم في المساجد',
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تصفح مواعيد مجالس العلم المباشرة، شارك بأسئلتك ، أو استمع للتسجيلات الصوتية في مكتبة الدروس.',
                    style: AppTypography.bodyRegular(
                      context,
                      color: const Color(0xFFF9EAE1),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // محول التبويبات الرئيسي (المجتمع والمكتبة الإسلامية)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildMainTabButton(
                      id: 'upcoming',
                      label: 'مجالس العلم (${upcomingEvents.length})',
                      icon: Icons.event_available,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 4),
                    _buildMainTabButton(
                      id: 'archive',
                      label: 'مكتبة الدروس (${archivedBase.length})',
                      icon: Icons.podcasts_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 4),
                    _buildMainTabButton(
                      id: 'donations',
                      label: 'التبرع للمساجد 🤝',
                      icon: Icons.volunteer_activism_rounded,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ==================== تبويب الدروس القادمة فقط ====================
            if (_activeMainTab == 'upcoming') ...[
              if (availableCategories.length > 1) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < availableCategories.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _buildFilterChip(
                          availableCategories.values.elementAt(i),
                          availableCategories.keys.elementAt(i),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              upcomingEvents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Text(
                          'لا توجد مجالس قادمة حالياً',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: upcomingEvents.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.8,
                        color: dividerColor,
                      ),
                      itemBuilder: (context, idx) {
                        final ev = upcomingEvents[idx];
                        final mosque = data
                            .getMosques()
                            .where((m) => m.id == ev.mosqueId)
                            .firstOrNull;

                        final isLive = ev.eventStatus == 'live';
                        final isCutoff = DateTime.now().isAfter(
                          ev.eventDateTime.subtract(
                            const Duration(minutes: 30),
                          ),
                        );
                        final questions = data.getEventQuestions(ev.id);
                        final remainingQ = ev.maxQuestions - questions.length;
                        final isManager = canManageEvents && ownsEvent(ev);
                        // القسم النسائي يدير دروسه لكنه لا يسجّل ولا يؤرشف أبداً
                        final canRecordLesson =
                            isManager && data.canRecordArchive;

                        // جلب بيانات الشيخ لصورته الشخصية
                        final sheikh = ev.sheikhId != null
                            ? data
                                  .getSheikhs()
                                  .where((s) => s.id == ev.sheikhId)
                                  .firstOrNull
                            : null;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;

                            final avatarWidget = AppUserAvatar(
                              name: ev.organizerName,
                              imageUrl: sheikh?.profileImageUrl,
                              role: 'sheikh',
                              radius: 22,
                            );

                            final titleInfoWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ev.title,
                                        style: AppTypography.verveTitle(
                                          context,
                                        ),
                                      ),
                                    ),
                                    if (ev.isGroupLesson) ...[
                                      const GroupLessonBadge(),
                                      const SizedBox(width: 6),
                                    ],
                                    if (isLive)
                                      const UnifiedBadge(
                                        label: 'مباشر الآن 🔴',
                                        backgroundColor: Color(0xFFFEE2E2),
                                        textColor: Colors.red,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${ev.isGroupLesson ? 'المحاضرون' : 'المحاضر'}: ${ev.organizerName} • ${mosque?.name ?? "المسجد"}${mosque?.city != null ? " (${mosque!.city})" : ""}',
                                  style: AppTypography.verveSubtitle(context),
                                ),
                                if (ev.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    ev.description,
                                    style: AppTypography.bodyRegular(
                                      context,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    UnifiedBadge(
                                      label: ev.displayCategory,
                                      backgroundColor: AppColors.gold
                                          .withValues(alpha: 0.15),
                                      textColor: AppColors.goldDark,
                                    ),
                                    UnifiedBadge(
                                      label: ev.timingDescription,
                                      backgroundColor: AppColors
                                          .terracottaPrimary
                                          .withValues(alpha: 0.1),
                                      textColor: AppColors.terracottaPrimary,
                                    ),
                                    Builder(
                                      builder: (context) {
                                        double? dist = ev.distanceMeters;
                                        if (dist == null &&
                                            _currentPosition != null) {
                                          dist = Geolocator.distanceBetween(
                                            _currentPosition!.latitude,
                                            _currentPosition!.longitude,
                                            ev.latitude,
                                            ev.longitude,
                                          );
                                          ev.distanceMeters = dist;
                                        }
                                        if (dist != null) {
                                          return UnifiedBadge(
                                            label:
                                                'يبعد ${(dist / 1000).toStringAsFixed(1)} كم 📍',
                                            backgroundColor: isDark
                                                ? Colors.white10
                                                : const Color(0xFFF1F5F9),
                                            textColor: isDark
                                                ? Colors.white70
                                                : AppColors.obsidianEspresso,
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                    UnifiedBadge(
                                      label:
                                          '${ev.attendanceCount} مهتمون للحضور',
                                      backgroundColor: AppColors.emeraldPrimary
                                          .withValues(alpha: 0.1),
                                      textColor: AppColors.emeraldPrimary,
                                      icon: Icons.people_outline,
                                    ),
                                  ],
                                ),
                                if (ev.isQaEnabled && !isManager) ...[
                                  const SizedBox(height: 10),
                                  if (isCutoff)
                                    const Text(
                                      '🔒 تم إغلاق باب استقبال الأسئلة (قبل الدرس بنصف ساعة)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (remainingQ <= 0)
                                    const Text(
                                      '🔒 اكتمل الحد الأقصى للأسئلة المتاحة لهذا المجلس',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () => _showAskQuestionDialog(
                                        context,
                                        ev,
                                        data,
                                      ),
                                      icon: const Icon(
                                        Icons.help_outline_rounded,
                                        size: 15,
                                      ),
                                      label: Text(
                                        'طرح سؤال مجهول للشيخ (متبقي $remainingQ)',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0284C7,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                ],
                              ],
                            );

                            final actionButtonsWidget = Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: isNarrow
                                  ? WrapAlignment.start
                                  : WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (!isManager)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: ev.hasTapped
                                          ? AppColors.terracottaPrimary
                                          : Colors.transparent,
                                      side: BorderSide(
                                        color: ev.hasTapped
                                            ? AppColors.terracottaPrimary
                                            : (isDark
                                                  ? Colors.white24
                                                  : Colors.black26),
                                      ),
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                    onPressed: () => data.tapAttendance(ev.id),
                                    icon: Icon(
                                      ev.hasTapped
                                          ? Icons.check_circle
                                          : Icons.touch_app,
                                      size: 14,
                                      color: ev.hasTapped
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white70
                                                : AppColors.obsidianEspresso),
                                    ),
                                    label: Text(
                                      ev.hasTapped
                                          ? 'مسجل حضور'
                                          : 'أنوي الحضور',
                                      style: AppTypography.buttonText(
                                        color: ev.hasTapped
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white70
                                                  : AppColors.obsidianEspresso),
                                      ),
                                    ),
                                  ),
                                if (isManager &&
                                    ev.eventStatus != 'archived') ...[
                                  if (canRecordLesson)
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                SheikhLiveLessonScreen(
                                                  event: ev,
                                                ),
                                          ),
                                        );
                                        if (context.mounted) setState(() {});
                                      },
                                      icon: const Icon(Icons.mic, size: 16),
                                      label: Text(
                                        isLive
                                            ? 'متابعة البث 🔴'
                                            : 'بدء الدرس 🎙️',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isLive
                                            ? Colors.red
                                            : AppColors.emeraldPrimary,
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: 'تعديل',
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppColors.goldDark,
                                    ),
                                    onPressed: () =>
                                        DiscoverEventDialog.showEditPublicEventModal(
                                          context,
                                          data,
                                          ev,
                                        ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.redAccent,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'تأكيد الحذف',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          'هل أنت متأكد من حذف درس "${ev.title}"؟\nلا يمكن التراجع عن هذا الإجراء.',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('إلغاء'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                              shape: const StadiumBorder(),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              data.deleteCommunityEvent(ev.id);
                                            },
                                            child: const Text(
                                              'حذف نهائياً',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );

                            if (isNarrow) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        avatarWidget,
                                        const SizedBox(width: 12),
                                        Expanded(child: titleInfoWidget),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    actionButtonsWidget,
                                  ],
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(width: 50, child: avatarWidget),
                                  const SizedBox(width: 14),
                                  Expanded(child: titleInfoWidget),
                                  const SizedBox(width: 12),
                                  actionButtonsWidget,
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ],

            // ==================== تبويب الأرشيف الصوتي المستقل تماماً ====================
            if (_activeMainTab == 'archive') ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _archiveSearchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الدرس أو محاوره...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _archiveSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _archiveSearchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkCard
                            : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // فلتر نوع التسجيل: فيديو أو صوت أو الكل
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(
                      Icons.perm_media_outlined,
                      size: 18,
                      color: AppColors.emeraldPrimary,
                    ),
                    const SizedBox(width: 8),
                    _buildMediaChip(
                      label: 'الكل',
                      icon: Icons.apps_rounded,
                      value: 'all',
                      count: archivedBase.length,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMediaChip(
                      label: 'فيديو',
                      icon: Icons.videocam_rounded,
                      value: 'video',
                      count: archiveVideoCount,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildMediaChip(
                      label: 'صوت',
                      icon: Icons.headphones_rounded,
                      value: 'audio',
                      count: archiveAudioCount,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              if (archiveSheikhNames.isNotEmpty ||
                  archiveMosqueIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                // فلاتر الشيوخ
                if (archiveSheikhNames.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 18,
                          color: AppColors.goldDark,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('جميع الشيوخ'),
                          selected: _selectedArchiveSheikh == 'all',
                          selectedColor: AppColors.terracottaPrimary,
                          labelStyle: TextStyle(
                            color: _selectedArchiveSheikh == 'all'
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: _selectedArchiveSheikh == 'all'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (v) {
                            if (v) {
                              setState(() => _selectedArchiveSheikh = 'all');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        for (final name in archiveSheikhNames) ...[
                          ChoiceChip(
                            label: Text(name),
                            selected: _selectedArchiveSheikh == name,
                            selectedColor: AppColors.terracottaPrimary,
                            labelStyle: TextStyle(
                              color: _selectedArchiveSheikh == name
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: _selectedArchiveSheikh == name
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (v) {
                              if (v) {
                                setState(() => _selectedArchiveSheikh = name);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // فلاتر المساجد
                if (archiveMosqueIds.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(
                          Icons.mosque_rounded,
                          size: 18,
                          color: AppColors.goldDark,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('جميع المساجد'),
                          selected: _selectedArchiveMosque == 'all',
                          selectedColor: AppColors.terracottaPrimary,
                          labelStyle: TextStyle(
                            color: _selectedArchiveMosque == 'all'
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: _selectedArchiveMosque == 'all'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (v) {
                            if (v) {
                              setState(() => _selectedArchiveMosque = 'all');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        for (final mId in archiveMosqueIds) ...[
                          Builder(
                            builder: (context) {
                              final mName =
                                  data.getMosqueById(mId)?.name ?? 'مسجد';
                              return ChoiceChip(
                                label: Text(mName),
                                selected: _selectedArchiveMosque == mId,
                                selectedColor: AppColors.terracottaPrimary,
                                labelStyle: TextStyle(
                                  color: _selectedArchiveMosque == mId
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  fontWeight: _selectedArchiveMosque == mId
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (v) {
                                  if (v) {
                                    setState(
                                      () => _selectedArchiveMosque = mId,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                // خيارات الفرز
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 18,
                        color: AppColors.terracottaPrimary,
                      ),
                      const SizedBox(width: 8),
                      _buildSortChip('الأحدث 🕒', 'newest'),
                      const SizedBox(width: 8),
                      _buildSortChip('الأقدم ⏳', 'oldest'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              archivedEvents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Text(
                          _archiveMediaFilter == 'video'
                              ? 'لا توجد تسجيلات مرئية مطابقة ضمن هذا الاختيار'
                              : (_archiveMediaFilter == 'audio'
                                    ? 'لا توجد تسجيلات صوتية مطابقة ضمن هذا الاختيار'
                                    : 'لا توجد تسجيلات في مكتبة الدروس حتى الآن'),
                          textAlign: TextAlign.center,
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: archivedEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, idx) {
                        final ev = archivedEvents[idx];
                        final isCurrentActive = _activeAudioId == ev.id;
                        final isThisPlaying = isCurrentActive && _isPlaying;

                        // جلب بيانات الشيخ للصورة الشخصية
                        final sheikh = ev.sheikhId != null
                            ? data
                                  .getSheikhs()
                                  .where((s) => s.id == ev.sheikhId)
                                  .firstOrNull
                            : null;
                        final canManageThisArchivedItem =
                            _canManageArchivedEvent(ev, session, data);

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isCurrentActive
                                  ? AppColors.terracottaPrimary
                                  : dividerColor,
                              width: isCurrentActive ? 2.0 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isCurrentActive
                                    ? AppColors.terracottaPrimary.withValues(
                                        alpha: 0.12,
                                      )
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: isCurrentActive ? 16 : 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // رأس الكرت
                              Row(
                                children: [
                                  AppUserAvatar(
                                    name: ev.organizerName,
                                    imageUrl: sheikh?.profileImageUrl,
                                    role: 'sheikh',
                                    radius: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ev.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${ev.isGroupLesson ? 'المحاضرون' : 'المحاضر'}: ${ev.organizerName} • ${DateFormat('yyyy/MM/dd').format(ev.eventDateTime)}',
                                          style: AppTypography.verveSubtitle(
                                            context,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // زر التشغيل الصوتي يظهر فقط للتسجيلات الصوتية.
                                  // تسجيلات الفيديو لها كرتها الخاص أسفل الرأس.
                                  if (ev.hasAudio)
                                    IconButton(
                                      iconSize: 48,
                                      color: AppColors.terracottaPrimary,
                                      tooltip: isThisPlaying
                                          ? 'إيقاف مؤقت'
                                          : 'تشغيل التسجيل',
                                      icon: Icon(
                                        isThisPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill,
                                      ),
                                      onPressed: () => _playOrPause(ev),
                                    ),
                                  if (canManageThisArchivedItem)
                                    IconButton(
                                      tooltip: 'حذف من مكتبة الدروس',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 22,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteArchivedEvent(
                                            context,
                                            data,
                                            ev,
                                          ),
                                    ),
                                ],
                              ),

                              // لوحة التحكم تظهر حصراً وفقط إذا كان هذا الدرس هو المختار والشغال
                              if (isCurrentActive) ...[
                                const SizedBox(height: 14),
                                Divider(height: 1, color: dividerColor),
                                const SizedBox(height: 10),

                                // شريط التقدم الزمني
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 16,
                                    ),
                                    trackHeight: 4,
                                    activeTrackColor:
                                        AppColors.terracottaPrimary,
                                    thumbColor: AppColors.terracottaPrimary,
                                    inactiveTrackColor: isDark
                                        ? Colors.white24
                                        : Colors.black12,
                                  ),
                                  child: Slider(
                                    value: _position.inMilliseconds
                                        .clamp(
                                          0,
                                          _duration.inMilliseconds > 0
                                              ? _duration.inMilliseconds
                                              : 1,
                                        )
                                        .toDouble(),
                                    max:
                                        (_duration.inMilliseconds > 0
                                                ? _duration.inMilliseconds
                                                : 1)
                                            .toDouble(),
                                    onChanged: (val) {
                                      _lesson.seek(
                                        Duration(milliseconds: val.toInt()),
                                      );
                                    },
                                  ),
                                ),

                                // العداد الزمني (المنقضي / الكلي)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(_position),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        _duration.inSeconds > 0
                                            ? _formatDuration(_duration)
                                            : '00:00',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // أزرار التحكم الفورية (تقديم، ترجيع، سرعات، وإغلاق)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: 'ترجيع 10 ثوانٍ',
                                      icon: const Icon(
                                        Icons.replay_10_rounded,
                                        size: 28,
                                      ),
                                      onPressed: () => _seekRelative(-10),
                                    ),
                                    const SizedBox(width: 14),
                                    IconButton(
                                      tooltip: 'تقديم 10 ثوانٍ',
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                        size: 28,
                                      ),
                                      onPressed: () => _seekRelative(10),
                                    ),
                                    const SizedBox(width: 18),

                                    // زر سرعة القراءة
                                    InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: _cyclePlaybackRate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.terracottaPrimary
                                                .withValues(alpha: 0.5),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          color: AppColors.terracottaPrimary
                                              .withValues(alpha: 0.1),
                                        ),
                                        child: Text(
                                          '${_playbackRate}x',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.terracottaPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 18),

                                    // زر إغلاق المشغل وإيقافه
                                    IconButton(
                                      tooltip: 'إغلاق المشغل',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 22,
                                        color: Colors.grey,
                                      ),
                                      onPressed: _stopAndClosePlayer,
                                    ),
                                  ],
                                ),
                              ],

                              // شارة وعرض المرفق (فيديو أو ملف أو مستند أو رابط)
                              if (ev.hasVideo) ...[
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final attInfo =
                                        AppFileLauncher.getAttachmentInfo(
                                          ev.videoRecordUrl!,
                                        );
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: attInfo.primaryColor.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: attInfo.primaryColor
                                              .withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: attInfo.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              attInfo.icon,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  attInfo.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  attInfo.subtitle,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  attInfo.primaryColor,
                                              foregroundColor: Colors.white,
                                              shape: const StadiumBorder(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.play_arrow_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              attInfo.actionLabel,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _openAttachment(ev, attInfo),
                                          ),
                                          if (canManageThisArchivedItem) ...[
                                            const SizedBox(width: 4),
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert_rounded,
                                                size: 20,
                                                color: Colors.grey,
                                              ),
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _attachFileOrLinkToEvent(
                                                    context,
                                                    data,
                                                    ev,
                                                  );
                                                } else if (val == 'delete') {
                                                  _removeAttachmentFromEvent(
                                                    context,
                                                    data,
                                                    ev,
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit_rounded,
                                                        size: 18,
                                                        color: AppColors
                                                            .emeraldPrimary,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'استبدال الملف / الرابط',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18,
                                                        color: Colors.redAccent,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('إزالة المرفق'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ] else if (canManageThisArchivedItem) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.emeraldPrimary,
                                    ),
                                    icon: const Icon(
                                      Icons.attach_file_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'إرفاق ملف عام أو رابط للدرس',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => _attachFileOrLinkToEvent(
                                      context,
                                      data,
                                      ev,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ],

            // ==================== التبويبات الإسلامية الإضافية ====================
            if (_activeMainTab == 'zad' || _activeMainTab == 'athkar')
              IslamicZadHubView(
                isDark: isDark,
                initialTab: _activeMainTab == 'athkar' ? 0 : 0,
              ),
            if (_activeMainTab == 'prayer')
              PrayerTimesQiblaView(isDark: isDark),
            if (_activeMainTab == 'donations')
              MosqueDonationsView(isDark: isDark),
          ],
        ),
      ),
    );
  }

  /// شريحة فلتر نوع التسجيل، تحمل عدد العناصر المتاحة لكل نوع.
  Widget _buildMediaChip({
    required String label,
    required IconData icon,
    required String value,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _archiveMediaFilter == value;
    final primaryColor = Theme.of(context).primaryColor;
    final contentColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return ChoiceChip(
      avatar: Icon(icon, size: 15, color: contentColor),
      label: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 12,
          color: contentColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      shape: const StadiumBorder(),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      onSelected: (v) {
        if (v) setState(() => _archiveMediaFilter = value);
      },
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _archiveSortType == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      shape: const StadiumBorder(),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: isDark ? Colors.white10 : Colors.black12),
      onSelected: (v) {
        if (v) setState(() => _archiveSortType = value);
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.buttonText(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : AppColors.obsidianEspresso),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      onSelected: (v) {
        if (v) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildMainTabButton({
    required String id,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _activeMainTab == id;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _activeMainTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// حذف عنصر من الأرشيف نهائياً — متاح فقط لمن يجتاز [_canManageArchivedEvent]:
  /// الشيخ الناشر للدرس، أو إدارة المسجد المالك له.
  void _confirmDeleteArchivedEvent(
    BuildContext context,
    DataService data,
    CommunityEvent ev,
  ) {
    final mediaLabel = ev.hasVideo ? 'التسجيل المرئي' : 'التسجيل الصوتي';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف "${ev.title}" من مكتبة الدروس؟\n'
          'سيُحذف $mediaLabel من مكتبة الدروس لدى جميع المستخدمين، ولا يمكن التراجع.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // إيقاف المشغل إذا كان هذا العنصر قيد التشغيل حالياً
              if (_activeAudioId == ev.id) _stopAndClosePlayer();
              data.deleteCommunityEvent(ev.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف العنصر من مكتبة الدروس')),
              );
            },
            child: const Text(
              'حذف نهائياً',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool _canManageArchivedEvent(
    CommunityEvent ev,
    ActiveSession? session,
    DataService data,
  ) {
    if (session == null) return false;

    // 0. السوبر أدمن يقدر يدير أي شيء
    if (session.role == 'super_admin') return true;

    // 1. الشيخ صاحب الدرس فقط (يتحقق بالمعرف أولاً ثم الاسم كبديل)
    if (session.role == 'sheikh') {
      if (ev.involvesSheikh(sheikhId: session.sheikhId, name: session.name)) return true;
    }

    // 2. إدارة المسجد المالكة للدرس (نفس المسجد فقط — ليس جوامع أخرى)
    if (session.role == 'mosque_admin' &&
        session.mosqueId != null &&
        session.mosqueId == ev.mosqueId) {
      return true;
    }

    // فحص الجلسات الإضافية (متعددة الأدوار على نفس الجهاز)
    final adminSession = data.getSessionForRole('mosque_admin');
    if (adminSession != null &&
        adminSession.mosqueId != null &&
        adminSession.mosqueId == ev.mosqueId) {
      return true;
    }

    final sheikhSession = data.getSessionForRole('sheikh');
    if (sheikhSession != null) {
      if (ev.involvesSheikh(sheikhId: sheikhSession.sheikhId, name: sheikhSession.name)) return true;
    }

    return false;
  }

  void _attachFileOrLinkToEvent(
    BuildContext context,
    DataService data,
    CommunityEvent ev,
  ) {
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.attach_file_rounded, color: AppColors.emeraldPrimary),
            const SizedBox(width: 8),
            const Text(
              'إرفاق ملف أو رابط بالدرس',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'يمكنك اختيار ملف من جهازك (فيديو، مستند PDF، صوت، ملخص) أو إدخال رابط إلكتروني مباشر:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              // خيار اختيار ملف عام (فيديو، PDF، مستند، صوت)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
                icon: const Icon(Icons.file_open_rounded, size: 20),
                label: Text('اختيار ملف من الجهاز (حتى ${MediaLimits.maxFileMbLabel} ميغابايت)'),
                onPressed: () async {
                  try {
                    final result = await FilePicker.pickFiles(
                      type: FileType.any,
                      allowMultiple: false,
                    );
                    final picked = result?.files.single;
                    if (picked == null || picked.path == null) return;

                    final source = File(picked.path!);
                    final size = source.lengthSync();
                    if (size > MediaLimits.maxFileBytes) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'حجم الملف ${MediaLimits.formatMb(size)} ميغابايت، والحد الأقصى ${MediaLimits.maxFileMbLabel} ميغابايت',
                            ),
                            backgroundColor: Colors.redAccent[700],
                          ),
                        );
                      }
                      return;
                    }

                    // نرفع نسخة: طابور الرفع يحذف ملفه بعد النجاح، ولا نمسّ ملف المستخدم.
                    final uploadsDir = Directory(
                      '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}pending_uploads',
                    );
                    await uploadsDir.create(recursive: true);
                    final copy = await source.copy(
                      '${uploadsDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
                    );
                    await data.audioUploadQueue.addToQueue(
                      eventId: ev.id,
                      title: ev.title,
                      speaker: ev.organizerName,
                      filePath: copy.path,
                      durationSeconds: 0,
                      kind: UploadKind.document,
                      fileName: picked.name,
                    );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'جاري رفع الملف، وسيظهر مع الدرس فور اكتمال الرفع',
                          ),
                          backgroundColor: AppColors.emeraldPrimary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذر اختيار الملف: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'أو رابط مباشر / سحابي',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=... أو رابط مباشر',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              final link = urlCtrl.text.trim();
              if (link.isNotEmpty) {
                data.setEventVideoUrl(ev.id, link);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('تم حفظ الرابط وإرفاقه بالدرس بنجاح ✨'),
                    backgroundColor: AppColors.emeraldPrimary,
                  ),
                );
              }
            },
            child: const Text('حفظ الرابط'),
          ),
        ],
      ),
    );
  }

  void _removeAttachmentFromEvent(
    BuildContext context,
    DataService data,
    CommunityEvent ev,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('حذف المرفق'),
        content: const Text(
          'هل أنت متأكد من رغبتك في إزالة هذا الملف/الرابط من الدرس المؤرشف؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إزالة'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      data.setEventVideoUrl(ev.id, '');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إزالة المرفق من الدرس بنجاح')),
        );
      }
    }
  }
}
