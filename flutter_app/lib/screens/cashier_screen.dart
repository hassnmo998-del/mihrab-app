import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../widgets/qr_dialogs.dart';
import 'cashier/dialogs/cashier_dispense_dialog.dart';
import 'cashier/cashier_records_screen.dart';

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

  /// السجلات والكشوف والفلاتر كلها في شاشة داخلية: الشاشة الأولى للصرف فقط.
  void _openRecords(String? activeMosqueId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CashierRecordsScreen(initialMosqueId: activeMosqueId),
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

    // رقما هذا الشهر للجامع النشط: يظهران على بلاطة السجلات
    final now = DateTime.now();
    final thisMonthRedemptions = ds
        .getRedemptions(mosqueId: activeCashierSession.mosqueId)
        .where((r) =>
            r.status == 'dispensed' &&
            r.dispensedAt != null &&
            r.dispensedAt!.year == now.year &&
            r.dispensedAt!.month == now.month)
        .toList();
    final monthPoints = thisMonthRedemptions.fold<int>(0, (sum, r) => sum + r.pointsSpent);

    // جامع واحد قد تكون له جلستان (صراف ومدير): يُعدّ ويُعرض مرة واحدة
    final mosqueSessions = <String, ActiveSession>{};
    for (final s in cashierSessions) {
      mosqueSessions.putIfAbsent(s.mosqueId ?? '', () => s);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppColors.terracottaPrimary, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'بوابة الصراف المعتمد',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleBold(context, fontSize: 17),
              ),
            ),
          ],
        ),
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMosquesCard(ds, mosqueSessions.values.toList(), activeCashierSession, isDark, dividerColor),
                  const SizedBox(height: 16),
                  _buildScanCard(ds, activeCashierSession, isDark, dividerColor),
                  const SizedBox(height: 16),
                  _buildRecordsTile(
                    isDark: isDark,
                    activeMosqueId: activeCashierSession.mosqueId,
                    monthCount: thisMonthRedemptions.length,
                    monthPoints: monthPoints,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// «جامع واحد»، «جامعان»، «3 جوامع»، «11 جامعاً».
  static String mosqueCountLabel(int n) {
    if (n == 1) return 'جامع واحد';
    if (n == 2) return 'جامعان';
    if (n <= 10) return '$n جوامع';
    return '$n جامعاً';
  }

  /// 1) كم جامعاً مسجّلاً عند الصراف، التبديل بينها، وإضافة جامع.
  Widget _buildMosquesCard(
    DataService ds,
    List<ActiveSession> mosques,
    ActiveSession active,
    bool isDark,
    Color dividerColor,
  ) {
    final many = mosques.length > 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mosque_rounded, color: AppColors.terracottaPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مسجّل عندك: ${mosqueCountLabel(mosques.length)}',
                      style: AppTypography.titleBold(context, fontSize: 15.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      many ? 'اضغط اسم الجامع الذي تصرف له الآن' : (active.mosqueName ?? 'جامع'),
                      style: AppTypography.verveSubtitle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (many) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in mosques)
                  ChoiceChip(
                    label: Text(s.mosqueName ?? 'جامع'),
                    selected: s.mosqueId == active.mosqueId,
                    selectedColor: AppColors.terracottaPrimary,
                    labelStyle: TextStyle(
                      color: s.mosqueId == active.mosqueId
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: s.mosqueId == active.mosqueId ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (!val) return;
                      setState(() => _manualSelectedMosqueId = s.mosqueId);
                      // Also switch global session so data lookups (students etc) are contextualized
                      ds.switchSession(s);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _handleUnlockScan(ds),
              icon: const Icon(Icons.add_business_outlined, size: 19),
              label: Text('إضافة جامع', style: AppTypography.buttonText(color: AppColors.terracottaPrimary)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.terracottaPrimary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2) العمل اليومي كله: امسح باركود الطالب، أو اكتب الكود.
  Widget _buildScanCard(DataService ds, ActiveSession active, bool isDark, Color dividerColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('صرف جائزة لطالب', style: AppTypography.verveHeaderTitle(context)),
          const SizedBox(height: 4),
          Text(
            'الصرف الآن لطلاب: ${active.mosqueName ?? 'الجامع'}',
            style: AppTypography.verveSubtitle(context),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 62,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terracottaPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
              label: Text('مسح باركود الطالب', style: AppTypography.buttonText().copyWith(fontSize: 17)),
              onPressed: () => _handleVoucherScan(ds),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('أو اكتب الكود', style: AppTypography.verveSubtitle(context)),
              ),
              Expanded(child: Divider(color: dividerColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  textCapitalization: TextCapitalization.characters,
                  style: AppTypography.bodyRegular(context, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'كود الطالب أو القسيمة',
                    hintText: 'STD-XXXX أو VCH-XXXX',
                    prefixIcon: Icon(Icons.qr_code_2),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (val) => _verifyAndDispense(ds, val),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _verifyAndDispense(ds, _voucherController.text),
                  child: Text('صرف', style: AppTypography.buttonText()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3) مدخل واحد للسجلات والكشوف والفلاتر (الشاشة الداخلية).
  Widget _buildRecordsTile({
    required bool isDark,
    required String? activeMosqueId,
    required int monthCount,
    required int monthPoints,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openRecords(activeMosqueId),
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
              child: Icon(Icons.receipt_long_rounded, color: AppColors.terracottaPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السجلات والكشوف', style: AppTypography.titleBold(context, fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Text(
                    monthCount == 0
                        ? 'ما صرفته، والمستحق لك، وكشف الإدارة'
                        : 'هذا الشهر: $monthCount جائزة • $monthPoints نقطة',
                    style: AppTypography.verveSubtitle(context),
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
