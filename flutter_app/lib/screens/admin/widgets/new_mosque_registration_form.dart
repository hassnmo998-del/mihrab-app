import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/printable_badge_dialog.dart';

/// نموذج تسجيل جامع جديد بعد التحقق من كود المشرف العام (`REG-`).
///
/// يُستخدم من بوابة إدارة المسجد ومن الماسح العام، فمسح باركود التسجيل من أي
/// مكان في التطبيق يفتح هذا النموذج مباشرة. عند الاعتماد يُستهلك الكود ويُرفع
/// للسحابة ليظهر الجامع وكوده في سجل المشرف العام.
class NewMosqueRegistrationForm extends StatefulWidget {
  final String token;
  final void Function(Mosque mosque, ActiveSession session) onRegistered;
  final VoidCallback? onCancel;

  const NewMosqueRegistrationForm({
    super.key,
    required this.token,
    required this.onRegistered,
    this.onCancel,
  });

  @override
  State<NewMosqueRegistrationForm> createState() => _NewMosqueRegistrationFormState();
}

class _NewMosqueRegistrationFormState extends State<NewMosqueRegistrationForm> {
  final _newMosqueNameCtrl = TextEditingController();
  final _newMosqueCityCtrl = TextEditingController(text: 'دمشق');
  final _newMosqueAddressCtrl = TextEditingController();
  final _newMosquePhoneCtrl = TextEditingController();
  /// كل تسجيل من هذه الشاشة هو فرع رجال؛ الفرع النسائي يُنشأ بمسح رمز التسليم.
  static const String _newMosqueGender = 'male';
  Position? _capturedPosition;
  bool _isLocating = false;
  bool _isSubmitting = false;

  Future<void> _captureLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        setState(() => _capturedPosition = pos);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديد موقع المسجد بنجاح! 📍')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى السماح بالوصول للموقع لتحديد مكان المسجد')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديد الموقع')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    final data = context.read<DataService>();
    final name = _newMosqueNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم المسجد')),
      );
      return;
    }
    // منع تسجيل جامعين بنفس الكود عند الضغط المتكرر
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final mosque = data.addMosque(
      name: name,
      address: _newMosqueAddressCtrl.text.trim(),
      city: _newMosqueCityCtrl.text.trim(),
      gender: _newMosqueGender,
      phone: _newMosquePhoneCtrl.text.trim(),
      latitude: _capturedPosition?.latitude,
      longitude: _capturedPosition?.longitude,
    );

    // Consume the registration token and link it to this mosque
    // (يُرفع للسحابة ليظهر في سجل كل أجهزة المشرف العام)
    if (widget.token.isNotEmpty) {
      await data.consumeRegistrationToken(
        token: widget.token,
        mosqueName: mosque.name,
        mosqueAddress: '${mosque.city} - ${mosque.address ?? ""}',
        mosqueAccessCode: mosque.accessCode,
      );
    }
    if (!mounted) return;

    // Auto switch to Mosque Manager role immediately!
    final session = ActiveSession(
      role: 'mosque_admin',
      code: mosque.accessCode,
      name: 'مدير ${mosque.name}',
      mosqueId: mosque.id,
      mosqueName: mosque.name,
      gender: mosque.gender,
    );
    data.switchSession(session);

    widget.onRegistered(mosque, session);
  }

  @override
  void dispose() {
    _newMosqueNameCtrl.dispose();
    _newMosqueCityCtrl.dispose();
    _newMosqueAddressCtrl.dispose();
    _newMosquePhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.add_business, color: AppTheme.emeraldPrimary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('تسجيل مسجد جديد (صلاحية مفتوحة ✅)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (widget.onCancel != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onCancel,
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _newMosqueNameCtrl,
          decoration: const InputDecoration(
            labelText: 'اسم المسجد *',
            hintText: 'مثال: جامع الإيمان، جامع الهدى',
            prefixIcon: Icon(Icons.mosque),
          ),
        ),
        const SizedBox(height: 12),

        // القسم النسائي لا يُسجَّل من هنا: يُنشأ حصراً بمسح رمز
        // التسليم الصادر من إدارة المسجد بعد اعتمادها.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.terracottaPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.terracottaPrimary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.female, size: 18, color: AppColors.terracottaPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'القسم النسائي: بعد اعتماد إدارة المسجد، يصدر المدير '
                  'رمز تسليم من لوحة الإدارة، وتمسحه المديرة من جهازها '
                  'لتُنشئ إدارة نسائية مستقلة تماماً بكودها الخاص. لا '
                  'يمكن تسجيل قسم نسائي من هذه الصفحة.',
                  style: AppTypography.bodyRegular(context, fontSize: 11.5)
                      .copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newMosqueCityCtrl,
                decoration: const InputDecoration(labelText: 'المدينة / المحافظة *'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _newMosqueAddressCtrl,
                decoration: const InputDecoration(labelText: 'الحي / العنوان التفصيلي *'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newMosquePhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'هاتف التواصل مع إدارة المسجد',
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 14),

        // Location Warning Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.goldDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تنبيه هام: يجب أن تكون متواجداً داخل المسجد عند ضغط الزر أدناه. هذا الموقع سيتم حفظه لمرة واحدة ليتمكن التطبيق من حساب بعد المصلين عن جامعكم بدقة.',
                  style: AppTypography.font(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Location Capture Button
        OutlinedButton.icon(
          onPressed: _isLocating ? null : _captureLocation,
          icon: _isLocating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.location_on, color: _capturedPosition != null ? Colors.green : AppTheme.emeraldPrimary),
          label: Text(
            _capturedPosition != null
                ? 'تم تثبيت الموقع الحالي للمسجد ✅'
                : 'تحديد موقع المسجد (إحداثيات GPS الحالية) 📍',
            style: TextStyle(
              color: _capturedPosition != null ? Colors.green : AppTheme.emeraldPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: _capturedPosition != null ? Colors.green : AppTheme.emeraldPrimary),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('اعتماد المسجد والبدء في الإدارة فوراً'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emeraldPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// صفحة كاملة تُفتح مباشرة بعد مسح باركود التسجيل من الماسح العام.
/// تُغلق نفسها عند الاعتماد وتعيد الجامع والجلسة الجديدة لمن فتحها.
class NewMosqueRegistrationScreen extends StatelessWidget {
  final String token;

  const NewMosqueRegistrationScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل جامع جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: NewMosqueRegistrationForm(
                  token: token,
                  onRegistered: (mosque, session) =>
                      Navigator.of(context).pop((mosque, session)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// رسالة النجاح وبطاقة المدير بالباركود الرسمي بعد اعتماد الجامع.
void showMosqueRegisteredFeedback(BuildContext context, Mosque mosque) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('تم تسجيل المسجد بنجاح! كودك المعتمد هو: ${mosque.accessCode}'),
      backgroundColor: AppTheme.emeraldPrimary,
    ),
  );
  showDialog(
    context: context,
    builder: (_) => PrintableBadgeDialog(
      title: 'بطاقة مدير المسجد والباركود الرسمي',
      name: 'إدارة ${mosque.name}',
      roleLabel: 'مدير المسجد المعتمد',
      mosqueName: mosque.name,
      code: mosque.accessCode,
    ),
  );
}
