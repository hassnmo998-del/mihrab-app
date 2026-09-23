import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Centralized Reusable DataTable Wrapper Component.
///
/// Ensures all tables across the app adhere to:
/// - Consistent heading row color, typography, and height
/// - Consistent data rows, typography, and divider lines
/// - Consistent container styling with [AppRadius.card] and theme borders
/// - Automatic full-width stretching on wide viewports with responsive scrolling on narrow viewports
/// - Elegant empty state handling
class UnifiedDataTable extends StatelessWidget {
  /// Table column definitions.
  final List<DataColumn>? columns;

  /// Table row definitions.
  final List<DataRow>? rows;

  /// Optional pre-built [DataTable] widget when using wrapper mode.
  final DataTable? customTable;

  /// Minimum width constraint to ensure columns don't compress.
  final double minWidth;

  /// Space between table columns. Defaults to 16.0.
  final double columnSpacing;

  /// Horizontal margin on table edges. Defaults to 16.0.
  final double horizontalMargin;

  /// Height of the table header row. Defaults to 48.0.
  final double headingRowHeight;

  /// Minimum height of data rows. Defaults to 48.0.
  final double dataRowMinHeight;

  /// Maximum height of data rows. Defaults to 56.0.
  final double dataRowMaxHeight;

  /// Custom background color for header row.
  final Color? headingRowColor;

  /// Border radius for the table card container. Defaults to [AppRadius.card].
  final BorderRadius? borderRadius;

  /// Custom border color. Automatically defaults to theme border.
  final Color? borderColor;

  /// Whether to wrap the table in an outer rounded border card container. Defaults to true.
  final bool showContainer;

  /// Whether to enable alternating row background colors (zebra striping). Defaults to false.
  final bool showZebraStripes;

  /// Index of column being sorted.
  final int? sortColumnIndex;

  /// Sort ascending order.
  final bool sortAscending;

  /// Message displayed when [rows] is empty.
  final String emptyMessage;

  /// Custom empty widget when [rows] is empty.
  final Widget? emptyWidget;

  /// Checkbox selection callback support.
  final ValueSetter<bool?>? onSelectAll;

  const UnifiedDataTable({
    super.key,
    required List<DataColumn> this.columns,
    required List<DataRow> this.rows,
    this.minWidth = 720.0,
    this.columnSpacing = 16.0,
    this.horizontalMargin = 16.0,
    this.headingRowHeight = 48.0,
    this.dataRowMinHeight = 48.0,
    this.dataRowMaxHeight = 56.0,
    this.headingRowColor,
    this.borderRadius,
    this.borderColor,
    this.showContainer = true,
    this.showZebraStripes = false,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.emptyMessage = 'لا توجد بيانات متاحة لعرضها في الجدول',
    this.emptyWidget,
    this.onSelectAll,
  }) : customTable = null;

  /// Factory constructor to wrap an existing [DataTable] with unified styling and responsive scroll.
  const UnifiedDataTable.wrap({
    super.key,
    required DataTable this.customTable,
    this.minWidth = 720.0,
    this.borderRadius,
    this.borderColor,
    this.showContainer = true,
  })  : columns = null,
        rows = null,
        columnSpacing = 16.0,
        horizontalMargin = 16.0,
        headingRowHeight = 48.0,
        dataRowMinHeight = 48.0,
        dataRowMaxHeight = 56.0,
        headingRowColor = null,
        showZebraStripes = false,
        sortColumnIndex = null,
        sortAscending = true,
        emptyMessage = '',
        emptyWidget = null,
        onSelectAll = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBorderColor = borderColor ??
        (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final effectiveRadius = borderRadius ?? AppRadius.card;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final defaultHeadingBg = isDark
        ? const Color(0xFF231822)
        : const Color(0xFFF7F2EB);

    final effectiveHeadingBg = headingRowColor ?? defaultHeadingBg;

    // Check if we should render empty state
    if (customTable == null && rows != null && rows!.isEmpty) {
      return _buildEmptyState(context, textSecondary, effectiveBorderColor, effectiveRadius, surfaceColor);
    }

    Widget tableWidget;

    if (customTable != null) {
      tableWidget = customTable!;
    } else {
      // Build zebra rows if requested
      final styledRows = showZebraStripes
          ? _buildZebraRows(rows!, isDark)
          : rows!;

      tableWidget = DataTable(
        headingRowColor: WidgetStatePropertyAll(effectiveHeadingBg),
        headingTextStyle: GoogleFonts.amiri(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        dataTextStyle: GoogleFonts.amiri(
          fontSize: 13.5,
          color: textPrimary,
        ),
        columnSpacing: columnSpacing,
        horizontalMargin: horizontalMargin,
        headingRowHeight: headingRowHeight,
        dataRowMinHeight: dataRowMinHeight,
        dataRowMaxHeight: dataRowMaxHeight,
        dividerThickness: 1.0,
        border: TableBorder(
          horizontalInside: BorderSide(color: effectiveBorderColor, width: 0.8),
        ),
        sortColumnIndex: sortColumnIndex,
        sortAscending: sortAscending,
        onSelectAll: onSelectAll,
        columns: columns!,
        rows: styledRows,
      );
    }

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: effectiveWidth),
            child: tableWidget,
          ),
        );
      },
    );

    if (showContainer) {
      content = Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: effectiveRadius,
          border: Border.all(color: effectiveBorderColor, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return content;
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color textSecondary,
    Color effectiveBorderColor,
    BorderRadius effectiveRadius,
    Color surfaceColor,
  ) {
    Widget emptyContent = emptyWidget ??
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_rows_outlined,
                size: 40,
                color: textSecondary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppSpacing.s10),
              Text(
                emptyMessage,
                style: AppTypography.bodyRegular(context, fontSize: 13, color: textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

    if (showContainer) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: effectiveRadius,
          border: Border.all(color: effectiveBorderColor, width: 1.0),
        ),
        child: emptyContent,
      );
    }

    return emptyContent;
  }

  List<DataRow> _buildZebraRows(List<DataRow> originalRows, bool isDark) {
    final stripeColor = isDark
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.black.withValues(alpha: 0.02);

    return List.generate(originalRows.length, (index) {
      final row = originalRows[index];
      if (index % 2 == 1 && row.color == null) {
        return DataRow(
          key: row.key,
          selected: row.selected,
          onSelectChanged: row.onSelectChanged,
          onLongPress: row.onLongPress,
          color: WidgetStatePropertyAll(stripeColor),
          cells: row.cells,
        );
      }
      return row;
    });
  }
}
