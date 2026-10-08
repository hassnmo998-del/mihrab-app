import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../presentation/widgets/widgets.dart';
import '../services/data_service.dart';

/// الحد الأقصى المسموح للحركة اليدوية الواحدة (إضافة أو خصم).
const int kManualPointsMaxPerAction = 10000;

/// نافذة الوضع اليدوي لنقاط الطالب: خانة للرقم، وزر «خصم» وزر «إضافة». لا شيء غيرها.
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
  final TextEditingController _amountCtrl = TextEditingController();

  /// رسالة نتيجة آخر حركة، تُعرض داخل النافذة لأن الإشعارات السفلية تظهر خلف الحجاب.
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
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

  void _apply(DataService data, int sign) {
    final amount = _amount;
    if (amount <= 0) {
      _setStatus('اكتب عدد النقاط أولاً', isError: true);
      return;
    }

    final result = data.adjustStudentPoints(
      studentId: widget.student.id,
      delta: sign * amount,
      actorName: widget.actorName,
    );

    final success = result['success'] == true;
    final message = result['message']?.toString() ??
        (success ? 'تم تحديث رصيد النقاط' : 'تعذر تنفيذ التعديل');

    if (!success) {
      _setStatus(message, isError: true);
      return;
    }

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
    final surfaceSoft = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
    final statusColor = _statusIsError ? AppColors.attendanceAbsent : AppColors.emeraldSuccess;

    return UnifiedDialog(
      icon: Icons.exposure,
      iconColor: AppColors.gold,
      title: 'الوضع اليدوي للنقاط',
      showCloseButton: true,
      maxWidth: 380,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // الطالب ورصيده الحالي
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
                  child: Text(
                    widget.student.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.verveTitle(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                UnifiedBadge(
                  label: 'الرصيد: $current',
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  textColor: AppColors.goldDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          TextField(
            key: const ValueKey('manualPointsAmountField'),
            controller: _amountCtrl,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            style: AppTypography.titleBold(context, fontSize: 22),
            decoration: const InputDecoration(
              labelText: 'عدد النقاط',
              floatingLabelAlignment: FloatingLabelAlignment.center,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onChanged: (_) {
              if (_statusMessage != null) setState(() => _statusMessage = null);
            },
          ),
          const SizedBox(height: AppSpacing.s14),

          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  key: const ValueKey('manualPointsDeductButton'),
                  label: 'خصم',
                  icon: Icons.remove,
                  color: AppColors.attendanceAbsent,
                  onPressed: () => _apply(data, -1),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: _ActionButton(
                  key: const ValueKey('manualPointsAddButton'),
                  label: 'إضافة',
                  icon: Icons.add,
                  color: AppColors.emeraldSuccess,
                  onPressed: () => _apply(data, 1),
                ),
              ),
            ],
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              _statusMessage!,
              key: const ValueKey('manualPointsStatus'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyRegular(context, fontSize: 12.5, color: statusColor),
            ),
          ],
        ],
      ),
      actions: const [],
    );
  }
}

/// زر تنفيذ الحركة (خصم / إضافة) بهيئة موحدة.
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
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
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
