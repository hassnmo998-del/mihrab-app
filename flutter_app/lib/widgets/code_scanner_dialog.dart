import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/access_code_generator.dart';
import '../screens/admin/widgets/women_branch_setup_dialog.dart';
import '../services/data_service.dart';
import '../models/models.dart';

class CodeScannerDialog extends StatefulWidget {
  final Function(ActiveSession) onSessionUnlocked;
  final String? targetRole;

  const CodeScannerDialog({
    super.key,
    required this.onSessionUnlocked,
    this.targetRole,
  });

  @override
  State<CodeScannerDialog> createState() => _CodeScannerDialogState();
}

class _CodeScannerDialogState extends State<CodeScannerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MobileScannerController? _scannerController;
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isProcessing = false; // منع المسح المتكرر
  String? _errorMessage;

  bool get _isCameraSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (_isCameraSupported) {
      _scannerController = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.normal,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كود الدخول');
      return;
    }

    // ⛔ منع استدعاءات متزامنة (الكاميرا تكتشف الـ QR عشرات المرات في الثانية)
    if (_isProcessing) return;
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _isLoading = true;
      _errorMessage = null;
    });

    // 🔍 debug: شوف ايش يقرأ الباركود بالضبط
    debugPrint('📷 QR scanned raw: "$code" → clean: "$clean"');

    // رمز إنشاء القسم النسائي لا يمنح جلسة على مسجد الرجال؛ يفتح نافذة إنشاء
    // إدارة نسائية مستقلة بكودها الخاص. هذا هو المنفذ الوحيد لوجود قسم نسائي.
    final offer = await DataService().inspectWomenProvisionToken(clean);
    if (!mounted) return;
    if (offer != null) {
      setState(() {
        _isLoading = false;
        _isProcessing = false;
      });
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (_) => WomenBranchSetupDialog(
          offer: offer,
          onProvisioned: () {
            final session = DataService().getSessionForRole('mosque_admin');
            if (session != null) widget.onSessionUnlocked(session);
          },
        ),
      );
      return;
    }

    if (AccessCodeGenerator.isWomenProvisionToken(clean) ||
        AccessCodeGenerator.isLegacyWomenCode(clean)) {
      setState(() {
        _isLoading = false;
        _isProcessing = false;
        _errorMessage =
            'رمز القسم النسائي غير صالح أو مستخدم مسبقاً. اطلبي رمز تسليم جديداً من إدارة المسجد.';
      });
      return;
    }

    final session = await DataService().verifyCode(clean);
    debugPrint('📷 verifyCode result: ${session?.role} / ${session?.name}');
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isProcessing = false;
    });

    if (session != null) {
      // ✅ استبدل الجلسة القديمة لنفس الرتبة تلقائياً (بدلاً من التراكم)
      DataService().setRoleSession(session);
      Navigator.pop(context);
      widget.onSessionUnlocked(session);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل الدخول بنجاح: ${session.name} (${session.roleLabel})',
            style: AppTypography.buttonText(),
          ),
          backgroundColor: AppColors.terracottaPrimary,
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'الكود غير صحيح أو لم يتم العثور على صاحب هذا الرمز في المنظومة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom - 40;
    final maxDialogHeight = availableHeight.clamp(340.0, 540.0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxDialogHeight),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unified Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الدخول عبر الكود أو بطاقة الـ QR',
                    style: AppTypography.titleBold(context, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tabs (Amiri Font & Verve Style)
            TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 13.5),
              unselectedLabelStyle: GoogleFonts.amiri(fontWeight: FontWeight.w600, fontSize: 13.5),
              tabs: const [
                Tab(icon: Icon(Icons.keyboard_outlined, size: 18), text: 'إدخال الكود يدوياً'),
                Tab(icon: Icon(Icons.camera_alt_outlined, size: 18), text: 'مسح الباركود بالكاميرا'),
              ],
            ),
            Divider(height: 1, thickness: 0.8, color: dividerColor),
            const SizedBox(height: 10),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Manual Input
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: AppTypography.verveNumber(context).copyWith(
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            labelText: 'أدخل كود الاعتماد الممنوح لك',
                            hintText: 'مثال: MSQ-1234 أو SHK-5678 أو STD-9012',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => _codeController.clear(),
                            ),
                          ),
                          onSubmitted: _submitCode,
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            style: AppTypography.bodyRegular(
                              context,
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _isLoading ? null : () => _submitCode(_codeController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                              : Text('تأكيد الدخول المعتمد', style: AppTypography.buttonText()),
                        ),
                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'يحصل المحفظ على كود الحلقة من مدير المسجد، ويحصل الطالب وولي أمره على كوده وبطاقة الـ QR من المحفظ.',
                                  style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Camera Scanner
                  _isCameraSupported && _scannerController != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ExcludeSemantics(
                                child: MobileScanner(
                                  controller: _scannerController!,
                                  onDetect: (capture) {
                                    final List<Barcode> barcodes = capture.barcodes;
                                    for (final barcode in barcodes) {
                                      if (barcode.rawValue != null) {
                                        _submitCode(barcode.rawValue!);
                                        break;
                                      }
                                    }
                                  },
                                ),
                              ),
                              Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.primary, width: 2.5),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(AppRadius.rPill),
                                  ),
                                  child: Text(
                                    'وجّه الكاميرا نحو رمز الـ QR المعتمد',
                                    style: AppTypography.buttonText(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.videocam_off_rounded, size: 36, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'المسح بالكاميرا متاح على الهواتف الذكية فقط',
                                  style: AppTypography.titleBold(context, fontSize: 13.5),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'على أجهزة الكمبيوتر، يُرجى استخدام التبويب الأول وإدخال الكود يدويًا.',
                                  style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11.5),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: () => _tabController.animateTo(0),
                                  icon: const Icon(Icons.keyboard_outlined, size: 16),
                                  label: const Text('إدخال الكود يدويًا', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}