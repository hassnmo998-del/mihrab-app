import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/code_scanner_dialog.dart';

class SheikhLockedView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSessionUnlocked;

  const SheikhLockedView({
    super.key,
    required this.isDark,
    required this.onSessionUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.terracottaPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu_book_outlined, size: 64, color: AppColors.terracottaPrimary),
              ),
              const SizedBox(height: 20),
              Text(
                'بوابة الشيخ المحفظ وإدارة الحلقة',
                style: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'هذا القسم مخصص لمحفظي ومعلمات الحلقات القرآنية.\nامسح كود الـ QR أو أدخل الرمز الخاص بك الممنوح من مدير المسجد لفتح إدارتك.',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => CodeScannerDialog(
                    onSessionUnlocked: (_) => onSessionUnlocked(),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text('امسح كود الحلقة المعتمد من مدير المسجد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
