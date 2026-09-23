import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';

class UniversalQrScannerDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final Function(String code) onCodeScanned;

  const UniversalQrScannerDialog({
    super.key,
    required this.title,
    this.hintText = 'وجّه الكاميرا نحو رمز الاستجابة السريعة (QR)',
    required this.onCodeScanned,
  });

  @override
  State<UniversalQrScannerDialog> createState() => _UniversalQrScannerDialogState();
}

class _UniversalQrScannerDialogState extends State<UniversalQrScannerDialog> {
  MobileScannerController? _scannerController;
  final TextEditingController _manualCtrl = TextEditingController();
  bool _hasScanned = false;
  bool _showManual = false;

  bool get _isCameraSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isCameraSupported) {
      _scannerController = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.normal,
      );
    } else {
      _showManual = true;
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _hasScanned = true;
        widget.onCodeScanned(code.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    widget.title,
                    style: AppTypography.titleBold(context, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.hintText,
              style: AppTypography.verveSubtitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (!_showManual && _isCameraSupported && _scannerController != null) ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ExcludeSemantics(
                        child: MobileScanner(
                          controller: _scannerController!,
                          onDetect: _onDetect,
                        ),
                      ),
                      Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.terracottaPrimary, width: 2.5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terracottaPrimary,
                ),
                onPressed: () => setState(() => _showManual = true),
                icon: const Icon(Icons.keyboard_outlined, size: 18),
                label: Text('أو الإدخال اليدوي للرمز', style: AppTypography.buttonText(color: AppColors.terracottaPrimary)),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _manualCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: AppTypography.bodyRegular(context, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'رمز الكود المعلق أو القسيمة',
                          hintText: 'مثال: VCH-1234 أو WM-XXXX',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final c = _manualCtrl.text.trim();
                            if (c.isNotEmpty) {
                              widget.onCodeScanned(c);
                            }
                          },
                          child: Text('تأكيد الرمز', style: AppTypography.buttonText()),
                        ),
                      ),
                      if (_isCameraSupported) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                          ),
                          onPressed: () => setState(() => _showManual = false),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text('العودة لمسح الكاميرا', style: AppTypography.buttonText(color: isDark ? Colors.white70 : AppColors.lightTextPrimary)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudentRedemptionQrDialog extends StatelessWidget {
  final Student student;
  final Reward reward;

  const StudentRedemptionQrDialog({
    super.key,
    required this.student,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final qrSize = (screenWidth * 0.42).clamp(130.0, 180.0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 390,
          maxHeight: screenHeight * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded,
                      color: theme.colorScheme.primary, size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  'أبرز هويتك للصراف',
                  style: AppTypography.titleBold(context, fontSize: 17),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'يرجى التوجه لصراف المسجد ومسح الكود الخاص بك لاستلام جائزة (${reward.title})',
                  style: AppTypography.verveSubtitle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Student Barcode
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: student.code,
                    version: QrVersions.auto,
                    size: qrSize,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),

                // Summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('اسم الطالب:',
                              style: AppTypography.verveSubtitle(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              student.fullName,
                              textAlign: TextAlign.end,
                              style: AppTypography.titleBold(context, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('كود الطالب:',
                              style: AppTypography.verveSubtitle(context)),
                          const SizedBox(width: 8),
                          Text(
                            student.code,
                            style: AppTypography.titleBold(
                              context,
                              fontSize: 15,
                              color: AppColors.terracottaPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('إغلاق', style: AppTypography.buttonText()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RewardVoucherQrDialog extends StatelessWidget {
  final RewardRedemption redemption;

  const RewardVoucherQrDialog({
    super.key,
    required this.redemption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final qrSize = (screenWidth * 0.42).clamp(130.0, 180.0);

    final boundaryKey = GlobalKey();

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 390,
          maxHeight: screenHeight * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: boundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.card_giftcard_rounded, color: AppColors.goldDark, size: 30),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'باركود قسيمة الجائزة للصراف',
                          style: AppTypography.titleBold(context, fontSize: 17),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'أبرز هذا الباركود لصراف المسجد المعتمد لاستلام جائزتك فوراً',
                          style: AppTypography.verveSubtitle(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),

                        // Clean QR Frame (Always pure white backing for scanner readability)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: redemption.redemptionCode,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Voucher Details Box (Open Verve Style)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('الجائزة:', style: AppTypography.verveSubtitle(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      redemption.rewardTitle,
                                      textAlign: TextAlign.end,
                                      style: AppTypography.titleBold(context, fontSize: 13.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('رمز القسيمة:', style: AppTypography.verveSubtitle(context)),
                                  const SizedBox(width: 8),
                                  Text(
                                    redemption.redemptionCode,
                                    style: AppTypography.titleBold(
                                      context,
                                      fontSize: 15,
                                      color: AppColors.terracottaPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('النقاط المصروفة:', style: AppTypography.verveSubtitle(context)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${redemption.pointsSpent} نقطة',
                                    style: AppTypography.titleBold(
                                      context,
                                      fontSize: 13.5,
                                      color: AppColors.goldDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                UnifiedQrActionsRow(
                  code: redemption.redemptionCode,
                  shareTitle: 'قسيمة استلام: ${redemption.rewardTitle}',
                  shareBody: '🎉 قسيمة جائزة معتمدة عبر منصة محراب\nالجائزة: ${redemption.rewardTitle}\nالنقاط المخصومة: ${redemption.pointsSpent} نقطة',
                  primaryColor: AppColors.terracottaPrimary,
                  boundaryKey: boundaryKey,
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق', style: AppTypography.buttonText(color: isDark ? Colors.white60 : Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionQrCodeDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String code;
  final IconData icon;
  final Color? primaryColor;

  const SectionQrCodeDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.icon,
    this.primaryColor,
  });

  @override
  State<SectionQrCodeDialog> createState() => _SectionQrCodeDialogState();
}

class _SectionQrCodeDialogState extends State<SectionQrCodeDialog> {
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = widget.primaryColor ?? theme.primaryColor;
    final dialogBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final qrSize = (screenWidth * 0.44).clamp(135.0, 185.0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenHeight * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // RepaintBoundary for high-res sharing
                RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: effectiveColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: effectiveColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon, color: effectiveColor, size: 30),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.title,
                          style: AppTypography.titleBold(context, fontSize: 17),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: AppTypography.verveSubtitle(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),

                        // Center-Branded QR Frame
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              QrImageView(
                                data: widget.code,
                                version: QrVersions.auto,
                                errorCorrectionLevel: QrErrorCorrectLevel.H,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(6),
                              ),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: effectiveColor, width: 2.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(widget.icon, color: effectiveColor, size: 22),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Code Display Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: effectiveColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.rPill),
                          ),
                          child: Text(
                            widget.code,
                            style: AppTypography.verveNumber(context).copyWith(
                              fontSize: 17,
                              color: effectiveColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                UnifiedQrActionsRow(
                  code: widget.code,
                  shareTitle: widget.title,
                  shareBody: '${widget.title}\n${widget.subtitle}',
                  primaryColor: effectiveColor,
                  boundaryKey: _boundaryKey,
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق', style: AppTypography.buttonText(color: isDark ? Colors.white60 : Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnifiedQrActionsRow extends StatefulWidget {
  final String code;
  final String shareTitle;
  final String shareBody;
  final Color? primaryColor;
  final VoidCallback? onPrint;
  final GlobalKey? boundaryKey;

  const UnifiedQrActionsRow({
    super.key,
    required this.code,
    required this.shareTitle,
    required this.shareBody,
    this.primaryColor,
    this.onPrint,
    this.boundaryKey,
  });

  @override
  State<UnifiedQrActionsRow> createState() => _UnifiedQrActionsRowState();
}

class _UnifiedQrActionsRowState extends State<UnifiedQrActionsRow> {
  bool _isCapturing = false;

  void _copy(BuildContext context) {
    final effectiveColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الرمز بنجاح: ${widget.code}', style: AppTypography.buttonText()),
        backgroundColor: effectiveColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share() async {
    final effectiveColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final fullText = '${widget.shareBody}\n\n🔑 رمز الكود المباشر: ${widget.code}\n(يمكن مسح رمز الـ QR أو إدخال الكود أعلاه مباشرة في المنصة)';

    // 1. Copy full text with code immediately to clipboard
    await Clipboard.setData(ClipboardData(text: fullText));

    if (widget.boundaryKey != null) {
      setState(() => _isCapturing = true);
      try {
        await Future.delayed(const Duration(milliseconds: 60));
        RenderRepaintBoundary? boundary = widget.boundaryKey!.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          await Future.delayed(const Duration(milliseconds: 60));
          boundary = widget.boundaryKey!.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        }
        if (boundary != null) {
          if (boundary.debugNeedsPaint) {
            await Future.delayed(const Duration(milliseconds: 60));
          }
          final image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            Directory? targetDir;
            try {
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                targetDir = await getDownloadsDirectory();
              }
            } catch (_) {}
            targetDir ??= await getApplicationDocumentsDirectory();

            final sep = Platform.isWindows ? '\\' : '/';
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final safeCode = widget.code.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
            var fullPath = '${targetDir.path}$sep' 'qr_card_${safeCode}_$timestamp.png';
            if (Platform.isWindows) {
              fullPath = fullPath.replaceAll('/', '\\');
            }

            final file = File(fullPath);
            await file.writeAsBytes(byteData.buffer.asUint8List());

            final sharePath = Platform.isWindows ? file.path.replaceAll('/', '\\') : file.path;
            await Share.shareXFiles(
              [
                XFile(
                  sharePath,
                  mimeType: 'image/png',
                  name: 'qr_card_$safeCode.png',
                ),
              ],
              text: fullText,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم نسخ نص الرمز وحفظ بطاقة الـ QR بنجاح: $sharePath', style: AppTypography.buttonText()),
                  backgroundColor: effectiveColor,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Error sharing QR card: $e');
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
    }

    await Share.share(fullText);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم نسخ نص الرمز وكود الدخول إلى الحافظة بنجاح ✨'),
          backgroundColor: effectiveColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _saveOrPrint(BuildContext context) async {
    final effectiveColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    if (widget.onPrint != null) {
      widget.onPrint!();
    } else {
      if (widget.boundaryKey != null) {
        try {
          await Future.delayed(const Duration(milliseconds: 60));
          RenderRepaintBoundary? boundary = widget.boundaryKey!.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary == null) {
            await Future.delayed(const Duration(milliseconds: 60));
            boundary = widget.boundaryKey!.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          }
          if (boundary != null) {
            if (boundary.debugNeedsPaint) {
              await Future.delayed(const Duration(milliseconds: 60));
            }
            final image = await boundary.toImage(pixelRatio: 3.0);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              Directory? targetDir;
              try {
                if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                  targetDir = await getDownloadsDirectory();
                }
              } catch (_) {}
              targetDir ??= await getApplicationDocumentsDirectory();

              final sep = Platform.isWindows ? '\\' : '/';
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final safeCode = widget.code.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
              var fullPath = '${targetDir.path}$sep' 'qr_card_${safeCode}_print_$timestamp.png';
              if (Platform.isWindows) {
                fullPath = fullPath.replaceAll('/', '\\');
              }

              final file = File(fullPath);
              await file.writeAsBytes(byteData.buffer.asUint8List());

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حفظ صورة الرمز للطباعة بجودة عالية في التنزيلات: $fullPath', style: AppTypography.buttonText()),
                    backgroundColor: effectiveColor,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('Error saving QR print: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تجهيز البطاقة والكود للطباعة أو الحفظ: ${widget.code}', style: AppTypography.buttonText()),
            backgroundColor: effectiveColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = widget.primaryColor ?? Theme.of(context).primaryColor;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: effectiveColor,
            side: BorderSide(color: effectiveColor.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const StadiumBorder(),
          ),
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_rounded, size: 15),
          label: Text('نسخ', style: AppTypography.buttonText(color: effectiveColor)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          onPressed: _isCapturing ? null : _share,
          icon: _isCapturing
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.share_rounded, size: 15),
          label: Text('مشاركة', style: AppTypography.buttonText()),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : AppColors.lightTextPrimary,
            side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: const StadiumBorder(),
          ),
          onPressed: () => _saveOrPrint(context),
          icon: const Icon(Icons.print_rounded, size: 15),
          label: Text('طباعة', style: AppTypography.buttonText(color: isDark ? Colors.white70 : AppColors.lightTextPrimary)),
        ),
      ],
    );
  }
}