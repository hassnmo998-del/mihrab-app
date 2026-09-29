import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/adhan_service.dart';

/// Floating bottom card designed specifically for elderly worshippers to effortlessly
/// activate Adhan prayer notifications with clear, step-by-step guidance.
class AdhanActivationFloatingBanner extends StatefulWidget {
  final bool isDark;

  const AdhanActivationFloatingBanner({super.key, required this.isDark});

  @override
  State<AdhanActivationFloatingBanner> createState() =>
      _AdhanActivationFloatingBannerState();
}

class _AdhanActivationFloatingBannerState
    extends State<AdhanActivationFloatingBanner> with WidgetsBindingObserver {
  static const String _prefDismissedKey = 'adhan_activation_banner_dismissed';

  bool _isDismissed = false;
  bool _isStepMode = false;
  bool _isLoading = true;
  bool _isCompleted = false;

  AdhanPermissionsStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isStepMode && !_isCompleted) {
      _checkPermissionsAndAdvance();
    }
  }

  Future<void> _checkInitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDismissed = prefs.getBool(_prefDismissedKey) ?? false;

      final isEnabled = AdhanService.instance.isEnabledNotifier.value;
      final status = await AdhanService.instance.checkPermissionsStatus();

      if (mounted) {
        setState(() {
          _permissionStatus = status;
          _isLoading = false;
          // If already fully guaranteed and enabled, don't show
          if (isEnabled && status.isFullyGuaranteed) {
            _isDismissed = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissionsAndAdvance() async {
    final status = await AdhanService.instance.checkPermissionsStatus();
    if (!mounted) return;

    setState(() => _permissionStatus = status);

    // If all granted, complete & destroy
    if (status.isFullyGuaranteed) {
      await _onAllPermissionsGranted();
    }
  }

  Future<void> _onAllPermissionsGranted() async {
    setState(() => _isCompleted = true);

    await AdhanService.instance.setAdhanEnabled(true);
    await AdhanService.instance.rescheduleNativeAlarms();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDismissedKey, true);

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() => _isDismissed = true);
    }
  }

  Future<void> _dismissBanner() async {
    setState(() => _isDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || _isLoading) return const SizedBox.shrink();

    // On web, alarms don't apply
    if (kIsWeb) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: AdhanService.instance.isEnabledNotifier,
      builder: (context, isEnabled, _) {
        if (isEnabled && (_permissionStatus?.isFullyGuaranteed ?? false)) {
          return const SizedBox.shrink();
        }

        final isDark = widget.isDark;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          margin: const EdgeInsets.only(top: 14, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF064E3B),
                      const Color(0xFF047857),
                    ]
                  : [
                      const Color(0xFFECFDF5),
                      const Color(0xFFD1FAE5),
                    ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF059669),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isCompleted
              ? _buildCompletedView(isDark)
              : (_isStepMode ? _buildStepView(isDark) : _buildInitialQuestionView(isDark)),
        );
      },
    );
  }

  // --- Step 1: Initial Question View ---
  Widget _buildInitialQuestionView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF059669),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'هل تريد تفعيل صوت الأذان؟ 🕌',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF064E3B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ليصدح الأذان في هاتفك عند دخول وقت كل صلاة، حتى لو كانت الشاشة مقفولة أو التطبيق مغلقاً.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isDark ? Colors.white70 : const Color(0xFF065F46),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // "لا، ليس الآن" button
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _dismissBanner,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'لا، ليس الآن',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // "نعم، تفعيل الأذان" button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isStepMode = true);
                  _checkPermissionsAndAdvance();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'نعم، تفعيل الأذان 🔔',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 2: Step-by-Step Guidance View ---
  Widget _buildStepView(bool isDark) {
    final status = _permissionStatus;
    final needsNotification = !(status?.notificationsGranted ?? false);
    final needsExactAlarm = !(status?.exactAlarmsGranted ?? false);
    final needsBattery = !(status?.batteryOptimizationIgnored ?? false);

    String stepTitle;
    String stepDesc;
    String btnLabel;
    IconData btnIcon;
    VoidCallback onBtnTap;

    if (needsNotification) {
      stepTitle = 'الخطوة 1: السماح بإظهار تنبيهات الصلاة 🔔';
      stepDesc = 'اضغط على الزر أدناه، ثم اختر (سماح) عند ظهور نافذة الهاتف ليتمكن من تنبيهك بالصلاة.';
      btnLabel = 'السماح بإشعارات الأذان والصوت';
      btnIcon = Icons.notification_add_rounded;
      onBtnTap = () async {
        await AdhanService.instance.requestNotificationPermission();
        await _checkPermissionsAndAdvance();
      };
    } else if (needsExactAlarm) {
      stepTitle = 'الخطوة 2: السماح بالتنبيه في الوقت الدقيق ⏰';
      stepDesc = 'ليصدح الأذان في نفس دقيقة دخول الوقت دون أي تأخير من نظام الهاتف.';
      btnLabel = 'تفعيل التنبيه في الموعد الدقيق';
      btnIcon = Icons.alarm_on_rounded;
      onBtnTap = () async {
        await AdhanService.instance.requestExactAlarmPermission();
        await _checkPermissionsAndAdvance();
      };
    } else if (needsBattery) {
      stepTitle = 'الخطوة الأخيرة: السماح بالعمل أثناء قفل الشاشة 🔋';
      stepDesc = 'لمنع نظام الهاتف من إيقاف أو تجميد صوت الأذان عندما يكون الجهاز في جيبك.';
      btnLabel = 'منع إيقاف الأذان أثناء قفل الشاشة';
      btnIcon = Icons.battery_charging_full_rounded;
      onBtnTap = () async {
        await AdhanService.instance.requestIgnoreBatteryOptimizations();
        await _checkPermissionsAndAdvance();
      };
    } else {
      // All done!
      return _buildCompletedView(isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                color: Color(0xFF059669),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                stepTitle,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF064E3B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          stepDesc,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: isDark ? Colors.white70 : const Color(0xFF065F46),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: onBtnTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          icon: Icon(btnIcon, size: 20),
          label: Text(
            btnLabel,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // --- Step 3: Success Completed View ---
  Widget _buildCompletedView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 36),
        const SizedBox(height: 8),
        const Text(
          'تم تفعيل الأذان بنجاح! 🕌',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'سيصدح الأذان في هاتفك عند دخول وقت كل صلاة بإذن الله. تقبل الله طاعاتكم 🤲',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.white70),
        ),
      ],
    );
  }
}
