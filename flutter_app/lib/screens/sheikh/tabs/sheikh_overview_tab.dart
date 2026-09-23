import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/profile_image_picker.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class SheikhOverviewTab extends StatefulWidget {
  final Sheikh sheikh;
  final List<Halaqa> halaqat;
  final bool isDark;

  const SheikhOverviewTab({
    super.key,
    required this.sheikh,
    required this.halaqat,
    this.isDark = false,
  });

  @override
  State<SheikhOverviewTab> createState() => _SheikhOverviewTabState();
}

class _SheikhOverviewTabState extends State<SheikhOverviewTab> {
  String _overviewSearch = '';
  String _overviewHalaqaFilter = 'all';
  DateTime _overviewDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final overviewItems = data.getExecutiveOverview(
      sheikhId: widget.sheikh.id,
      halaqaId: _overviewHalaqaFilter == 'all' ? null : _overviewHalaqaFilter,
      searchQuery: _overviewSearch,
      date: _overviewDate,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final dateStr =
        '${_overviewDate.year}/${_overviewDate.month.toString().padLeft(2, '0')}/${_overviewDate.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header & Summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'لوحة المتابعة الشاملة لطلاب الحلقة',
                style: AppTypography.verveHeaderTitle(context),
              ),
              Text(
                'إجمالي الطلاب: ${overviewItems.length}',
                style: AppTypography.titleBold(context, color: AppColors.terracottaPrimary, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Filter Bar (Clean Verve Style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final searchField = TextField(
                decoration: const InputDecoration(
                  hintText: 'بحث باسم الطالب...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (v) => setState(() => _overviewSearch = v.trim()),
              );

              final halaqaFilter = DropdownButtonFormField<String>(
                initialValue: _overviewHalaqaFilter,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('جميع حلقاتي', style: AppTypography.bodyRegular(context)),
                  ),
                  ...widget.halaqat.map((h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, style: AppTypography.bodyRegular(context)),
                  )),
                ],
                onChanged: (v) => setState(() => _overviewHalaqaFilter = v ?? 'all'),
              );

              final dateButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _overviewDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _overviewDate = d);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  dateStr,
                  style: AppTypography.bodyRegular(context, fontSize: 13),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: halaqaFilter),
                        const SizedBox(width: 8),
                        dateButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: halaqaFilter),
                  const SizedBox(width: 10),
                  dateButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Full-Width Comprehensive Table
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<DataService>().syncWithSupabase(),
            child: overviewItems.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Text(
                          'لا توجد بيانات مطابقة للبحث أو التاريخ المحدد',
                          style: AppTypography.verveSubtitle(context),
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: dividerColor,
                      ),
                      child: DataTable(
                        headingRowHeight: 54,
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 68,
                        horizontalMargin: 20,
                        columnSpacing: 28,
                        headingRowColor: WidgetStatePropertyAll(
                          isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              'الطالب',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'الحلقة',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'حضور اليوم',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'آخر تسميع قرآن',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'آخر حديث نبوي',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'المتقن من 30',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'مجموع النقاط',
                              style: AppTypography.titleBold(context, fontSize: 14),
                            ),
                          ),
                        ],
                        rows: overviewItems.map((item) {
                          final student = item['student'] as Student;
                          final halaqa = item['halaqa'] as Halaqa;
                          final att = item['attendance'] as AttendanceRecord;
                          final lastQuran = item['lastQuran'] as MemorizationRecord?;
                          final lastHadith = item['lastHadith'] as PointsLog?;
                          final completedAjza = item['completedAjza'] as int;
                          final totalPoints = item['totalPoints'] as int;

                          String attText = 'لم يرصد';
                          if (att.status == 'present') {
                            attText = 'حاضر';
                          } else if (att.status == 'late') {
                            attText = 'متأخر';
                          } else if (att.status == 'absent') {
                            attText = 'غائب';
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProfileImagePicker(
                                      radius: 16,
                                      isEditable: false,
                                      initialImageUrl: student.profileImageUrl,
                                      fallbackName: student.fullName,
                                      onImageChanged: (_) {},
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      student.fullName,
                                      style: AppTypography.titleBold(context, fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  halaqa.name,
                                  style: AppTypography.bodyRegular(context, fontSize: 13),
                                ),
                              ),
                              DataCell(
                                UnifiedBadge.fromStatus(attText),
                              ),
                              DataCell(
                                Text(
                                  lastQuran != null
                                      ? 'سورة ${lastQuran.surahName} (${lastQuran.fromAyah}-${lastQuran.toAyah})'
                                      : 'لا يوجد',
                                  style: AppTypography.bodyRegular(context, fontSize: 12.5),
                                ),
                              ),
                              DataCell(
                                Text(
                                  lastHadith != null
                                      ? lastHadith.reason.replaceAll('تسميع حديث نبوي شريف: ', '')
                                      : 'لا يوجد',
                                  style: AppTypography.bodyRegular(context, fontSize: 12.5),
                                ),
                              ),
                              DataCell(
                                UnifiedBadge(
                                  label: '$completedAjza / 30 جزء',
                                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                                  textColor: AppColors.goldDark,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '$totalPoints نقطة',
                                  style: AppTypography.titleBold(
                                    context,
                                    color: AppColors.terracottaPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
}