import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/data_service.dart';
import 'cashier_full_ledger_screen.dart';
import 'widgets/cashier_history_section.dart';

/// السجلات والكشوف: كل ما ليس صرفاً مباشراً من شاشة الصراف.
///
/// الشاشة الأولى للصراف فيها الصرف وحده؛ هنا هويته ورقما الشهر، كشف الإدارة
/// الكامل، وسجل الصرف ببحثه وفلاتره.
class CashierRecordsScreen extends StatelessWidget {
  /// الجامع النشط في شاشة الصراف حين فُتحت هذه الشاشة.
  final String? initialMosqueId;

  const CashierRecordsScreen({super.key, this.initialMosqueId});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cashierSessions =
        ds.savedSessions.where((s) => s.role == 'cashier' || s.role == 'mosque_admin').toList();

    if (cashierSessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('السجلات والكشوف', style: AppTypography.titleBold(context, fontSize: 17))),
        body: Center(
          child: Text('لا يوجد اعتماد صراف على هذا الجهاز', style: AppTypography.verveSubtitle(context)),
        ),
      );
    }

    final ActiveSession active = cashierSessions.firstWhere(
      (s) => s.mosqueId == initialMosqueId,
      orElse: () => cashierSessions.first,
    );

    final now = DateTime.now();
    final thisMonth = ds
        .getRedemptions(mosqueId: active.mosqueId)
        .where((r) =>
            r.status == 'dispensed' &&
            r.dispensedAt != null &&
            r.dispensedAt!.year == now.year &&
            r.dispensedAt!.month == now.month)
        .toList();
    final monthPoints = thisMonth.fold<int>(0, (sum, r) => sum + r.pointsSpent);

    // السجل يشمل كل الجوامع المعتمد الصراف فيها ليتمكن من الفرز والتنسيق بينها
    final authorizedMosqueIds = cashierSessions
        .map((s) => s.mosqueId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final mosqueOptions = <String, String>{
      for (final s in cashierSessions)
        if (s.mosqueId != null && s.mosqueId!.isNotEmpty) s.mosqueId!: s.mosqueName ?? 'جامع'
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('السجلات والكشوف', style: AppTypography.titleBold(context, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ds.syncWithSupabase(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ds.syncWithSupabase(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _identityBanner(context, active, thisMonth.length, monthPoints),
                  const SizedBox(height: 14),
                  _fullLedgerCta(
                    context,
                    isDark: isDark,
                    mosqueOptions: mosqueOptions,
                    activeMosqueId: active.mosqueId,
                    cashierLabel: active.name,
                  ),
                  const SizedBox(height: 20),
                  CashierHistorySection(
                    allRedemptions:
                        ds.getRedemptions().where((r) => authorizedMosqueIds.contains(r.mosqueId)).toList(),
                    allRewards: ds.getRewards().where((r) => authorizedMosqueIds.contains(r.mosqueId)).toList(),
                    students: ds.getStudents().where((st) => authorizedMosqueIds.contains(st.mosqueId)).toList(),
                    halaqat: ds.getHalaqat().where((h) => authorizedMosqueIds.contains(h.mosqueId)).toList(),
                    mosqueOptions: mosqueOptions,
                    activeMosqueId: active.mosqueId ?? 'all',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// هوية نقطة الصرف ورقما هذا الشهر للجامع النشط.
  Widget _identityBanner(BuildContext context, ActiveSession active, int monthCount, int monthPoints) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: AppTypography.titleBold(context, fontSize: 22, color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.bodyRegular(context, fontSize: 11, color: const Color(0xFFF9EAE1)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.sunsetTwilightGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.heroBanner,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active.name,
                      style: AppTypography.titleBold(context, fontSize: 17, color: Colors.white),
                    ),
                    Text(
                      'كود النقطة: ${active.code} • ${active.mosqueName ?? "نظام الصرف المعتمد"}',
                      style: AppTypography.bodyRegular(context, fontSize: 12, color: const Color(0xFFF9EAE1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('$monthCount', 'جوائز صُرفت (هذا الشهر)'),
              Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.18)),
              stat('$monthPoints', 'إجمالي النقاط المستبدلة'),
            ],
          ),
        ],
      ),
    );
  }

  /// بطاقة السجل الكامل — ما تطلبه الإدارة عند المحاسبة.
  Widget _fullLedgerCta(
    BuildContext context, {
    required bool isDark,
    required Map<String, String> mosqueOptions,
    required String? activeMosqueId,
    required String cashierLabel,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CashierFullLedgerScreen(
            mosqueOptions: mosqueOptions,
            initialMosqueId: activeMosqueId,
            cashierLabel: cashierLabel,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.goldSoftBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.goldSoftBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.fact_check_rounded, color: AppColors.terracottaPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السجل الكامل للإدارة 📋', style: AppTypography.titleBold(context, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    'كشف جاهز لجامع وفترة محددين: كم نقطة انسحبت، وما المستحق لك بالمال حسب الجوائز — قابل للمشاركة أو التصدير Excel.',
                    style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: isDark ? Colors.white38 : Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
