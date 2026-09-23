import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../presentation/widgets/widgets.dart';
import '../../services/data_service.dart';
import 'models/cashier_ledger_report.dart';
import 'services/cashier_ledger_export.dart';
import 'services/reward_price_store.dart';

/// السجل الكامل لصرف الجوائز — الكشف الرسمي الذي يسلّمه الصراف لإدارة الجامع.
///
/// يجيب عن أربعة أسئلة تطلبها الإدارة عادة: أي جامع، أي فترة، كم نقطة انسحبت،
/// وكم يستحق الصراف بالمال مقابل الجوائز التي سلّمها؛ مع إمكانية مشاركة الكشف
/// نصياً أو تصديره ملف Excel.
class CashierFullLedgerScreen extends StatefulWidget {
  /// الجوامع المعتمد الصراف للصرف فيها: المعرّف -> الاسم.
  final Map<String, String> mosqueOptions;

  /// الجامع المفتوح ابتداءً (الجامع النشط في شاشة الصراف).
  final String? initialMosqueId;

  /// اسم الصراف كما يظهر في ترويسة الكشف.
  final String cashierLabel;

  const CashierFullLedgerScreen({
    super.key,
    required this.mosqueOptions,
    required this.cashierLabel,
    this.initialMosqueId,
  });

  @override
  State<CashierFullLedgerScreen> createState() =>
      _CashierFullLedgerScreenState();
}

class _CashierFullLedgerScreenState extends State<CashierFullLedgerScreen> {
  static const String _allMosques = 'all';

  late String _mosqueFilter;
  String _halaqaFilter = 'all';
  LedgerPeriod _period = LedgerPeriod.thisMonth();
  String _periodKey = 'month';
  bool _includePending = true;
  bool _showDetails = true;

  /// التسعيرة المحمّلة للجامع المختار: معرّف الجائزة -> ثمن الوحدة.
  Map<String, double> _prices = {};
  String _currency = RewardPriceStore.defaultCurrency;
  bool _loadingPrices = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMosqueId;
    _mosqueFilter = (initial != null && widget.mosqueOptions.containsKey(initial))
        ? initial
        : (widget.mosqueOptions.length == 1
            ? widget.mosqueOptions.keys.first
            : _allMosques);
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    setState(() => _loadingPrices = true);
    final currency = await RewardPriceStore.loadCurrency();
    // عند عرض كل الجوامع نجمع تسعيرة كل جامع معتمد في خريطة واحدة
    final ids = _mosqueFilter == _allMosques
        ? widget.mosqueOptions.keys.toList()
        : [_mosqueFilter];
    final merged = <String, double>{};
    for (final id in ids) {
      merged.addAll(await RewardPriceStore.loadPrices(id));
    }
    if (!mounted) return;
    setState(() {
      _prices = merged;
      _currency = currency;
      _loadingPrices = false;
    });
  }

  // ===========================================================
  // بناء الكشف
  // ===========================================================
  CashierLedgerReport _buildReport(DataService ds) {
    final authorizedIds = widget.mosqueOptions.keys.toSet();
    final scopedIds =
        _mosqueFilter == _allMosques ? authorizedIds : {_mosqueFilter};

    final redemptions = ds
        .getRedemptions()
        .where((r) => scopedIds.contains(r.mosqueId))
        .toList();
    final rewards =
        ds.getRewards().where((r) => scopedIds.contains(r.mosqueId)).toList();
    final students =
        ds.getStudents().where((s) => scopedIds.contains(s.mosqueId)).toList();
    final halaqat =
        ds.getHalaqat().where((h) => scopedIds.contains(h.mosqueId)).toList();

    return CashierLedgerReport.build(
      redemptions: redemptions,
      rewards: rewards,
      students: students,
      halaqat: halaqat,
      mosqueLabel: _mosqueFilter == _allMosques
          ? 'كل الجوامع المعتمدة (${widget.mosqueOptions.length})'
          : (widget.mosqueOptions[_mosqueFilter] ?? 'الجامع'),
      period: _period,
      cashierLabel: widget.cashierLabel,
      mosqueId: _mosqueFilter == _allMosques ? null : _mosqueFilter,
      halaqaId: _halaqaFilter == 'all' ? null : _halaqaFilter,
      unitPrices: _prices,
      currency: _currency,
      includePending: _includePending,
    );
  }

  List<Halaqa> _halaqaScope(DataService ds) {
    final ids = _mosqueFilter == _allMosques
        ? widget.mosqueOptions.keys.toSet()
        : {_mosqueFilter};
    return ds.getHalaqat().where((h) => ids.contains(h.mosqueId)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ===========================================================
  // الأحداث
  // ===========================================================
  void _setPeriod(String key) {
    setState(() {
      _periodKey = key;
      switch (key) {
        case 'today':
          _period = LedgerPeriod.today();
          break;
        case 'week':
          _period = LedgerPeriod.thisWeek();
          break;
        case 'month':
          _period = LedgerPeriod.thisMonth();
          break;
        case 'last_month':
          _period = LedgerPeriod.lastMonth();
          break;
        default:
          _period = const LedgerPeriod.all();
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = (_period.from != null && _period.to != null)
        ? DateTimeRange(start: _period.from!, end: _period.to!)
        : DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: 'اختر فترة الكشف',
      saveText: 'اعتماد',
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _periodKey = 'custom';
      _period = LedgerPeriod.custom(picked.start, picked.end);
    });
  }

  void _showToast(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.buttonText()),
        backgroundColor: color ?? AppColors.emeraldSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareStatement(CashierLedgerReport report) async {
    await CashierLedgerExport.shareText(
      report.toPlainText(includeDetails: _showDetails),
    );
  }

  Future<void> _copyStatement(CashierLedgerReport report) async {
    await CashierLedgerExport.copyToClipboard(
      report.toPlainText(includeDetails: _showDetails),
    );
    _showToast('تم نسخ الكشف الكامل إلى الحافظة ✅');
  }

  Future<void> _exportCsv(CashierLedgerReport report) async {
    final path = await CashierLedgerExport.shareCsv(
      csv: report.toCsv(),
      fileNamePrefix: report.fileNamePrefix(),
    );
    if (path == null) {
      _showToast('تعذّر حفظ الملف على هذا الجهاز', color: Colors.redAccent);
      return;
    }
    _showToast('تم حفظ نسخة Excel في: $path');
  }

  // ===========================================================
  // Build
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final report = _buildReport(ds);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.fact_check_rounded,
                color: AppColors.terracottaPrimary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('السجل الكامل للجوائز',
                  style: AppTypography.titleBold(context, fontSize: 17)),
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
      bottomNavigationBar: _buildActionBar(context, report, isDark),
      body: RefreshIndicator(
        onRefresh: () => ds.syncWithSupabase(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatementHeader(context, report),
                  const SizedBox(height: 14),
                  _buildFilters(context, ds, isDark, dividerColor),
                  const SizedBox(height: 14),
                  _buildSummary(context, report, isDark),
                  const SizedBox(height: 14),
                  _buildPricingSection(context, report, isDark, dividerColor),
                  const SizedBox(height: 14),
                  _buildBreakdown(
                    context: context,
                    isDark: isDark,
                    title: 'التفصيل حسب الجائزة',
                    subtitle: 'هذا هو أساس محاسبة الصراف بالمال',
                    icon: Icons.card_giftcard_rounded,
                    groups: report.byReward,
                    report: report,
                    unitLabel: 'قطعة',
                    showMoney: true,
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdown(
                    context: context,
                    isDark: isDark,
                    title: 'التفصيل حسب الحلقة',
                    subtitle: 'من أي حلقة انسحبت النقاط',
                    icon: Icons.groups_2_outlined,
                    groups: report.byHalaqa,
                    report: report,
                    unitLabel: 'جائزة',
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdown(
                    context: context,
                    isDark: isDark,
                    title: 'التفصيل حسب الطالب',
                    subtitle: 'الطلاب المستفيدون خلال الفترة',
                    icon: Icons.person_outline_rounded,
                    groups: report.byStudent,
                    report: report,
                    unitLabel: 'جائزة',
                    collapsible: true,
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdown(
                    context: context,
                    isDark: isDark,
                    title: 'التفصيل حسب اليوم',
                    subtitle: 'حركة الصرف يوماً بيوم',
                    icon: Icons.calendar_month_rounded,
                    groups: report.byDay,
                    report: report,
                    unitLabel: 'جائزة',
                    collapsible: true,
                  ),
                  const SizedBox(height: 18),
                  _buildDetailedList(context, report, isDark, dividerColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // ترويسة الكشف
  // ===========================================================
  Widget _buildStatementHeader(
      BuildContext context, CashierLedgerReport report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.sunsetTwilightGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.heroBanner,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('كشف صرف الجوائز',
                        style: AppTypography.titleBold(context,
                            fontSize: 18, color: Colors.white)),
                    Text(
                      report.mosqueLabel,
                      style: AppTypography.bodyRegular(context,
                          fontSize: 12.5, color: const Color(0xFFF9EAE1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(Icons.date_range_rounded, report.period.label),
              _headerChip(Icons.point_of_sale_rounded, report.cashierLabel),
              _headerChip(Icons.event_available_rounded,
                  'صدر في ${CashierLedgerReport.dateFmt.format(report.generatedAt)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.font(fontSize: 11.5, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // الفلاتر
  // ===========================================================
  Widget _buildFilters(
      BuildContext context, DataService ds, bool isDark, Color dividerColor) {
    final halaqaItems = _halaqaScope(ds);
    final effectiveHalaqa =
        halaqaItems.any((h) => h.id == _halaqaFilter) ? _halaqaFilter : 'all';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 18, color: AppColors.terracottaPrimary),
              const SizedBox(width: 8),
              Text('نطاق الكشف',
                  style: AppTypography.titleBold(context, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final mosqueField = MinisterialDropdownField<String>(
                label: 'الجامع',
                value: _mosqueFilter,
                prefixIcon: const Icon(Icons.mosque_outlined, size: 18),
                items: [
                  if (widget.mosqueOptions.length > 1)
                    const DropdownMenuItem(
                        value: _allMosques,
                        child: Text('كل الجوامع المعتمدة')),
                  ...widget.mosqueOptions.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _mosqueFilter = val ?? _allMosques;
                    _halaqaFilter = 'all';
                  });
                  _loadPricing();
                },
              );

              final halaqaField = MinisterialDropdownField<String>(
                label: 'الحلقة',
                value: effectiveHalaqa,
                prefixIcon: const Icon(Icons.groups_2_outlined, size: 18),
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('كل الحلقات')),
                  ...halaqaItems.map(
                    (h) => DropdownMenuItem(value: h.id, child: Text(h.name)),
                  ),
                ],
                onChanged: (val) => setState(() => _halaqaFilter = val ?? 'all'),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    mosqueField,
                    const SizedBox(height: 10),
                    halaqaField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mosqueField),
                  const SizedBox(width: 10),
                  Expanded(child: halaqaField),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text('الفترة',
              style: AppTypography.bodyRegular(context, fontSize: 12)
                  .copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _periodChip('اليوم', 'today'),
              _periodChip('هذا الأسبوع', 'week'),
              _periodChip('هذا الشهر', 'month'),
              _periodChip('الشهر الماضي', 'last_month'),
              _periodChip('كل الفترات', 'all'),
              ActionChip(
                avatar: Icon(Icons.edit_calendar_rounded,
                    size: 15,
                    color: _periodKey == 'custom'
                        ? Colors.white
                        : AppColors.terracottaPrimary),
                label: Text(
                  _periodKey == 'custom' ? _period.label : 'فترة مخصصة',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        _periodKey == 'custom' ? FontWeight.bold : FontWeight.normal,
                    color: _periodKey == 'custom' ? Colors.white : null,
                  ),
                ),
                backgroundColor:
                    _periodKey == 'custom' ? AppColors.terracottaPrimary : null,
                onPressed: _pickCustomRange,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _includePending,
            activeThumbColor: AppColors.terracottaPrimary,
            title: Text('تضمين القسائم المعلّقة (غير المسلّمة)',
                style: AppTypography.bodyRegular(context, fontSize: 12.5)),
            subtitle: Text(
              'المستحقات المالية تُحسب على المسلّم فعلياً فقط',
              style: AppTypography.verveSubtitle(context).copyWith(fontSize: 10.5),
            ),
            onChanged: (val) => setState(() => _includePending = val),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _showDetails,
            activeThumbColor: AppColors.terracottaPrimary,
            title: Text('إظهار تفصيل كل عملية في الكشف المُصدَّر',
                style: AppTypography.bodyRegular(context, fontSize: 12.5)),
            onChanged: (val) => setState(() => _showDetails = val),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, String key) {
    final selected = _periodKey == key;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      selectedColor: AppColors.terracottaPrimary,
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => _setPeriod(key),
    );
  }

  // ===========================================================
  // الملخص
  // ===========================================================
  Widget _buildSummary(
      BuildContext context, CashierLedgerReport report, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.goldSoftBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldSoftBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.goldDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('خلاصة المحاسبة (${report.period.label})',
                    style: AppTypography.titleBold(context, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = <Widget>[
                _statTile(
                  context,
                  value: CashierLedgerReport.fmtInt(report.dispensedCount),
                  label: 'جائزة مسلّمة',
                  color: AppColors.emeraldSuccess,
                ),
                _statTile(
                  context,
                  value: CashierLedgerReport.fmtInt(report.dispensedPoints),
                  label: 'نقطة انسحبت',
                  color: AppColors.goldDark,
                ),
                _statTile(
                  context,
                  value: CashierLedgerReport.fmtInt(report.beneficiaries),
                  label: 'طالب مستفيد',
                  color: AppColors.terracottaPrimary,
                ),
                if (report.hasPricing)
                  _statTile(
                    context,
                    value: CashierLedgerReport.fmtMoney(report.dispensedMoney),
                    label: 'المستحق للصراف (${report.currency})',
                    color: AppColors.emeraldPrimary,
                  ),
                if (report.pendingCount > 0)
                  _statTile(
                    context,
                    value: CashierLedgerReport.fmtInt(report.pendingCount),
                    label:
                        'قيد الانتظار (${CashierLedgerReport.fmtInt(report.pendingPoints)} نقطة)',
                    color: Colors.orange.shade700,
                  ),
              ];
              final columns = constraints.maxWidth < 420 ? 2 : 3;
              return Wrap(
                spacing: 8,
                runSpacing: 12,
                children: tiles
                    .map((t) => SizedBox(
                          width: (constraints.maxWidth - (columns - 1) * 8) /
                              columns,
                          child: t,
                        ))
                    .toList(),
              );
            },
          ),
          if (!report.hasPricing && report.dispensedCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'أدخل تسعيرة الجوائز بالأسفل ليحسب الكشف المبلغ المستحق لك بالمال.',
              style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context,
      {required String value, required String label, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style:
                  AppTypography.titleBold(context, fontSize: 22, color: color)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodyRegular(context, fontSize: 10.5),
        ),
      ],
    );
  }

  // ===========================================================
  // تسعيرة الجوائز (لتحويل النقاط إلى مال)
  // ===========================================================
  Widget _buildPricingSection(BuildContext context, CashierLedgerReport report,
      bool isDark, Color dividerColor) {
    if (_loadingPrices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (report.byReward.isEmpty) return const SizedBox.shrink();

    final pricedCount = report.byReward.where((g) => g.hasPrice).length;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dividerColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: pricedCount == 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(Icons.price_change_rounded,
              color: AppColors.terracottaPrimary, size: 20),
          title: Text('تسعيرة الجوائز بالمال',
              style: AppTypography.titleBold(context, fontSize: 14)),
          subtitle: Text(
            pricedCount == 0
                ? 'لم تُسعَّر أي جائزة بعد — أدخل ثمن القطعة ليُحسب المبلغ'
                : 'مُسعَّرة $pricedCount من ${report.byReward.length} جائزة',
            style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الأسعار تُحفظ على جهازك لكل جامع، ولا تُرسل مع بيانات الطلاب.',
                    style: AppTypography.verveSubtitle(context)
                        .copyWith(fontSize: 10.5),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    initialValue: _currency,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyRegular(context, fontSize: 12.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'العملة',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onChanged: (val) {
                      _currency =
                          val.trim().isEmpty ? RewardPriceStore.defaultCurrency : val.trim();
                      RewardPriceStore.saveCurrency(_currency);
                    },
                    onFieldSubmitted: (_) => setState(() {}),
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...report.byReward.map((g) => _priceRow(context, g, report)),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(
      BuildContext context, LedgerGroup group, CashierLedgerReport report) {
    final current = _prices[group.key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyRegular(context, fontSize: 13)),
                Text(
                  '${CashierLedgerReport.fmtInt(group.count)} قطعة'
                  '${group.hasPrice ? ' = ${report.moneyText(group.money)}' : ''}',
                  style: AppTypography.verveSubtitle(context)
                      .copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('price_${group.key}'),
              initialValue: current != null
                  ? CashierLedgerReport.fmtMoney(current)
                  : '',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.bodyRegular(context, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'ثمن القطعة',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onChanged: (val) {
                final parsed = double.tryParse(val.trim().replaceAll(',', ''));
                if (parsed == null || parsed <= 0) {
                  _prices.remove(group.key);
                } else {
                  _prices[group.key] = parsed;
                }
              },
              onFieldSubmitted: (_) => _persistPrices(),
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
                _persistPrices();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _persistPrices() {
    // عند عرض كل الجوامع نوزّع كل سعر على الجامع الذي تتبع له جائزته
    final ds = context.read<DataService>();
    final rewardMosque = <String, String>{};
    for (final r in ds.getRewards()) {
      rewardMosque[r.id] = r.mosqueId;
      // السجلات القديمة قد تُسعَّر بعنوان الجائزة بدل معرّفها
      rewardMosque.putIfAbsent(r.title, () => r.mosqueId);
    }
    final targets = _mosqueFilter == _allMosques
        ? widget.mosqueOptions.keys.toList()
        : [_mosqueFilter];

    for (final mosqueId in targets) {
      final forMosque = <String, double>{
        for (final e in _prices.entries)
          if (targets.length == 1 || rewardMosque[e.key] == mosqueId)
            e.key: e.value,
      };
      RewardPriceStore.savePrices(mosqueId, forMosque);
    }
    setState(() {});
  }

  // ===========================================================
  // بطاقات التفصيل
  // ===========================================================
  Widget _buildBreakdown({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<LedgerGroup> groups,
    required CashierLedgerReport report,
    required String unitLabel,
    bool showMoney = false,
    bool collapsible = false,
  }) {
    if (groups.isEmpty) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...groups.map(
          (g) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Icon(icon,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.label,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.bodyRegular(context, fontSize: 12.5)),
                      if (g.subtitle != null && g.subtitle!.isNotEmpty)
                        Text(g.subtitle!,
                            style: AppTypography.verveSubtitle(context)
                                .copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                Text(
                  '${CashierLedgerReport.fmtInt(g.count)} $unitLabel',
                  style: AppTypography.bodyRegular(context, fontSize: 11.5),
                ),
                const SizedBox(width: 10),
                Text(
                  '${CashierLedgerReport.fmtInt(g.points)} نقطة',
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: AppColors.goldDark,
                  ),
                ),
                if (showMoney && g.hasPrice) ...[
                  const SizedBox(width: 10),
                  Text(
                    report.moneyText(g.money),
                    style: AppTypography.font(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: AppColors.emeraldSuccess,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showMoney && report.hasPricing) ...[
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('الإجمالي المستحق بالمال',
                    style: AppTypography.titleBold(context, fontSize: 13)),
              ),
              Text(
                report.moneyText(report.dispensedMoney),
                style: AppTypography.titleBold(context,
                    fontSize: 15, color: AppColors.emeraldSuccess),
              ),
            ],
          ),
          if (report.unpricedRewards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'لم تُسعَّر بعد: ${report.unpricedRewards.map((g) => g.label).join('، ')}',
                style: AppTypography.verveSubtitle(context)
                    .copyWith(fontSize: 10.5, color: Colors.orange.shade700),
              ),
            ),
        ],
      ],
    );

    return _sectionCard(
      context: context,
      isDark: isDark,
      title: title,
      subtitle: subtitle,
      icon: icon,
      collapsible: collapsible,
      child: content,
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    bool collapsible = false,
  }) {
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final decoration = BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: dividerColor),
    );

    if (collapsible) {
      return Container(
        decoration: decoration,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading:
                Icon(icon, size: 20, color: AppColors.terracottaPrimary),
            title: Text(title,
                style: AppTypography.titleBold(context, fontSize: 14)),
            subtitle: Text(subtitle,
                style:
                    AppTypography.verveSubtitle(context).copyWith(fontSize: 11)),
            children: [child],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.terracottaPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.titleBold(context, fontSize: 14)),
                    Text(subtitle,
                        style: AppTypography.verveSubtitle(context)
                            .copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ===========================================================
  // تفصيل العمليات
  // ===========================================================
  Widget _buildDetailedList(BuildContext context, CashierLedgerReport report,
      bool isDark, Color dividerColor) {
    if (report.entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('لا توجد عمليات ضمن هذا النطاق',
                style: AppTypography.bodyRegular(context,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('جرّب توسيع الفترة أو اختيار جامع آخر',
                style: AppTypography.verveSubtitle(context)
                    .copyWith(fontSize: 11)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_rounded,
                size: 20, color: AppColors.emeraldPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تفصيل العمليات (${CashierLedgerReport.fmtInt(report.entries.length)})',
                style: AppTypography.verveHeaderTitle(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: report.entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _entryRow(
            context,
            report,
            report.entries[index],
            index + 1,
            isDark,
            dividerColor,
          ),
        ),
      ],
    );
  }

  Widget _entryRow(BuildContext context, CashierLedgerReport report,
      LedgerEntry entry, int number, bool isDark, Color dividerColor) {
    final r = entry.redemption;
    final statusColor =
        entry.isDispensed ? AppColors.emeraldSuccess : Colors.orange.shade700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text('$number',
                    style: AppTypography.font(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName,
                        style: AppTypography.titleBold(context, fontSize: 13.5)),
                    Text(
                      '${entry.studentCode} • ${entry.halaqaName}',
                      style: AppTypography.verveSubtitle(context)
                          .copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.isDispensed ? 'تم التسليم' : 'قيد الانتظار',
                  style:
                      AppTypography.badgeText(color: statusColor, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 14, color: isDark ? Colors.white54 : Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(r.rewardTitle,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyRegular(context, fontSize: 12)),
              ),
              Text('${CashierLedgerReport.fmtInt(r.pointsSpent)} نقطة',
                  style: AppTypography.font(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.goldDark)),
              if (entry.isDispensed && entry.unitPrice != null) ...[
                const SizedBox(width: 8),
                Text(report.moneyText(entry.unitPrice!),
                    style: AppTypography.font(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.emeraldSuccess)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${CashierLedgerReport.dateTimeFmt.format(entry.date)}  •  '
            '${r.mosqueName}  •  القسيمة: ${r.redemptionCode}'
            '${r.cashierName != null ? '  •  الصراف: ${r.cashierName}' : ''}',
            style: AppTypography.bodyRegular(context, fontSize: 10.5).copyWith(
                color: isDark ? Colors.white38 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // شريط الإجراءات السفلي
  // ===========================================================
  Widget _buildActionBar(
      BuildContext context, CashierLedgerReport report, bool isDark) {
    final enabled = report.entries.isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text('مشاركة الكشف',
                    style: AppTypography.buttonText(color: Colors.white)),
                onPressed: enabled ? () => _shareStatement(report) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emeraldPrimary,
                  side: BorderSide(
                      color:
                          AppColors.emeraldPrimary.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.table_view_rounded, size: 18),
                label: Text('Excel',
                    style:
                        AppTypography.buttonText(color: AppColors.emeraldPrimary)),
                onPressed: enabled ? () => _exportCsv(report) : null,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'نسخ الكشف',
              icon: const Icon(Icons.copy_rounded),
              onPressed: enabled ? () => _copyStatement(report) : null,
            ),
          ],
        ),
      ),
    );
  }
}
