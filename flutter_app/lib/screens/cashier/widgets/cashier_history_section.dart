import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';

/// سجل صرف الجوائز والمستحقات.
///
/// يعرض لكل عملية: الجامع الذي صُرف له، الطالب وحلقته، الجائزة، قيمتها بالنقاط،
/// تاريخ الصرف والصراف المنفّذ؛ مع فلاتر حسب الجامع أو الحلقة أو الحالة أو الفترة،
/// وفرز مرن، وملخص للمستحقات يسهّل التنسيق بين الصراف وإدارة المسجد.
class CashierHistorySection extends StatefulWidget {
  final List<RewardRedemption> allRedemptions;
  final List<Reward> allRewards;
  final List<Student> students;
  final List<Halaqa> halaqat;

  /// الجوامع المعتمد الصراف للصرف فيها: المعرّف -> الاسم.
  final Map<String, String> mosqueOptions;

  /// الجامع النشط حالياً في شريط التبديل بالأعلى.
  final String activeMosqueId;

  const CashierHistorySection({
    super.key,
    required this.allRedemptions,
    required this.allRewards,
    required this.students,
    required this.halaqat,
    required this.mosqueOptions,
    required this.activeMosqueId,
  });

  @override
  State<CashierHistorySection> createState() => _CashierHistorySectionState();
}

class _CashierHistorySectionState extends State<CashierHistorySection> {
  static final DateFormat _dateFmt = DateFormat('yyyy/MM/dd');
  static final DateFormat _dateTimeFmt = DateFormat('yyyy/MM/dd • hh:mm a');

  late String _mosqueFilter;
  String _halaqaFilter = 'all';
  String _statusFilter = 'all';
  String _periodFilter = 'all';
  String _sortMode = 'newest';
  String _search = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mosqueFilter = widget.activeMosqueId;
  }

  @override
  void didUpdateWidget(covariant CashierHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // عند تبديل الجامع من الشريط العلوي نتابع الاختيار الجديد تلقائياً
    if (oldWidget.activeMosqueId != widget.activeMosqueId &&
        _mosqueFilter == oldWidget.activeMosqueId) {
      _mosqueFilter = widget.activeMosqueId;
      _halaqaFilter = 'all';
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===========================================================
  // Helpers
  // ===========================================================
  Map<String, Student> get _studentById =>
      {for (final s in widget.students) s.id: s};

  Map<String, Halaqa> get _halaqaById =>
      {for (final h in widget.halaqat) h.id: h};

  String? _halaqaIdOf(RewardRedemption r, Map<String, Student> students) =>
      students[r.studentId]?.halaqaId;

  String _halaqaNameOf(RewardRedemption r, Map<String, Student> students,
      Map<String, Halaqa> halaqat) {
    final hId = _halaqaIdOf(r, students);
    if (hId == null || hId.isEmpty) return 'حلقة غير محددة';
    return halaqat[hId]?.name ?? 'حلقة غير محددة';
  }

  String _studentCodeOf(RewardRedemption r, Map<String, Student> students) =>
      students[r.studentId]?.code ?? '—';

  /// الحلقات ضمن نطاق الجامع المختار حالياً.
  List<Halaqa> get _halaqaScope => widget.halaqat
      .where((h) => _mosqueFilter == 'all' || h.mosqueId == _mosqueFilter)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  /// فلتر الحلقة المعتمد فعلياً (يسقط تلقائياً إن خرجت الحلقة عن نطاق الجامع).
  String get _effectiveHalaqaFilter =>
      _halaqaScope.any((h) => h.id == _halaqaFilter) ? _halaqaFilter : 'all';

  /// التاريخ المعتمد للعملية: تاريخ التسليم إن تم، وإلا تاريخ الطلب.
  DateTime _effectiveDate(RewardRedemption r) => r.dispensedAt ?? r.redeemedAt;

  bool _matchesPeriod(RewardRedemption r) {
    if (_periodFilter == 'all') return true;
    final now = DateTime.now();
    final d = _effectiveDate(r);
    switch (_periodFilter) {
      case 'today':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'week':
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday % 7));
        return d.isAfter(startOfWeek);
      case 'month':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  String get _periodLabel {
    switch (_periodFilter) {
      case 'today':
        return 'اليوم';
      case 'week':
        return 'هذا الأسبوع';
      case 'month':
        return 'هذا الشهر';
      default:
        return 'كل الفترات';
    }
  }

  // ===========================================================
  // Build
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final students = _studentById;
    final halaqat = _halaqaById;

    // 1) استبعاد الطلبات المعلّقة لجوائز أوقفتها الإدارة
    final base = widget.allRedemptions.where((r) {
      if (r.status != 'pending') return true;
      final reward =
          widget.allRewards.where((rew) => rew.id == r.rewardId).firstOrNull;
      return reward?.isActive ?? true;
    }).toList();

    // 2) تطبيق الفلاتر
    final query = _search.trim().toLowerCase();
    final halaqaFilter = _effectiveHalaqaFilter;
    final filtered = base.where((r) {
      if (_mosqueFilter != 'all' && r.mosqueId != _mosqueFilter) return false;
      if (halaqaFilter != 'all' && _halaqaIdOf(r, students) != halaqaFilter) {
        return false;
      }
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      if (!_matchesPeriod(r)) return false;
      if (query.isNotEmpty) {
        final haystack = [
          r.studentName,
          r.rewardTitle,
          r.redemptionCode,
          r.mosqueName,
          _studentCodeOf(r, students),
          _halaqaNameOf(r, students, halaqat),
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();

    // 3) الفرز
    filtered.sort((a, b) {
      switch (_sortMode) {
        case 'oldest':
          return _effectiveDate(a).compareTo(_effectiveDate(b));
        case 'points_desc':
          return b.pointsSpent.compareTo(a.pointsSpent);
        case 'points_asc':
          return a.pointsSpent.compareTo(b.pointsSpent);
        case 'student':
          return a.studentName.compareTo(b.studentName);
        case 'halaqa':
          return _halaqaNameOf(a, students, halaqat)
              .compareTo(_halaqaNameOf(b, students, halaqat));
        default: // newest
          return _effectiveDate(b).compareTo(_effectiveDate(a));
      }
    });

    final dispensed = filtered.where((r) => r.status == 'dispensed').toList();
    final pending = filtered.where((r) => r.status == 'pending').toList();
    final dispensedPoints =
        dispensed.fold<int>(0, (sum, r) => sum + r.pointsSpent);
    final pendingPoints = pending.fold<int>(0, (sum, r) => sum + r.pointsSpent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, filtered, students, halaqat),
        const SizedBox(height: 14),
        _buildFilters(context, isDark, dividerColor),
        const SizedBox(height: 14),
        _buildSettlementSummary(
          context: context,
          isDark: isDark,
          dispensedCount: dispensed.length,
          dispensedPoints: dispensedPoints,
          pendingCount: pending.length,
          pendingPoints: pendingPoints,
          dispensedList: dispensed,
          students: students,
          halaqat: halaqat,
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'لا توجد عمليات مطابقة للفلاتر المختارة',
                  style: AppTypography.bodyRegular(context, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _buildRecordCard(
              context,
              filtered[index],
              students,
              halaqat,
              isDark,
            ),
          ),
      ],
    );
  }

  // ===========================================================
  // Header + export
  // ===========================================================
  Widget _buildHeader(
    BuildContext context,
    List<RewardRedemption> filtered,
    Map<String, Student> students,
    Map<String, Halaqa> halaqat,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.emeraldPrimary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجل الصرف والمستحقات',
                    style: AppTypography.verveHeaderTitle(context)),
                Text(
                  'كشف تفصيلي لمن صُرف له ومن أي جامع وبكم نقطة',
                  style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: filtered.isEmpty
              ? null
              : () => _shareStatement(filtered, students, halaqat),
          icon: const Icon(Icons.ios_share_rounded, size: 16),
          label: Text('مشاركة الكشف',
              style: AppTypography.buttonText(color: AppColors.emeraldPrimary)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.emeraldPrimary,
            side: BorderSide(color: AppColors.emeraldPrimary.withValues(alpha: 0.4)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _shareStatement(
    List<RewardRedemption> filtered,
    Map<String, Student> students,
    Map<String, Halaqa> halaqat,
  ) {
    final mosqueLabel = _mosqueFilter == 'all'
        ? 'كل الجوامع المعتمدة'
        : (widget.mosqueOptions[_mosqueFilter] ?? 'الجامع');
    final halaqaFilter = _effectiveHalaqaFilter;
    final halaqaLabel = halaqaFilter == 'all'
        ? 'كل الحلقات'
        : (halaqat[halaqaFilter]?.name ?? 'حلقة');

    final dispensed = filtered.where((r) => r.status == 'dispensed').toList();
    final totalPoints = dispensed.fold<int>(0, (sum, r) => sum + r.pointsSpent);

    final buffer = StringBuffer()
      ..writeln('كشف صرف الجوائز')
      ..writeln('الجامع: $mosqueLabel')
      ..writeln('الحلقة: $halaqaLabel')
      ..writeln('الفترة: $_periodLabel')
      ..writeln('تاريخ الكشف: ${_dateFmt.format(DateTime.now())}')
      ..writeln('──────────────');

    for (final r in filtered) {
      final halaqaName = _halaqaNameOf(r, students, halaqat);
      final statusLabel = r.status == 'dispensed' ? 'تم التسليم' : 'قيد الانتظار';
      buffer
        ..writeln('• ${r.studentName} (${_studentCodeOf(r, students)}) - $halaqaName')
        ..writeln('  الجامع: ${r.mosqueName}')
        ..writeln('  الجائزة: ${r.rewardTitle} - ${r.pointsSpent} نقطة')
        ..writeln('  الحالة: $statusLabel - ${_dateTimeFmt.format(_effectiveDate(r))}')
        ..writeln('  القسيمة: ${r.redemptionCode}'
            '${r.cashierName != null ? ' - الصراف: ${r.cashierName}' : ''}');
    }

    buffer
      ..writeln('──────────────')
      ..writeln('عدد الجوائز المسلّمة: ${dispensed.length}')
      ..writeln('إجمالي النقاط المستحقة على الجامع: $totalPoints نقطة');

    Share.share(buffer.toString());
  }

  // ===========================================================
  // Filters
  // ===========================================================
  Widget _buildFilters(BuildContext context, bool isDark, Color dividerColor) {
    // الحلقات المعروضة تتبع الجامع المختار
    final halaqaItems = _halaqaScope;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            style: AppTypography.bodyRegular(context, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ابحث باسم الطالب أو كوده أو اسم الجائزة...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (val) => setState(() => _search = val),
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
                  const DropdownMenuItem(value: 'all', child: Text('كل الجوامع المعتمدة')),
                  ...widget.mosqueOptions.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (val) => setState(() {
                  _mosqueFilter = val ?? 'all';
                  _halaqaFilter = 'all';
                }),
              );

              final halaqaField = MinisterialDropdownField<String>(
                label: 'الحلقة',
                value: _effectiveHalaqaFilter,
                prefixIcon: const Icon(Icons.groups_2_outlined, size: 18),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('كل الحلقات')),
                  ...halaqaItems.map(
                    (h) => DropdownMenuItem(value: h.id, child: Text(h.name)),
                  ),
                ],
                onChanged: (val) => setState(() => _halaqaFilter = val ?? 'all'),
              );

              final sortField = MinisterialDropdownField<String>(
                label: 'الفرز',
                value: _sortMode,
                prefixIcon: const Icon(Icons.sort_rounded, size: 18),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('الأحدث أولاً')),
                  DropdownMenuItem(value: 'oldest', child: Text('الأقدم أولاً')),
                  DropdownMenuItem(value: 'points_desc', child: Text('الأعلى نقاطاً')),
                  DropdownMenuItem(value: 'points_asc', child: Text('الأقل نقاطاً')),
                  DropdownMenuItem(value: 'student', child: Text('حسب اسم الطالب')),
                  DropdownMenuItem(value: 'halaqa', child: Text('حسب الحلقة')),
                ],
                onChanged: (val) => setState(() => _sortMode = val ?? 'newest'),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    mosqueField,
                    const SizedBox(height: 10),
                    halaqaField,
                    const SizedBox(height: 10),
                    sortField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mosqueField),
                  const SizedBox(width: 10),
                  Expanded(child: halaqaField),
                  const SizedBox(width: 10),
                  Expanded(child: sortField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('الكل', _statusFilter == 'all',
                  () => setState(() => _statusFilter = 'all')),
              _filterChip('تم التسليم', _statusFilter == 'dispensed',
                  () => setState(() => _statusFilter = 'dispensed')),
              _filterChip('قيد الانتظار', _statusFilter == 'pending',
                  () => setState(() => _statusFilter = 'pending')),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('كل الفترات', _periodFilter == 'all',
                  () => setState(() => _periodFilter = 'all')),
              _filterChip('اليوم', _periodFilter == 'today',
                  () => setState(() => _periodFilter = 'today')),
              _filterChip('هذا الأسبوع', _periodFilter == 'week',
                  () => setState(() => _periodFilter = 'week')),
              _filterChip('هذا الشهر', _periodFilter == 'month',
                  () => setState(() => _periodFilter = 'month')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      selectedColor: AppColors.terracottaPrimary,
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onTap(),
    );
  }

  // ===========================================================
  // Settlement summary (ما يستحق على الجامع للصراف)
  // ===========================================================
  Widget _buildSettlementSummary({
    required BuildContext context,
    required bool isDark,
    required int dispensedCount,
    required int dispensedPoints,
    required int pendingCount,
    required int pendingPoints,
    required List<RewardRedemption> dispensedList,
    required Map<String, Student> students,
    required Map<String, Halaqa> halaqat,
  }) {
    // التجميع: حسب الجامع عند عرض كل الجوامع، وحسب الحلقة عند اختيار جامع واحد
    final groupByMosque = _mosqueFilter == 'all';
    final Map<String, _GroupTotals> groups = {};
    for (final r in dispensedList) {
      final key = groupByMosque
          ? (r.mosqueName.isEmpty ? 'جامع غير محدد' : r.mosqueName)
          : _halaqaNameOf(r, students, halaqat);
      final g = groups.putIfAbsent(key, () => _GroupTotals());
      g.count += 1;
      g.points += r.pointsSpent;
    }
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => b.value.points.compareTo(a.value.points));

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
                child: Text(
                  'ملخص المستحقات ($_periodLabel)',
                  style: AppTypography.titleBold(context, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'هذه القيم هي ما صرفه الصراف فعلياً للطلاب ويستحقه على الجامع.',
            style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  context,
                  value: '$dispensedCount',
                  label: 'جائزة مسلّمة',
                  color: AppColors.emeraldSuccess,
                ),
              ),
              Expanded(
                child: _summaryTile(
                  context,
                  value: '$dispensedPoints',
                  label: 'نقطة مستحقة على الجامع',
                  color: AppColors.goldDark,
                ),
              ),
              Expanded(
                child: _summaryTile(
                  context,
                  value: '$pendingCount',
                  label: 'قيد الانتظار ($pendingPoints نقطة)',
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          if (sortedGroups.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              groupByMosque ? 'التفصيل حسب الجامع:' : 'التفصيل حسب الحلقة:',
              style: AppTypography.titleBold(context, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            ...sortedGroups.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      groupByMosque ? Icons.mosque_outlined : Icons.groups_2_outlined,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.key,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyRegular(context, fontSize: 12.5),
                      ),
                    ),
                    Text(
                      '${e.value.count} جائزة',
                      style: AppTypography.bodyRegular(context, fontSize: 11.5),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${e.value.points} نقطة',
                      style: AppTypography.font(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryTile(BuildContext context,
      {required String value, required String label, required Color color}) {
    return Column(
      children: [
        Text(value,
            style: AppTypography.titleBold(context, fontSize: 22, color: color)),
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
  // Record card
  // ===========================================================
  Widget _buildRecordCard(
    BuildContext context,
    RewardRedemption item,
    Map<String, Student> students,
    Map<String, Halaqa> halaqat,
    bool isDark,
  ) {
    final isDispensed = item.status == 'dispensed';
    final statusColor =
        isDispensed ? AppColors.emeraldSuccess : Colors.orange.shade700;
    final halaqaName = _halaqaNameOf(item, students, halaqat);
    final studentCode = _studentCodeOf(item, students);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDispensed ? Icons.check_rounded : Icons.hourglass_top_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.studentName,
                        style: AppTypography.titleBold(context, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'كود الطالب: $studentCode',
                        style: AppTypography.bodyRegular(context, fontSize: 11.5)
                            .copyWith(
                                color: isDark ? Colors.white60 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDispensed ? 'تم التسليم' : 'قيد الانتظار',
                    style: AppTypography.badgeText(color: statusColor, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _infoTag(
                  context,
                  Icons.mosque_outlined,
                  item.mosqueName.isEmpty ? 'جامع غير محدد' : item.mosqueName,
                  isDark,
                ),
                _infoTag(context, Icons.groups_2_outlined, halaqaName, isDark),
                _infoTag(context, Icons.card_giftcard_rounded, item.rewardTitle, isDark),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.stars_rounded, size: 16, color: AppColors.goldDark),
                const SizedBox(width: 4),
                Text(
                  '${item.pointsSpent} نقطة',
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.goldDark,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.event_rounded,
                    size: 15, color: isDark ? Colors.white54 : Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _dateTimeFmt.format(_effectiveDate(item)),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyRegular(context, fontSize: 11.5)
                        .copyWith(color: isDark ? Colors.white60 : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'القسيمة: ${item.redemptionCode}'
              '${item.cashierName != null ? '  •  الصراف: ${item.cashierName}' : ''}',
              style: AppTypography.bodyRegular(context, fontSize: 11)
                  .copyWith(color: isDark ? Colors.white38 : Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTag(BuildContext context, IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white60 : Colors.grey.shade700),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyRegular(context, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTotals {
  int count = 0;
  int points = 0;
}
