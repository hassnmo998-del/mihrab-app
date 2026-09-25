import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../presentation/widgets/unified_badge.dart';
import '../../../services/adhan_service.dart';

/// Modal dialog ensuring all Android permissions (Notifications, Exact Alarms,
/// Battery Optimization Exemption) are diagnosed and properly configured.
class AdhanPermissionsDialog extends StatefulWidget {
  final bool isDark;

  const AdhanPermissionsDialog({super.key, required this.isDark});

  static Future<bool> show(BuildContext context, {required bool isDark}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdhanPermissionsDialog(isDark: isDark),
    );
    return result ?? false;
  }

  @override
  State<AdhanPermissionsDialog> createState() => _AdhanPermissionsDialogState();
}

class _AdhanPermissionsDialogState extends State<AdhanPermissionsDialog>
    with WidgetsBindingObserver {
  AdhanPermissionsStatus? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final status = await AdhanService.instance.checkPermissionsStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final status = _status;
    final bool allDone = status?.isFullyGuaranteed ?? false;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      color: AppColors.goldDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'صلاحيات الأذان الموثوق',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.obsidianEspresso,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'لضمان صدح الأذان في وقته بدقة حتى عند قفل الشاشة',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Item 1: Notifications
                _permissionRow(
                  icon: Icons.notifications_active_rounded,
                  title: 'إذن الإشعارات والصوت',
                  desc: 'السماح للتطبيق بإظهار إشعار الأذان وإطلاق الصوت',
                  isGranted: status?.notificationsGranted ?? false,
                  actionLabel: 'منح الإذن',
                  onAction: () async {
                    await AdhanService.instance.requestNotificationPermission();
                    await _checkStatus();
                  },
                ),
                const SizedBox(height: 10),

                // Item 2: Exact Alarms
                _permissionRow(
                  icon: Icons.alarm_rounded,
                  title: 'التنبيه في الوقت الفعلي الدقيق',
                  desc: 'منع نظام أندرويد من تأخير موعد الأذان عبر جدولة التنبيهات الدقيقة',
                  isGranted: status?.exactAlarmsGranted ?? false,
                  actionLabel: 'تفعيل التنبيه الدقيق',
                  onAction: () async {
                    await AdhanService.instance.requestExactAlarmPermission();
                    await _checkStatus();
                  },
                ),
                const SizedBox(height: 10),

                // Item 3: Ignore Battery Optimization
                _permissionRow(
                  icon: Icons.battery_saver_rounded,
                  title: 'استثناء من توفير الطاقة والبطارية',
                  desc: 'منع تجميد أو إغلاق تطبيق محراب أثناء سكون الجهاز وقفل الشاشة',
                  isGranted: status?.batteryOptimizationIgnored ?? false,
                  actionLabel: 'إلغاء قيود البطارية',
                  onAction: () async {
                    await AdhanService.instance.requestIgnoreBatteryOptimizations();
                    await _checkStatus();
                  },
                ),

                const SizedBox(height: 16),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: AppColors.goldDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          allDone
                              ? 'ممتاز! كافة الصلاحيات مكتملة، سيعمل الأذان بدقة متناهية.'
                              : 'يرجى استكمال الصلاحيات المتبقية لضمان عدم توقف الأذان بالخلفية.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Allow activating
                          Navigator.of(context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: allDone
                              ? Theme.of(context).primaryColor
                              : AppColors.goldDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          allDone ? Icons.check_circle_rounded : Icons.notifications_active_rounded,
                          size: 18,
                        ),
                        label: Text(
                          allDone ? 'تأكيد تفعيل الأذان' : 'تفعيل مع المتابعة',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final isDark = widget.isDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              size: 20,
              color: isGranted ? Colors.green : Colors.amber.shade800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.obsidianEspresso,
                        ),
                      ),
                    ),
                    UnifiedBadge(
                      label: isGranted ? 'ممنوح' : 'مطلوب',
                      backgroundColor: isGranted
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      textColor: isGranted ? Colors.green : Colors.amber.shade900,
                      icon: isGranted ? Icons.check : Icons.priority_high,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.3,
                  ),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: Text(
                        actionLabel,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
