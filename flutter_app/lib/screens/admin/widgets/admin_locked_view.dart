import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/data_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/code_scanner_dialog.dart';
import '../../../widgets/qr_dialogs.dart';
import 'new_mosque_registration_form.dart';

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

  @override
  Widget build(BuildContext context) {
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
                      : NewMosqueRegistrationForm(
                    token: _usedToken ?? '',
                    onCancel: () => setState(() => _isRegistrationUnlocked = false),
                    onRegistered: (mosque, _) {
                      widget.onSessionUnlocked();
                      showMosqueRegisteredFeedback(context, mosque);
                    },
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
