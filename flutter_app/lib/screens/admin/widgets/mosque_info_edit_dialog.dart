import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';

/// تعديل معلومات المسجد التي أُدخلت عند تسجيله: الاسم، المدينة، العنوان،
/// الهاتف، والموقع. كود الإدارة والفرع (رجال/نساء) لا يتغيّران من هنا.
class MosqueInfoEditDialog extends StatefulWidget {
  final Mosque mosque;

  const MosqueInfoEditDialog({super.key, required this.mosque});

  static Future<void> show(BuildContext context, Mosque mosque) => showDialog<void>(
        context: context,
        builder: (_) => MosqueInfoEditDialog(mosque: mosque),
      );

  @override
  State<MosqueInfoEditDialog> createState() => _MosqueInfoEditDialogState();
}

class _MosqueInfoEditDialogState extends State<MosqueInfoEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;

  Position? _newPosition;
  bool _isLocating = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final m = widget.mosque;
    _nameCtrl = TextEditingController(text: m.name);
    _cityCtrl = TextEditingController(text: m.city);
    _addressCtrl = TextEditingController(text: m.address ?? '');
    _phoneCtrl = TextEditingController(text: m.phone ?? '');
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        setState(() => _newPosition = pos);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('يرجى السماح بالوصول للموقع لتحديث مكان المسجد')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر تحديد الموقع الآن')));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'اسم المسجد مطلوب');
      return;
    }
    final city = _cityCtrl.text.trim();

    context.read<DataService>().updateMosque(
          id: widget.mosque.id,
          name: name,
          // المدينة لا تُترك فارغة: تُعرض بجانب اسم المسجد في كل القوائم
          city: city.isEmpty ? widget.mosque.city : city,
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          latitude: _newPosition?.latitude,
          longitude: _newPosition?.longitude,
        );

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('تم حفظ معلومات المسجد'),
        backgroundColor: AppColors.emeraldPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final located = _newPosition != null;
    final accent = located ? Colors.green : AppColors.emeraldPrimary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Icon(Icons.edit_location_alt_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تعديل معلومات المسجد',
              style: AppTypography.titleBold(context, fontSize: 16),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم المسجد *',
                  prefixIcon: const Icon(Icons.mosque),
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'المدينة / المحافظة'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'الحي / العنوان التفصيلي'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'هاتف التواصل مع إدارة المسجد',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isLocating ? null : _captureLocation,
                icon: _isLocating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.location_on, color: accent),
                label: Text(
                  located
                      ? 'سيُحفظ موقعك الحالي موقعاً للمسجد ✅'
                      : 'تغيير موقع المسجد إلى موقعي الحالي 📍',
                  style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  side: BorderSide(color: accent),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                located
                    ? 'اضغط «حفظ» لاعتماد الموقع الجديد.'
                    : 'الموقع الحالي للمسجد يبقى كما هو ما لم تضغط الزر، واضغطه وأنت داخل المسجد.',
                style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('حفظ'),
        ),
      ],
    );
  }
}
