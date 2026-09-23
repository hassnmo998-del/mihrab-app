import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../widgets/printable_badge_dialog.dart';

/// Women's-administration side of the handover.
///
/// Reached only by scanning a `WMV-` token issued from an existing men's
/// administration. Redeeming it creates a brand-new mosque record for the
/// women's branch with its own access code — that separate id is what keeps
/// every students/halaqat/rewards/events query apart from the men's branch.
class WomenBranchSetupDialog extends StatefulWidget {
  final WomenBranchProvisionOffer offer;
  final VoidCallback? onProvisioned;

  const WomenBranchSetupDialog({
    super.key,
    required this.offer,
    this.onProvisioned,
  });

  @override
  State<WomenBranchSetupDialog> createState() => _WomenBranchSetupDialogState();
}

class _WomenBranchSetupDialogState extends State<WomenBranchSetupDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _addressCtrl;
  final _phoneCtrl = TextEditingController();

  Position? _capturedPosition;
  bool _isLocating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final parent = widget.offer.parentMosque;
    _nameCtrl = TextEditingController(text: widget.offer.suggestedBranchName);
    _cityCtrl = TextEditingController(text: parent.city);
    _addressCtrl = TextEditingController(text: parent.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        setState(() => _capturedPosition = pos);
      }
    } catch (_) {
      // الموقع اختياري: يورَّث موقع المسجد الأم إذا تعذّر التحديد
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    final data = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!widget.offer.isHandover && _nameCtrl.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم القسم النسائي')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final branch = await data.redeemWomenProvisionToken(
      offer: widget.offer,
      name: _nameCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      latitude: _capturedPosition?.latitude,
      longitude: _capturedPosition?.longitude,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (branch == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'انتهت صلاحية رمز التسليم أو استُخدم مسبقاً — اطلبي رمزاً جديداً من إدارة المسجد',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      navigator.pop();
      return;
    }

    navigator.pop();
    widget.onProvisioned?.call();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.offer.isHandover
              ? 'تم تسليم إدارة ${branch.name} لهذا الجهاز'
              : 'تم إنشاء إدارة ${branch.name} بنجاح — احفظي كود الإدارة',
        ),
        backgroundColor: AppColors.emeraldPrimary,
      ),
    );

    // كود الإدارة يُعرض هنا فقط ويبقى على جهاز المديرة، ولا تراه إدارة الرجال.
    showDialog(
      context: navigator.context,
      builder: (_) => PrintableBadgeDialog(
        title: 'بطاقة إدارة القسم النسائي',
        name: 'إدارة ${branch.name}',
        roleLabel: 'إدارة القسم النسائي المعتمدة',
        mosqueName: branch.name,
        code: branch.accessCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHandover = widget.offer.isHandover;

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
              isHandover
                  ? 'استلام إدارة القسم النسائي'
                  : 'إنشاء إدارة القسم النسائي',
              style: AppTypography.titleBold(context, fontSize: 16),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'الرمز صادر من: ${widget.offer.parentMosque.name}\n'
                  'سيتم إنشاء إدارة مستقلة تماماً: طالباتك ومعلماتك وحلقاتك '
                  'وجوائزك وفعالياتك لا تظهر لإدارة الرجال إطلاقاً، ولا تظهر لك '
                  'سجلات الرجال.',
                  style: AppTypography.bodyRegular(
                    context,
                    fontSize: 12,
                  ).copyWith(height: 1.55),
                ),
              ),
              const SizedBox(height: 14),
              if (!isHandover) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم القسم النسائي *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المدينة / المحافظة',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الحي / العنوان',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'هاتف التواصل (اختياري)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLocating ? null : _captureLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.location_on,
                          color: _capturedPosition != null
                              ? Colors.green
                              : AppColors.emeraldPrimary,
                        ),
                  label: Text(
                    _capturedPosition != null
                        ? 'تم تثبيت موقع القسم النسائي ✅'
                        : 'تحديد الموقع (اختياري — يورَّث موقع المسجد)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: _capturedPosition != null
                          ? Colors.green
                          : AppColors.emeraldPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'القسم النسائي منشأ مسبقاً. سيتم تسليم إدارته لهذا الجهاز '
                    'وإظهار كود الإدارة لك.',
                    style: AppTypography.verveSubtitle(
                      context,
                    ).copyWith(fontSize: 12, height: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.terracottaPrimary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            isHandover ? 'استلام الإدارة' : 'إنشاء الإدارة النسائية',
            style: AppTypography.buttonText(),
          ),
        ),
      ],
    );
  }
}
