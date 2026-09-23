import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../widgets/qr_dialogs.dart';
import 'cashier/widgets/cashier_history_section.dart';
import 'cashier/dialogs/cashier_dispense_dialog.dart';
import 'cashier/cashier_full_ledger_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => CashierScreenState();
}

class CashierScreenState extends State<CashierScreen> {
  final TextEditingController _voucherController = TextEditingController();
  String? _manualSelectedMosqueId;

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  // Expose scanning for external use (AppBar QR button)
  void openScanner() {
    final ds = context.read<DataService>();
    final cashierSessions = ds.savedSessions.where((s) => s.role == 'cashier' || s.role == 'mosque_admin').toList();
    final isAuthorized = cashierSessions.isNotEmpty;

    if (isAuthorized) {
      _handleVoucherScan(ds);
    } else {
      _handleUnlockScan(ds);
    }
  }

  void _handleUnlockScan(DataService ds) {
    showDialog(
      context: context,
      builder: (ctx) => UniversalQrScannerDialog(
        title: 'فتح بوابة الصراف المعتمد',
        hintText: 'امسح كود الاعتماد الممنوح لك من مدير المسجد (CSH-)',
        onCodeScanned: (code) async {
          Navigator.pop(ctx);
          final clean = code.trim().toUpperCase();
          
          if (clean.startsWith('STD-')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عذراً، هذا كود طالب. هذه البوابة مخصصة للصراف المعتمد فقط.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }

          final session = await ds.verifyCode(clean);
          if (session != null && (session.role == 'cashier' || session.role == 'mosque_admin')) {
            setState(() {}); // Refresh to show unlocked view
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('كود الاعتماد غير صحيح أو غير مصرح له بالصرف'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _handleVoucherScan(DataService ds) {
    showDialog(
      context: context,
      builder: (ctx) => UniversalQrScannerDialog(
        title: 'مسح باركود جائزة الطالب',
        hintText: 'وجّه الكاميرا نحو باركود الطالب (STD-) أو القسيمة (VCH-)',
        onCodeScanned: (code) {
          Navigator.pop(ctx);
          _voucherController.text = code;
          _verifyAndDispense(ds, code);
        },
      ),
    );
  }

  void _verifyAndDispense(DataService ds, String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('يرجى إدخال أو مسح رمز الكود أولاً', style: AppTypography.buttonText()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 1. Direct Student Sale Flow (STD-XXXX or just XXXX matching student code)
    final student = ds.getStudents().where((s) {
      final codeMatch = s.code.toUpperCase() == clean;
      final numericMatch = clean.length >= 4 && s.code.toUpperCase().endsWith(clean);
      return codeMatch || numericMatch;
    }).firstOrNull;

    if (student != null) {
      // إذا كان الطالب من جامع آخر نحن معتمدون فيه، نقوم بتبديل السياق تلقائياً
      final cashierSessions = ds.savedSessions.where((s) => s.role == 'cashier' || s.role == 'mosque_admin').toList();
      final targetSession = cashierSessions.where((s) => s.mosqueId == student.mosqueId).firstOrNull;
      
      if (targetSession != null && targetSession.mosqueId != _manualSelectedMosqueId) {
        setState(() => _manualSelectedMosqueId = targetSession.mosqueId);
        ds.switchSession(targetSession);
      }
      
      _showStudentSaleMenu(ds, student);
      return;
    }

    // 2. Existing Voucher Flow (VCH-XXXX)
    final redemptions = ds.getRedemptions();
    final item =
        redemptions.where((r) => r.redemptionCode.toUpperCase() == clean).firstOrNull;

    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز القسيمة غير موجود أو غير صالح'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // التحقق من حالة الجائزة: لا يمكن صرف قسيمة لجائزة قام المدير بإيقافها
    final originalReward = ds.getRewards().where((r) => r.id == item.rewardId).firstOrNull;
    if (originalReward != null && !originalReward.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، هذه الجائزة موقوفة حالياً من قبل الإدارة ولا يمكن تسليمها.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (item.status == 'dispensed') {
      CashierDispenseDialog.showAlreadyDispensed(context, item);
      return;
    }

    CashierDispenseDialog.showConfirmDispense(
      context: context,
      ds: ds,
      item: item,
      voucherCode: clean,
      onSuccess: () => _voucherController.clear(),
    );
  }

  /// يفتح السجل الكامل: كشف جاهز للإدارة بجامع وفترة محددين.
  void _openFullLedger({
    required Map<String, String> mosqueOptions,
    required String? activeMosqueId,
    required String cashierLabel,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CashierFullLedgerScreen(
          mosqueOptions: mosqueOptions,
          initialMosqueId: activeMosqueId,
          cashierLabel: cashierLabel,
        ),
      ),
    );
  }

  void _showStudentSaleMenu(DataService ds, Student student) {
    // جلب الجوائز وتصفيتها لتشمل فقط الجوائز النشطة (isActive) كما طلب المدير
    final rewards = ds.getRewards(mosqueId: student.mosqueId).where((r) => r.isActive).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: AppColors.terracottaPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.fullName, style: AppTypography.titleBold(context, fontSize: 18)),
                        Text('رصيد الطالب: ${student.totalPoints} نقطة 🪙',
                            style: AppTypography.bodyRegular(context, color: AppColors.goldDark, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 32),
              Text('الجوائز المتاحة لهذا الطالب:', style: AppTypography.verveHeaderTitle(context)),
              const SizedBox(height: 12),
              Expanded(
                child: rewards.isEmpty
                    ? const Center(child: Text('لا توجد جوائز مفعلة في مسجد الطالب حالياً'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: rewards.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final r = rewards[i];
                          final canAfford = student.totalPoints >= r.pointsCost;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.title, style: AppTypography.titleBold(context, fontSize: 15)),
                            subtitle: Text('${r.pointsCost} نقطة',
                                style: TextStyle(color: canAfford ? AppColors.emeraldPrimary : Colors.red)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAfford ? AppColors.terracottaPrimary : Colors.grey.shade300,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                elevation: 0,
                              ),
                              onPressed: canAfford
                                  ? () {
                                      Navigator.pop(ctx);
                                      CashierDispenseDialog.showConfirmDirectSale(
                                        context: context,
                                        ds: ds,
                                        student: student,
                                        reward: r,
                                        onSuccess: () => _voucherController.clear(),
                                      );
                                    }
                                  : null,
                              child: Text(canAfford ? 'صرف وتسليم' : 'النقاط لا تكفي'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بطاقة الوصول السريع للسجل الكامل — ما تطلبه الإدارة عند المحاسبة.
  Widget _buildFullLedgerCta({
    required bool isDark,
    required Color dividerColor,
    required Map<String, String> mosqueOptions,
    required String? activeMosqueId,
    required String cashierLabel,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openFullLedger(
        mosqueOptions: mosqueOptions,
        activeMosqueId: activeMosqueId,
        cashierLabel: cashierLabel,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.goldSoftBg,
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
              child: Icon(Icons.fact_check_rounded,
                  color: AppColors.terracottaPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السجل الكامل للإدارة 📋',
                      style: AppTypography.titleBold(context, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    'كشف جاهز لجامع وفترة محددين: كم نقطة انسحبت، وما المستحق لك بالمال حسب الجوائز — قابل للمشاركة أو التصدير Excel.',
                    style: AppTypography.verveSubtitle(context)
                        .copyWith(fontSize: 11.5),
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

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final allSavedSessions = ds.savedSessions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    // جلب كافة رتب الصراف أو مدير المسجد المعتمدة على هذا الجهاز
    final cashierSessions = allSavedSessions.where((s) => s.role == 'cashier' || s.role == 'mosque_admin').toList();
    final isAuthorized = cashierSessions.isNotEmpty;

    if (!isAuthorized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'بوابة الصراف المعتمد فقط',
              style: AppTypography.titleBold(context, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'هذه الصفحة مخصصة لاستخدام صراف المسجد لصرف الجوائز.\nيرجى استخدام كود اعتماد الصراف للوصول.',
              textAlign: TextAlign.center,
              style: AppTypography.verveSubtitle(context),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _handleUnlockScan(ds),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('مسح كود اعتماد الصراف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // تحديد الرتبة النشطة حالياً في واجهة الصراف
    // نفضل الرتبة المختارة يدوياً، أو الحالية إذا كانت صراف، أو أول واحدة في القائمة
    final ActiveSession activeCashierSession;
    if (_manualSelectedMosqueId != null && cashierSessions.any((s) => s.mosqueId == _manualSelectedMosqueId)) {
      activeCashierSession = cashierSessions.firstWhere((s) => s.mosqueId == _manualSelectedMosqueId);
    } else if (ds.currentSession != null && (ds.currentSession!.role == 'cashier' || ds.currentSession!.role == 'mosque_admin')) {
      activeCashierSession = ds.currentSession!;
    } else {
      activeCashierSession = cashierSessions.first;
    }

    // Stats calculation filtered by active mosque
    final allRedemptions = ds.getRedemptions(mosqueId: activeCashierSession.mosqueId);
    final now = DateTime.now();
    final thisMonthRedemptions = allRedemptions.where((r) =>
    r.status == 'dispensed' &&
        r.dispensedAt != null &&
        r.dispensedAt!.year == now.year &&
        r.dispensedAt!.month == now.month
    ).toList();

    final totalPointsDispensedMonth = thisMonthRedemptions.fold<int>(0, (sum, r) => sum + r.pointsSpent);

    // بيانات سجل الصرف: تشمل كل الجوامع المعتمد الصراف فيها ليتمكن من الفرز والتنسيق بينها
    final authorizedMosqueIds = cashierSessions
        .map((s) => s.mosqueId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final ledgerRedemptions = ds
        .getRedemptions()
        .where((r) => authorizedMosqueIds.contains(r.mosqueId))
        .toList();
    final ledgerRewards = ds
        .getRewards()
        .where((r) => authorizedMosqueIds.contains(r.mosqueId))
        .toList();
    final ledgerStudents = ds
        .getStudents()
        .where((st) => authorizedMosqueIds.contains(st.mosqueId))
        .toList();
    final ledgerHalaqat = ds
        .getHalaqat()
        .where((h) => authorizedMosqueIds.contains(h.mosqueId))
        .toList();
    final mosqueOptions = <String, String>{
      for (final s in cashierSessions)
        if (s.mosqueId != null && s.mosqueId!.isNotEmpty)
          s.mosqueId!: s.mosqueName ?? 'جامع'
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppColors.terracottaPrimary, size: 22),
            const SizedBox(width: 10),
            Text('بوابة الصراف المعتمد', style: AppTypography.titleBold(context, fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'السجل الكامل للإدارة 📋',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => _openFullLedger(
              mosqueOptions: mosqueOptions,
              activeMosqueId: activeCashierSession.mosqueId,
              cashierLabel: activeCashierSession.name,
            ),
          ),
          IconButton(
            tooltip: 'إضافة جامع آخر للصرف ➕',
            icon: const Icon(Icons.add_business_outlined),
            onPressed: () => _handleUnlockScan(ds),
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ds.syncWithSupabase(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mosque Switcher Bar
          if (cashierSessions.length > 1)
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                border: Border(bottom: BorderSide(color: dividerColor)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: cashierSessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final s = cashierSessions[idx];
                  final isSelected = s.mosqueId == activeCashierSession.mosqueId;
                  return ChoiceChip(
                    label: Text(s.mosqueName ?? 'جامع'),
                    selected: isSelected,
                    selectedColor: AppColors.terracottaPrimary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _manualSelectedMosqueId = s.mosqueId);
                        // Also switch global session so data lookups (students etc) are contextualized
                        ds.switchSession(s);
                      }
                    },
                  );
                },
              ),
            ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ds.syncWithSupabase(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. PRIMARY ACTION: Scanning / Input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مسح هوية الطالب وصرف المكافأة 📍',
                                style: AppTypography.verveHeaderTitle(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'أنت الآن في: ${activeCashierSession.mosqueName}. امسح باركود الطالب (STD-) لبدء الصرف.',
                                style: AppTypography.verveSubtitle(context),
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 460;
                                  final textField = TextField(
                                    controller: _voucherController,
                                    textCapitalization: TextCapitalization.characters,
                                    style: AppTypography.bodyRegular(context, fontSize: 14),
                                    decoration: const InputDecoration(
                                      labelText: 'كود الطالب أو القسيمة *',
                                      hintText: 'STD-XXXX أو VCH-XXXX',
                                      prefixIcon: Icon(Icons.qr_code_2),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    onSubmitted: (val) => _verifyAndDispense(ds, val),
                                  );

                                  final scanButton = ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.terracottaPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.camera_alt_outlined, size: 22),
                                    label: Text('فتح الكاميرا للمسح', style: AppTypography.buttonText()),
                                    onPressed: () => _handleVoucherScan(ds),
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        textField,
                                        const SizedBox(height: 12),
                                        scanButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: textField),
                                      const SizedBox(width: 12),
                                      scanButton,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Secondary: Identity & Stats
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.sunsetTwilightGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadows.heroBanner,
                        ),
                        child: Row(
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
                                    activeCashierSession.name,
                                    style: AppTypography.titleBold(context, fontSize: 18, color: Colors.white),
                                  ),
                                  Text(
                                    'كود النقطة: ${activeCashierSession.code} • ${activeCashierSession.mosqueName ?? "نظام الصرف المعتمد"}',
                                    style: AppTypography.bodyRegular(context, fontSize: 12, color: const Color(0xFFF9EAE1)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verve Stats Mini Row
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text('${thisMonthRedemptions.length}', style: AppTypography.titleBold(context, fontSize: 24, color: AppColors.terracottaPrimary)),
                                  Text('جوائز صُرفت (هذا الشهر)', style: AppTypography.bodyRegular(context, fontSize: 11)),
                                ],
                              ),
                            ),
                            VerticalDivider(width: 1, thickness: 0.8, color: dividerColor),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('$totalPointsDispensedMonth', style: AppTypography.titleBold(context, fontSize: 24, color: AppColors.gold)),
                                  Text('إجمالي النقاط المستبدلة', style: AppTypography.bodyRegular(context, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // زر السجل الكامل: كشف رسمي للإدارة بجامع وفترة محددين
                      _buildFullLedgerCta(
                        isDark: isDark,
                        dividerColor: dividerColor,
                        mosqueOptions: mosqueOptions,
                        activeMosqueId: activeCashierSession.mosqueId,
                        cashierLabel: activeCashierSession.name,
                      ),
                      const SizedBox(height: 24),
                      Divider(height: 1, thickness: 0.8, color: dividerColor),
                      const SizedBox(height: 20),

                      // سجل الصرف والمستحقات (مع الفلاتر والفرز)
                      CashierHistorySection(
                        allRedemptions: ledgerRedemptions,
                        allRewards: ledgerRewards,
                        students: ledgerStudents,
                        halaqat: ledgerHalaqat,
                        mosqueOptions: mosqueOptions,
                        activeMosqueId: activeCashierSession.mosqueId ?? 'all',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}