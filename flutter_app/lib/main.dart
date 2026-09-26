import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/di/injection.dart';
import 'core/navigation/navigator_key.dart';
import 'core/theme/app_theme.dart';
import 'presentation/blocs/blocs.dart';
import 'screens/settings_screen.dart';
import 'services/data_service.dart';
import 'services/app_update_service.dart';
import 'services/app_notification_service.dart';
import 'widgets/update_dialog.dart';
import 'widgets/code_scanner_dialog.dart';
import 'widgets/app_header_date_widget.dart';
import 'screens/discover_screen.dart';
import 'screens/discover/widgets/quran_reader_view.dart';
import 'screens/discover/widgets/islamic_zad_hub_view.dart';
import 'screens/discover/widgets/prayer_times_qibla_view.dart';
import 'screens/student_screen.dart';
import 'screens/sheikh_screen.dart';
import 'screens/mosque_admin_screen.dart';
import 'screens/competition_screen.dart';
import 'models/models.dart';
import 'screens/onboarding/app_onboarding_screen.dart';
import 'screens/management_portal/management_portal_screen.dart';
import 'screens/cashier_screen.dart';
import 'screens/super_admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress known Windows framework duplicate key-down assertions, mouse tracker assertions, and empty JSON input messages
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final exceptionStr = details.exception.toString();
    if (exceptionStr.contains('!_pressedKeys.containsKey') ||
        exceptionStr.contains('HardwareKeyboard._assertEventIsRegular') ||
        exceptionStr.contains('!_debugDuringDeviceUpdate') ||
        exceptionStr.contains('mouse_tracker.dart') ||
        exceptionStr.contains('The document is empty')) {
      return; // Known Flutter Windows engine/framework issue during pointer/keyboard tracking
    }
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    if (errorStr.contains('!_debugDuringDeviceUpdate') ||
        errorStr.contains('mouse_tracker.dart') ||
        errorStr.contains('!_pressedKeys.containsKey') ||
        errorStr.contains('HardwareKeyboard._assertEventIsRegular')) {
      return true; // Handled / Suppressed framework desktop assertion re-entrancy bug
    }
    return false;
  };

  // تهيئة حقن التبعيات
  await initInjection();
  final dataService = sl<DataService>();

  // قراءة الإصدار وتحميل التخزين المحلي وتهيئة الإشعارات فوراً بالتوازي بأقصى سرعة ممكنة
  await Future.wait([
    AppUpdateService.init(),
    AppNotificationService.instance.init(),
    dataService.init(),
  ]);

  // Initialize window manager for fullscreen support (Desktop only)
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        minimumSize: Size(800, 600),
        center: true,
        title: 'مَنَصَّة مِحْرَاب',
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('⚠️ Window manager not available: $e');
    }
  }

  runApp(const MasjedApp());
}

class MasjedApp extends StatelessWidget {
  const MasjedApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!sl.isRegistered<DataService>()) {
      initInjection();
    }
    final dataService = sl<DataService>();

    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionBloc>(
          create: (_) => sl<SessionBloc>()..add(const LoadSessionsEvent()),
        ),
        BlocProvider<ThemeCubit>(
          create: (_) => sl<ThemeCubit>(),
        ),
        BlocProvider<RecitationBloc>(
          create: (_) => sl<RecitationBloc>(),
        ),
        BlocProvider<TripsBloc>(
          create: (_) => sl<TripsBloc>()..add(const LoadTripsEvent()),
        ),
        BlocProvider<CoursesBloc>(
          create: (_) => sl<CoursesBloc>()..add(const LoadCoursesEvent()),
        ),
        BlocProvider<AttendanceBloc>(
          create: (_) => sl<AttendanceBloc>(),
        ),
        BlocProvider<RewardsBloc>(
          create: (_) => sl<RewardsBloc>()..add(const LoadRewardsEvent()),
        ),
        BlocProvider<CompetitionsBloc>(
          create: (_) => sl<CompetitionsBloc>()..add(const LoadCompetitionsEvent()),
        ),
      ],
      child: ChangeNotifierProvider<DataService>.value(
        value: dataService,
        child: Consumer<DataService>(
          builder: (context, data, _) {
            final effectiveThemeMode = data.isDarkMode ? ThemeMode.dark : ThemeMode.light;

            return BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, themeState) {
                // Sync globally active font family & palette for all AppTypography and AppColors calls
                AppTypography.currentFontFamily = themeState.fontFamily;
                AppColors.currentPaletteId = themeState.paletteId;
                AppColors.isDarkMode = effectiveThemeMode == ThemeMode.dark;

                return MaterialApp(
                  navigatorKey: appNavigatorKey,
                  title: 'منصة محراب - وحلقات القرآن الكريم',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.buildTheme(
                    isDark: false,
                    paletteId: themeState.paletteId,
                    fontFamily: themeState.fontFamily,
                  ),
                  darkTheme: AppTheme.buildTheme(
                    isDark: true,
                    paletteId: themeState.paletteId,
                    fontFamily: themeState.fontFamily,
                  ),
                  themeMode: effectiveThemeMode,
                  locale: const Locale('ar'),
                  supportedLocales: const [
                    Locale('ar'),
                  ],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(themeState.fontScale),
                      ),
                      child: child!,
                    );
                  },
                  home: !data.hasCompletedOnboarding
                      ? const AppOnboardingScreen()
                      : const MainShell(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final ValueNotifier<String?> targetTabNotifier = ValueNotifier<String?>(null);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver, WindowListener {
  String _activeTabId = 'events';
  String _previousTabId = 'events';
  final GlobalKey<CashierScreenState> _cashierKey = GlobalKey<CashierScreenState>();
  final ScrollController _mobileBottomNavScrollController = ScrollController();
  final GlobalKey _activeMobileTabKey = GlobalKey();
  bool _isFullscreen = false;
  bool _isTogglingFullscreen = false;
  DateTime _lastFullscreenToggle = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _updateLaunchTimer;

  void _onTabSelected(String tabId) {
    if (tabId == 'quran') {
      _previousTabId = _activeTabId;
    }
    setState(() => _activeTabId = tabId);
    _ensureActiveMobileTabVisible();
  }

  void _ensureActiveMobileTabVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeMobileTabKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    MainShell.targetTabNotifier.addListener(_handleTargetTabRequest);

    // استعلام الحالة الحقيقية الفعلية للنافذة في أنظمة سطح المكتب
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.isFullScreen().then((isFull) {
        if (mounted) setState(() => _isFullscreen = isFull);
      }).catchError((_) {});
    }

    // استمع لـ F11 و Escape عالمياً بدون الحاجة لـ focus
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // ── فحص التحديثات عند الإطلاق ─────────────────────────
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      // نؤخر ثانية واحدة حتى تستقر الواجهة الرئيسية أولاً
      _updateLaunchTimer = Timer(const Duration(milliseconds: 1000), _checkUpdateOnLaunch);

      // فحص دوري كل 6 ساعات
      AppUpdateService.instance.startPeriodicSilentCheck(
        interval: const Duration(hours: 6),
        onReadyToInstall: _showInstallSnackBar,
      );
    }
  }

  /// فحص التحديث عند فتح التطبيق وعرض نافذة التحديث أينما كان المستخدم إن وُجد إصدار جديد
  Future<void> _checkUpdateOnLaunch() async {
    final info = await AppUpdateService.instance.checkForUpdate();
    if (info == null) return;

    final targetContext = appNavigatorKey.currentContext ?? (mounted ? context : null);
    if (targetContext != null && targetContext.mounted) {
      UpdateDialog.show(targetContext, info, AppUpdateService.instance);
    }
  }

  /// يظهر نافذة التحديث مع إشعار عند اكتمال تنزيل التحديث في الخلفية
  void _showInstallSnackBar(UpdateInfo info) {
    final targetContext = appNavigatorKey.currentContext ?? (mounted ? context : null);
    if (targetContext != null && targetContext.mounted) {
      UpdateDialog.show(targetContext, info, AppUpdateService.instance);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تحديث محراب v${info.version} جاهز للتثبيت 🚀'),
        action: SnackBarAction(
          label: 'تثبيت الآن',
          onPressed: () => AppUpdateService.instance.installDownloadedUpdate(),
        ),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    MainShell.targetTabNotifier.removeListener(_handleTargetTabRequest);
    _updateLaunchTimer?.cancel();
    _mobileBottomNavScrollController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    AppUpdateService.instance.stopPeriodicCheck(); // إلغاء المؤقت الدوري
    super.dispose();
  }

  void _handleTargetTabRequest() {
    final target = MainShell.targetTabNotifier.value;
    if (target != null && mounted) {
      _onTabSelected(target);
      MainShell.targetTabNotifier.value = null;
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return false;
    }
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.f11) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleFullscreen();
      });
      return true; // استهلك الحدث ومنع تكراره
    }

    if (event.logicalKey == LogicalKeyboardKey.escape && _isFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _exitFullscreen();
      });
      return true;
    }

    return false;
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted && !_isFullscreen) {
      setState(() => _isFullscreen = true);
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted && _isFullscreen) {
      setState(() => _isFullscreen = false);
    }
  }

  /// تبديل آمن 100% للشاشة الكاملة مع قفل العمليات المتزامنة وفحص حالة النظام الحقيقية
  Future<void> _toggleFullscreen() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    if (_isTogglingFullscreen) return; // حماية من استدعاء مكرر أثناء الانتقال

    final now = DateTime.now();
    if (now.difference(_lastFullscreenToggle).inMilliseconds < 600) {
      return; // تجاهل الضغطات المتتالية وتكرار ويندوز السريع
    }
    _lastFullscreenToggle = now;
    _isTogglingFullscreen = true;

    try {
      // قراءة الحالة الحقيقية من نظام التشغيل مباشرة لتجنب أي تعليق أو عدم تزامن
      final bool currentlyFull = await windowManager.isFullScreen();
      final bool targetState = !currentlyFull;

      await windowManager.setFullScreen(targetState);
      if (Platform.isWindows) {
        await windowManager.focus();
      }
      if (mounted) {
        setState(() => _isFullscreen = targetState);
      }
    } catch (e) {
      debugPrint('⚠️ [WindowManager] خطأ أثناء تبديل وضع ملء الشاشة: $e');
    } finally {
      // انتظار وجيز لانتهاء نظام ويندوز من تغيير نمط النوافذ وإعادة فتح القفل بأمان
      await Future.delayed(const Duration(milliseconds: 350));
      _isTogglingFullscreen = false;
    }
  }

  /// خروج فوري وآمن من وضع ملء الشاشة
  Future<void> _exitFullscreen() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    if (_isTogglingFullscreen) return;

    final now = DateTime.now();
    if (now.difference(_lastFullscreenToggle).inMilliseconds < 600) return;
    _lastFullscreenToggle = now;
    _isTogglingFullscreen = true;

    try {
      final bool currentlyFull = await windowManager.isFullScreen();
      if (currentlyFull) {
        await windowManager.setFullScreen(false);
        if (Platform.isWindows) {
          await windowManager.focus();
        }
        if (mounted) {
          setState(() => _isFullscreen = false);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [WindowManager] خطأ أثناء الخروج من ملء الشاشة: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 350));
      _isTogglingFullscreen = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<DataService>().syncWithSupabase();
        // فحص التحديثات فور العودة للتطبيق لضمان تنبيه المستخدم
        _checkUpdateOnLaunch();
      }
    }
  }

  void _handleSessionUnlocked(ActiveSession session) {
    setState(() {
      switch (session.role) {
        case 'student':
          _activeTabId = 'student';
          break;
        case 'sheikh':
          _activeTabId = 'sheikh';
          break;
        case 'mosque_admin':
          _activeTabId = 'mosque_admin';
          break;
        case 'cashier':
          _activeTabId = 'cashier';
          break;
        case 'super_admin':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminScreen()));
          break;
        default:
          _activeTabId = 'events';
      }
    });
  }

  void _openScanner({String? targetRole}) {
    // Context-Aware Scanning: If user is in the Cashier tab, trigger cashier identification instead of login
    if (_activeTabId == 'cashier') {
      _cashierKey.currentState?.openScanner();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => CodeScannerDialog(
        targetRole: targetRole,
        onSessionUnlocked: (session) {
          _handleSessionUnlocked(session);
        },
      ),
    );
  }

  void _showSuperAdminLogin() {
    final data = context.read<DataService>();

    // إذا كان الجهاز محفوظاً كمصادَق، ننتقل فوراً بدون طلب بيانات
    if (data.currentSession?.role == 'super_admin') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminScreen()));
      return;
    }

    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('دخول المشرف العام (Super Admin)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'كلمة المرور'), obscureText: true),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final scaffoldMsg = ScaffoldMessenger.of(context);
                setDialogState(() => isLoading = true);
                final result = await data.superAdminLoginAsync(emailCtrl.text, passCtrl.text);
                if (!ctx.mounted) return;
                if (result == SuperAdminLoginResult.success) {
                  Navigator.pop(ctx);
                  if (mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminScreen()));
                  }
                } else {
                  setDialogState(() => isLoading = false);
                  final message = switch (result) {
                    SuperAdminLoginResult.notAuthorized =>
                      'هذا الحساب لا يملك صلاحية المشرف العام',
                    SuperAdminLoginResult.unavailable =>
                      'تعذر الوصول لخادم المصادقة، تحقق من اتصالك بالإنترنت',
                    _ => 'بيانات الدخول غير صحيحة',
                  };
                  scaffoldMsg.showSnackBar(SnackBar(content: Text(message)));
                }
              },
              child: const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfileModal() {
    final data = context.read<DataService>();
    final current = data.currentSession;
    final sessions = data.savedSessions;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الملف الشخصي والحساب',
                  style: AppTypography.font(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (current == null && sessions.isEmpty) ...[
              // Visitor View
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor,
                      child: const Icon(Icons.person_outline, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'وضع الزائر العام',
                            style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'تصفح المساجد والفعاليات والدروس والمسابقات',
                            style: AppTypography.font(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openScanner();
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(
                  'تسجيل الدخول عبر مسح كود QR أو الرمز',
                  style: AppTypography.buttonText(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else ...[
              // Simplified Logged In View - Logout Only
              const SizedBox(height: 10),
              Icon(
                Icons.account_circle,
                size: 64,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                'أنت الآن مسجل الدخول في المنصة',
                textAlign: TextAlign.center,
                style: AppTypography.font(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  data.logoutCompletely();
                  Navigator.pop(ctx);
                  // Force a full rebuild of the app shell to clear states
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تسجيل الخروج الكلي وتصفير كافة الحسابات بنجاح'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                },
                icon: const Icon(Icons.logout, size: 22),
                label: Text('تسجيل الخروج من الحساب', style: AppTypography.buttonText()),
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  List<_ShellTab> _getVisibleTabs(DataService data) {
    final session = data.currentSession;
    final isManagement = data.appMode == 'management' || data.appMode == 'admin';
    final hasMosqueAdmin = data.hasRole('mosque_admin');
    final hasSheikh = data.hasRole('sheikh');
    final hasCashier = data.hasRole('cashier');
    final hasStudent = data.hasRole('student');

    final tabs = <_ShellTab>[];

    // 1. Events & Donations tab (Default first tab)
    tabs.add(_ShellTab(
      id: 'events',
      label: 'الفعاليات والتبرع',
      shortLabel: 'الفعاليات',
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      widget: DiscoverScreen(onOpenScanner: _openScanner),
    ));

    // 2. Holy Quran section
    tabs.add(_ShellTab(
      id: 'quran',
      label: 'القرآن الكريم',
      shortLabel: 'القرآن',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      widget: QuranReaderView(
        isDark: Theme.of(context).brightness == Brightness.dark,
        onExit: () => setState(() => _activeTabId = _previousTabId),
      ),
    ));

    // 3. Islamic Content / Hadith / Ruqyah / Athkar
    tabs.add(_ShellTab(
      id: 'islamic_zad',
      label: 'الأحاديث والرقية',
      shortLabel: 'الأحاديث والرقية',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      widget: RefreshIndicator(
        onRefresh: () => data.syncWithSupabase(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: IslamicZadHubView(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    ));

    // 4. Adhan & Prayer Times
    tabs.add(_ShellTab(
      id: 'prayer_times',
      label: 'الأذان ومواقيت الصلاة',
      shortLabel: 'الأذان والمواقيت',
      icon: Icons.access_time_filled_outlined,
      activeIcon: Icons.access_time_filled_rounded,
      widget: RefreshIndicator(
        onRefresh: () => data.syncWithSupabase(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: PrayerTimesQiblaView(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    ));

    // 2. Mosque Admin tab (unlocked in management mode OR if mosque_admin role active)
    if (isManagement || hasMosqueAdmin) {
      tabs.add(_ShellTab(
        id: 'mosque_admin',
        label: 'إدارة المسجد',
        shortLabel: 'المسجد',
        icon: Icons.mosque_outlined,
        activeIcon: Icons.mosque,
        widget: MosqueAdminScreen(session: data.getSessionForRole('mosque_admin') ?? session),
      ));
    }

    // 3. Sheikh tab (unlocked in management mode OR if mosque_admin OR sheikh active)
    if (isManagement || hasMosqueAdmin || hasSheikh) {
      tabs.add(_ShellTab(
        id: 'sheikh',
        label: 'إدارة الحلقة',
        shortLabel: 'الحلقة',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        widget: SheikhScreen(session: data.getSessionForRole('sheikh') ?? session),
      ));
    }

    // 4. Student tab — like its siblings, hidden until the student's code is scanned
    //    from the authorization portal.
    if (isManagement || hasStudent) {
      final studentCount = data.getStudentSessions().length;
      final label = studentCount > 1 ? 'ملفات الأبناء' : 'تفاصيل الطالب';
      final shortLabel = studentCount > 1 ? 'الأبناء' : 'الطالب';
      tabs.add(_ShellTab(
        id: 'student',
        label: label,
        shortLabel: shortLabel,
        icon: Icons.school_outlined,
        activeIcon: Icons.school,
        widget: StudentScreen(session: data.getSessionForRole('student') ?? session),
      ));
    }

    // 5. Rankings — opens alongside any portal-unlocked tab (admin, sheikh, student),
    //    but not for a cashier-only session.
    if (isManagement || hasMosqueAdmin || hasSheikh || hasStudent) {
      tabs.add(const _ShellTab(
        id: 'rankings',
        label: 'لوحة الترتيب',
        shortLabel: 'الترتيب والأبطال',
        icon: Icons.emoji_events_outlined,
        activeIcon: Icons.emoji_events,
        widget: CompetitionScreen(),
      ));
    }

    // 6. Cashier tab (unlocked in management mode OR if mosque_admin OR cashier active)
    if (isManagement || hasMosqueAdmin || hasCashier) {
      tabs.add(_ShellTab(
        id: 'cashier',
        label: 'صراف الجوائز',
        shortLabel: 'الصراف',
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        widget: CashierScreen(key: _cashierKey),
      ));
    }

    // 7. Authorization Portal tab (available in personal mode for progressive disclosure)
    if (!isManagement) {
      tabs.add(_ShellTab(
        id: 'portal',
        label: 'بوابة الإدارة والتفويض',
        shortLabel: 'بوابة الإدارة',
        icon: Icons.security_outlined,
        activeIcon: Icons.security_rounded,
        widget: ManagementPortalScreen(
          onNavigateToTab: (tabIdx) {
            if (tabIdx == 1) {
              _onTabSelected('mosque_admin');
            } else if (tabIdx == 2) {
              _onTabSelected('sheikh');
            } else if (tabIdx == 3) {
              _onTabSelected('student');
            } else if (tabIdx == 5) {
              _onTabSelected('cashier');
            }
          },
          onSessionUnlocked: (unlockedSession) {
            _handleSessionUnlocked(unlockedSession);
          },
        ),
      ));
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final session = data.currentSession;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final visibleTabs = _getVisibleTabs(data);
    int currentIdx = visibleTabs.indexWhere((t) => t.id == _activeTabId);
    if (currentIdx == -1) {
      currentIdx = 0;
      _activeTabId = visibleTabs.first.id;
    }

    // Phones get a slimmer header so the date and actions fit without clipping.
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final logoSize = isCompact ? 36.0 : 44.0;
    final compactActionStyle = isCompact
        ? const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
            minimumSize: WidgetStatePropertyAll(Size(36, 36)),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isCompact ? 58 : 74,
        titleSpacing: isCompact ? 12 : 16,
        title: Padding(
          padding: isCompact
              ? const EdgeInsets.only(top: 4.0, bottom: 2.0)
              : const EdgeInsets.only(top: 14.0, bottom: 6.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.mosque, color: AppColors.emeraldPrimary, size: 22),
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onLongPress: _showSuperAdminLogin,
                      child: Text(
                        'مَنَصَّة مِحْرَاب',
                        style: AppTypography.font(
                          fontWeight: FontWeight.w800,
                          fontSize: isCompact ? 17.5 : 21,
                          height: 1.2,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isCompact ? 1 : 3),
                    AppHeaderDateWidget(compact: isCompact),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Settings Button
          IconButton(
            style: compactActionStyle,
            tooltip: 'إعدادات المظهر والخط',
            icon: Icon(Icons.tune_rounded, color: primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          if (!isCompact) const SizedBox(width: 4),

          // Dark/Light Theme Switcher
          IconButton(
            style: compactActionStyle,
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? AppColors.sunsetGlow : primaryColor,
            ),
            onPressed: () {
              data.toggleTheme();
              try {
                context.read<ThemeCubit>().setTheme(data.isDarkMode);
              } catch (_) {}
            },
          ),
          if (!isCompact) const SizedBox(width: 4),

          // Fullscreen Button (Desktop only)
          if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ...[
            IconButton(
              style: compactActionStyle,
              tooltip: _isFullscreen ? 'إنهاء ملء الشاشة (F11 / Esc)' : 'ملء الشاشة (F11)',
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: primaryColor,
              ),
              onPressed: _toggleFullscreen,
            ),
            if (!isCompact) const SizedBox(width: 4),
          ],

          // Profile Button
          IconButton(
            style: compactActionStyle,
            tooltip: 'الملف الشخصي والحساب',
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: primaryColor.withValues(alpha: 0.15),
              child: Icon(
                session != null ? Icons.person : Icons.account_circle_outlined,
                size: 18,
                color: primaryColor,
              ),
            ),
            onPressed: _showUserProfileModal,
          ),
          SizedBox(width: isCompact ? 4 : 8),
        ],
        // Top Horizontal Tabs Row (Desktop / Wide screens only)
        bottom: isCompact
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    border: Border(
                      top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.8),
                      bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.8),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        for (int i = 0; i < visibleTabs.length; i++) ...[
                          _buildNavTab(
                            isCompact: false,
                            isSelected: visibleTabs[i].id == _activeTabId,
                            label: visibleTabs[i].label,
                            icon: visibleTabs[i].icon,
                            activeIcon: visibleTabs[i].activeIcon,
                            primaryColor: primaryColor,
                            onTap: () => _onTabSelected(visibleTabs[i].id),
                          ),
                          if (i < visibleTabs.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
      body: visibleTabs[currentIdx].widget,
      bottomNavigationBar: isCompact
          ? _buildMobileBottomBar(
              visibleTabs: visibleTabs,
              currentIdx: currentIdx,
              primaryColor: primaryColor,
              isDark: isDark,
            )
          : null,
    );
  }

  Widget _buildMobileBottomBar({
    required List<_ShellTab> visibleTabs,
    required int currentIdx,
    required Color primaryColor,
    required bool isDark,
  }) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // When tabs exceed 4 or don't have enough width per tab (minimum 76px per tab),
              // enable smooth horizontal scrolling so text never truncates or cramps.
              final isScrollable = visibleTabs.length > 4 || (constraints.maxWidth / visibleTabs.length) < 76;
              if (!isScrollable) {
                return Row(
                  children: [
                    for (final tab in visibleTabs)
                      Expanded(
                        child: _buildMobileBottomNavItem(
                          tab: tab,
                          isSelected: tab.id == _activeTabId,
                          primaryColor: primaryColor,
                          isDark: isDark,
                        ),
                      ),
                  ],
                );
              }

              return SingleChildScrollView(
                controller: _mobileBottomNavScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    for (final tab in visibleTabs)
                      Padding(
                        key: tab.id == _activeTabId ? _activeMobileTabKey : null,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildMobileBottomNavItem(
                          tab: tab,
                          isSelected: tab.id == _activeTabId,
                          primaryColor: primaryColor,
                          isDark: isDark,
                          isScrollable: true,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNavItem({
    required _ShellTab tab,
    required bool isSelected,
    required Color primaryColor,
    required bool isDark,
    bool isScrollable = false,
  }) {
    final activeColor = primaryColor;
    final inactiveColor = isDark ? Colors.white60 : Colors.black54;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTabSelected(tab.id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: isScrollable ? const BoxConstraints(minWidth: 70) : null,
          padding: EdgeInsets.symmetric(
            vertical: 4,
            horizontal: isScrollable ? 10 : 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: isDark ? 0.22 : 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.rPill),
                ),
                child: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  size: 21,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tab.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.font(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab({
    bool isCompact = false,
    required bool isSelected,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = primaryColor;
    final inactiveText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.rPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.rPill),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 16,
              color: isSelected ? Colors.white : inactiveText,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTypography.font(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : inactiveText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellTab {
  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData activeIcon;
  final Widget widget;

  const _ShellTab({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.activeIcon,
    required this.widget,
  });
}