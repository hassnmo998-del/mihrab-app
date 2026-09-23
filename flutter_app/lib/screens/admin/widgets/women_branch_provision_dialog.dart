import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/data_service.dart';
import '../../../widgets/qr_dialogs.dart';

/// Men's-administration side of the women's-branch handover.
///
/// This dialog is the only place a women's administration can be brought into
/// existence: it mints a single-use `WMV-` token, the women's administration
/// scans it on its own device, and a **separate** mosque record with its own
/// access code is created there. The men's administration never receives access
/// to the branch it provisioned — not even its access code.
class WomenBranchProvisionDialog extends StatefulWidget {
  final String mosqueId;

  const WomenBranchProvisionDialog({super.key, required this.mosqueId});

  @override
  State<WomenBranchProvisionDialog> createState() =>
      _WomenBranchProvisionDialogState();
}

class _WomenBranchProvisionDialogState
    extends State<WomenBranchProvisionDialog> {
  bool _isWorking = false;

  Future<void> _issueToken(DataService data, {required bool isReissue}) async {
    if (isReissue) {
      final confirmed = await _confirmReissue();
      if (confirmed != true) return;
    }

    setState(() => _isWorking = true);
    final token = data.issueWomenProvisionToken(widget.mosqueId);
    if (!mounted) return;
    setState(() => _isWorking = false);

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر إصدار الرمز — تأكد من أنك في إدارة مسجد رجالي معتمد',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _showTokenQr(token);
  }

  Future<bool?> _confirmReissue() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(child: Text('إعادة إصدار رمز التسليم')),
          ],
        ),
        content: const Text(
          'القسم النسائي منشأ مسبقاً وله إدارته وكوده الخاص. إعادة الإصدار تُستخدم '
          'فقط إذا فقدت المديرة كودها، ومن يمسح الرمز الجديد ستصبح له إدارة القسم '
          'النسائي بالكامل. سلّمي الرمز للمديرة المعتمدة وحدها.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إصدار رمز تسليم جديد'),
          ),
        ],
      ),
    );
  }

  void _showTokenQr(String token) {
    showDialog(
      context: context,
      builder: (_) => SectionQrCodeDialog(
        title: 'رمز إنشاء إدارة القسم النسائي',
        subtitle:
            'تمسح المديرة هذا الرمز من جهازها لتُنشئ إدارة القسم النسائي المستقلة '
            'بكودها الخاص. الرمز يُستهلك بعد أول استخدام.',
        code: token,
        icon: Icons.female,
        primaryColor: AppColors.terracottaPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final mosque = data.getMosqueById(widget.mosqueId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (mosque == null) {
      return const AlertDialog(content: Text('لم يُعثر على بيانات المسجد'));
    }

    final branch = mosque.womenBranchId != null
        ? data.getMosqueById(mosque.womenBranchId!)
        : null;
    final pendingToken = mosque.womenProvisionToken;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.female,
              color: AppColors.terracottaPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'القسم النسائي',
              style: AppTypography.titleBold(context, fontSize: 16),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoBox(
                isDark: isDark,
                icon: Icons.lock_outline_rounded,
                color: AppColors.emeraldPrimary,
                text:
                    'القسم النسائي إدارة مستقلة تماماً: سجلات وطالبات وحلقات '
                    'وجوائز وفعاليات خاصة به، لا تظهر في إدارة الرجال ولا تظهر '
                    'بيانات الرجال فيها.',
              ),
              const SizedBox(height: 12),
              if (branch != null)
                _StatusBox(
                  isDark: isDark,
                  title: 'تم إنشاء إدارة القسم النسائي ✅',
                  body:
                      'الفرع: ${branch.name}\n'
                      'كود إدارته محفوظ على جهاز المديرة فقط، ولا تملك إدارة '
                      'الرجال أي وصول إليه أو إلى بياناته.',
                )
              else if (pendingToken != null)
                _StatusBox(
                  isDark: isDark,
                  title: 'رمز تسليم بانتظار المسح ⏳',
                  body:
                      'أصدرتَ رمزاً ولم يُستخدم بعد. تمسحه المديرة من جهازها '
                      'لتُنشئ إدارتها المستقلة.',
                )
              else
                _StatusBox(
                  isDark: isDark,
                  title: 'لا يوجد قسم نسائي بعد',
                  body:
                      'أصدر رمز التسليم ثم اطلب من المديرة مسحه من جهازها. '
                      'لا توجد أي طريقة أخرى لإنشاء إدارة نسائية.',
                ),
              const SizedBox(height: 16),
              if (branch == null && pendingToken != null) ...[
                ElevatedButton.icon(
                  onPressed: _isWorking
                      ? null
                      : () => _showTokenQr(pendingToken),
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('عرض رمز التسليم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracottaPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isWorking
                      ? null
                      : () => _issueToken(data, isReissue: false),
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  label: const Text('توليد رمز جديد (يُلغي السابق)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ] else if (branch == null) ...[
                ElevatedButton.icon(
                  onPressed: _isWorking
                      ? null
                      : () => _issueToken(data, isReissue: false),
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('إصدار رمز إنشاء القسم النسائي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terracottaPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ] else ...[
                if (pendingToken != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: _isWorking
                          ? null
                          : () => _showTokenQr(pendingToken),
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('عرض رمز التسليم الحالي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracottaPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _isWorking
                      ? null
                      : () => _issueToken(data, isReissue: true),
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'إعادة إصدار رمز التسليم (فقدان الكود)',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBox({
    required this.isDark,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyRegular(
                context,
                fontSize: 12,
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final bool isDark;
  final String title;
  final String body;

  const _StatusBox({
    required this.isDark,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleBold(context, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.verveSubtitle(
              context,
            ).copyWith(fontSize: 12, height: 1.55),
          ),
        ],
      ),
    );
  }
}
