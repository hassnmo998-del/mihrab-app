import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/code_scanner_dialog.dart';
import '../../../widgets/qr_dialogs.dart';
import '../../../widgets/printable_badge_dialog.dart';
import 'package:geolocator/geolocator.dart';

class AdminLockedView extends StatefulWidget {
  final bool isDark;
  final VoidCallback onSessionUnlocked;

  const AdminLockedView({
    super.key,
    required this.isDark,
    required this.onSessionUnlocked,
  });

  @override
  State<AdminLockedView> createState() => _AdminLockedViewState();
}

class _AdminLockedViewState extends State<AdminLockedView> {
  final _newMosqueNameCtrl = TextEditingController();
  final _newMosqueCityCtrl = TextEditingController(text: 'دمشق');
  final _newMosqueAddressCtrl = TextEditingController();
  final _newMosquePhoneCtrl = TextEditingController();
  /// كل تسجيل من هذه الشاشة هو فرع رجال؛ الفرع النسائي يُنشأ بمسح رمز التسليم.
  static const String _newMosqueGender = 'male';
  Position? _capturedPosition;
  bool _isLocating = false;
  bool _isRegistrationUnlocked = false;
  String? _usedToken;

  void _openSuperAdminScanner() {
    showDialog(
      context: context,
      builder: (ctx) => UniversalQrScannerDialog(
        title: 'اعتماد تسجيل جامع جديد',
        hintText: 'امسح الباركود من جهاز المشرف العام لفتح صلاحية التسجيل',
        onCodeScanned: (code) async {
          final data = context.read<DataService>();
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(ctx);

          // التحقق يتم من السحابة حتى يعمل كود مولَّد على جهاز المشرف العام
          final result = await data.checkRegistrationToken(code);
          if (!mounted) return;

          if (result == RegistrationTokenCheck.valid) {
            setState(() {
              _isRegistrationUnlocked = true;
              _usedToken = code.trim().toUpperCase();
            });
            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('تم التحقق من الكود بنجاح! يمكنك الآن تسجيل الجامع الجديد.'), backgroundColor: Colors.green),
            );
          } else {
            final message = switch (result) {
              RegistrationTokenCheck.alreadyUsed =>
                'هذا الكود مستخدم مسبقاً لتسجيل مسجد آخر',
              RegistrationTokenCheck.unreachable =>
                'تعذّر الوصول للسحابة للتحقق من الكود — تأكد من اتصال هذا الجهاز بالإنترنت',
              _ => 'كود غير صالح، تأكد من مسح باركود صادر من المشرف العام',
            };
            messenger.showSnackBar(SnackBar(content: Text(message)));
          }
        },
      ),
    );
  }

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
      setState(() => _isLocating = false);
    }
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
    final data = context.read<DataService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.sunsetTwilightGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.heroBanner,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.mosque_outlined, size: 50, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'بوابة إدارة المسجد الرسمية',
                      style: GoogleFonts.amiri(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'سجّل مسجداً جديداً للبدء في إدارته فوراً، أو أدخل كود اعتماد مدير المسجد',
                      style: GoogleFonts.cairo(color: const Color(0xFFF9EAE1), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Option 1: Register New Mosque
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: !_isRegistrationUnlocked
                      ? Column(
                    children: [
                      Icon(Icons.lock_person_outlined, size: 40, color: AppTheme.emeraldPrimary),
                      const SizedBox(height: 12),
                      const Text(
                        'تسجيل المساجد الجديدة يتطلب اعتماد المشرف العام',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'للحصول على صلاحية الإدارة، يرجى التواصل مع المشرف العام لمسح كود الاعتماد الخاص بك.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _openSuperAdminScanner,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('مسح كود اعتماد المشرف العام'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.obsidianEspresso,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_business, color: AppTheme.emeraldPrimary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('تسجيل مسجد جديد (صلاحية مفتوحة ✅)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _isRegistrationUnlocked = false),
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
                        onPressed: () async {
                          final name = _newMosqueNameCtrl.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          if (name.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('يرجى إدخال اسم المسجد')),
                            );
                            return;
                          }
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
                          if (_usedToken != null) {
                            await data.consumeRegistrationToken(
                              token: _usedToken!,
                              mosqueName: mosque.name,
                              mosqueAddress: '${mosque.city} - ${mosque.address ?? ""}',
                              mosqueAccessCode: mosque.accessCode,
                            );
                          }
                          if (!context.mounted) return;

                          // Auto switch to Mosque Manager role immediately!
                          data.switchSession(ActiveSession(
                            role: 'mosque_admin',
                            code: mosque.accessCode,
                            name: 'مدير ${mosque.name}',
                            mosqueId: mosque.id,
                            mosqueName: mosque.name,
                            gender: mosque.gender,
                          ));

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('تم تسجيل المسجد بنجاح! كودك المعتمد هو: ${mosque.accessCode}'),
                              backgroundColor: AppTheme.emeraldPrimary,
                            ),
                          );

                          widget.onSessionUnlocked();
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
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('اعتماد المسجد والبدء في الإدارة فوراً'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Option 2: Enter Existing Code / Scan
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('مسجلك معتمد مسبقاً؟', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        'امسح كود الـ QR الخاص بالمسجد أو أدخل كود المدير للوصول لإدارتك',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => CodeScannerDialog(
                              onSessionUnlocked: (_) => widget.onSessionUnlocked(),
                            ),
                          );
                        },
                        icon: Icon(Icons.qr_code_scanner, color: AppTheme.emeraldPrimary),
                        label: const Text('إدخال كود أو مسح رمز المسجد'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.emeraldPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
