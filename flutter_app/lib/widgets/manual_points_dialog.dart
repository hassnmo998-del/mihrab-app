import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../presentation/widgets/widgets.dart';
import '../services/data_service.dart';

/// الحد الأقصى المسموح للحركة اليدوية الواحدة (إضافة أو خصم).
const int kManualPointsMaxPerAction = 10000;

/// نافذة الوضع اليدوي لنقاط الطالب: زر ناقص للخصم وزر زائد للإضافة،
/// مع مقدار قابل للتحرير وأسباب سريعة، ومعاينة فورية للرصيد الناتج.
///
/// تُستخدم في صفحة الطلاب بالإدارة وفي إدارة الحلقة (بوابة الشيخ)،
/// وتكتب التعديل محلياً وتدرجه في طابور المزامنة مع الباك اند عبر [DataService].
class ManualPointsDialog extends StatefulWidget {
  /// الطالب المستهدف بالتعديل.
  final Student student;

  /// اسم الجهة المنفذة (مدير المسجد أو الشيخ) لتوثيقه في سجل النقاط.
  final String? actorName;

  const ManualPointsDialog({
    super.key,
    required this.student,
    this.actorName,
  });

  @override
  State<ManualPointsDialog> createState() => _ManualPointsDialogState();
}

class _ManualPointsDialogState extends State<ManualPointsDialog> {
  static const List<int> _presets = [1, 5, 10, 25, 50, 100];

  final TextEditingController _amountCtrl = TextEditingController(text: '5');
  final TextEditingController _reasonCtrl = TextEditingController();

  /// رسالة نتيجة آخر حركة، تُعرض داخل النافذة لأن الإشعارات السفلية تظهر خلف الحجاب.
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _amount {
    final parsed = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (parsed < 0) return 0;
    return parsed > kManualPointsMaxPerAction ? kManualPointsMaxPerAction : parsed;
  }

  /// الرصيد الحالي مقروءاً من المصدر الحيّ لضمان تحديثه بعد كل حركة.
  int _currentPoints(DataService data) {
    final live = data.getStudents(mosqueId: widget.student.mosqueId)
        .where((s) => s.id == widget.student.id);
    return live.isEmpty ? widget.student.totalPoints : live.first.totalPoints;
  }

  void _setAmount(int value) {
    final clamped = value < 0
        ? 0
        : (value > kManualPointsMaxPerAction ? kManualPointsMaxPerAction : value);
    _amountCtrl.text = clamped.toString();
    _amountCtrl.selection =
        TextSelection.collapsed(offset: _amountCtrl.text.length);
    setState(() => _statusMessage = null);
  }

  void _apply(DataService data, int sign) {
    final amount = _amount;
    if (amount <= 0) {
      _setStatus('يرجى إدخال عدد نقاط أكبر من صفر', isError: true);
      return;
    }

    final result = data.adjustStudentPoints(
      studentId: widget.student.id,
      delta: sign * amount,
      reason: _reasonCtrl.text,
      actorName: widget.actorName,
    );

    final success = result['success'] == true;
    final message = result['message']?.toString() ??
        (success ? 'تم تحديث رصيد النقاط' : 'تعذر تنفيذ التعديل');

    if (!success) {
      _setStatus(message, isError: true);
      return;
    }

    _reasonCtrl.clear();
    _setStatus(
      result['clamped'] == true
          ? '$message (تم تحديد الخصم بحدود الرصيد المتاح)'
          : message,
    );
  }

  void _setStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _currentPoints(data);
    final amount = _amount;

    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceSoft = isDark ? Colors.white10 : const Color(0xFFF1F5F9);

    final afterAdd = current + amount;
    final afterDeduct = (current - amount) < 0 ? 0 : current - amount;

    return UnifiedDialog(
      icon: Icons.exposure,
      iconColor: AppColors.gold,
      title: 'الوضع اليدوي للنقاط',
      showCloseButton: true,
      maxWidth: 440,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // بطاقة الطالب والرصيد الحالي
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: surfaceSoft,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: AppTypography.verveTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'كود: ${widget.student.code}',
                        style: AppTypography.verveSubtitle(context),
                      ),
                    ],
                  ),
                ),
                UnifiedBadge(
                  label: 'الرصيد: $current',
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  textColor: AppColors.goldDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          Text('عدد النقاط', style: AppTypography.titleBold(context, fontSize: 13)),
          const SizedBox(height: AppSpacing.s8),

          // حقل المقدار مع مضاعفات سريعة
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  key: const ValueKey('manualPointsAmountField'),
                  controller: _amountCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: AppTypography.titleBold(context, fontSize: 18),
                  decoration: const InputDecoration(
                    contentPadding: AppSpacing.inputDensePadding,
                    hintText: '0',
                  ),
                  onChanged: (_) => setState(() => _statusMessage = null),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.s6,
                  runSpacing: AppSpacing.s6,
                  children: _presets
                      .map(
                        (p) => ChoiceChip(
                          label: Text(
                            '$p',
                            style: AppTypography.badgeText(
                              color: amount == p
                                  ? Colors.white
                                  : AppColors.terracottaPrimary,
                            ),
                          ),
                          selected: amount == p,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          selectedColor: AppColors.terracottaPrimary,
                          backgroundColor: surfaceSoft,
                          side: BorderSide(
                            color:
                                AppColors.terracottaPrimary.withValues(alpha: 0.35),
                          ),
                          onSelected: (_) => _setAmount(p),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s14),

          TextField(
            key: const ValueKey('manualPointsReasonField'),
            controller: _reasonCtrl,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'سبب التعديل (اختياري)',
              hintText: 'مثال: حسن خلق وانتظام، أو خصم لمخالفة نظام الحلقة',
              counterText: '',
              contentPadding: AppSpacing.inputDensePadding,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // معاينة الرصيد الناتج لكل من الخصم والإضافة
          Row(
            children: [
              Expanded(
                child: _PreviewTile(
                  label: 'بعد الخصم',
                  value: afterDeduct,
                  color: AppColors.attendanceAbsent,
                  background: surfaceSoft,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _PreviewTile(
                  label: 'بعد الإضافة',
                  value: afterAdd,
                  color: AppColors.emeraldSuccess,
                  background: surfaceSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          if (_statusMessage != null) ...[
            Container(
              key: const ValueKey('manualPointsStatus'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: (_statusIsError
                        ? AppColors.attendanceAbsent
                        : AppColors.emeraldSuccess)
                    .withValues(alpha: 0.12),
                borderRadius: AppRadius.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIsError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: _statusIsError
                        ? AppColors.attendanceAbsent
                        : AppColors.emeraldSuccess,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: AppTypography.bodyRegular(
                        context,
                        fontSize: 12,
                        color: _statusIsError
                            ? AppColors.attendanceAbsent
                            : AppColors.emeraldSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s10),
          ],

          Text(
            'كل حركة تُسجَّل في سجل نقاط الطالب وتُزامن مع قاعدة البيانات تلقائياً.',
            style: AppTypography.bodyRegular(context, fontSize: 11.5, color: textSecondary),
          ),
        ],
      ),
      actions: [
        _ActionButton(
          key: const ValueKey('manualPointsDeductButton'),
          label: 'خصم',
          icon: Icons.remove,
          color: AppColors.attendanceAbsent,
          onPressed: amount <= 0 ? null : () => _apply(data, -1),
        ),
        _ActionButton(
          key: const ValueKey('manualPointsAddButton'),
          label: 'إضافة',
          icon: Icons.add,
          color: AppColors.emeraldSuccess,
          onPressed: amount <= 0 ? null : () => _apply(data, 1),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: textSecondary,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            padding: AppSpacing.buttonDensePadding,
          ),
          child: Text('إغلاق', style: AppTypography.buttonText(color: textSecondary)),
        ),
      ],
    );
  }
}

/// زر تنفيذ الحركة (ناقص / زائد) بهيئة موحدة.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: AppTypography.buttonText()),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s10,
        ),
      ),
    );
  }
}

/// بطاقة معاينة الرصيد الناتج.
class _PreviewTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color background;

  const _PreviewTile({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.sm,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.badgeText(color: color, fontSize: 11)),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '$value نقطة',
            style: AppTypography.titleBold(context, fontSize: 15, color: color),
          ),
        ],
      ),
    );
  }
}

/// عرض نافذة الوضع اليدوي للنقاط لطالب محدد.
Future<void> showManualPointsDialog({
  required BuildContext context,
  required Student student,
  String? actorName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ManualPointsDialog(
      student: student,
      actorName: actorName,
    ),
  );
}
