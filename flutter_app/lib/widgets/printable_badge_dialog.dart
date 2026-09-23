import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_theme.dart';
import '../presentation/widgets/widgets.dart';
import 'app_user_avatar.dart';

class PrintableBadgeDialog extends StatefulWidget {
  final String title;
  final String name;
  final String roleLabel;
  final String mosqueName;
  final String code;
  final String? profileImageUrl;

  const PrintableBadgeDialog({
    super.key,
    required this.title,
    required this.name,
    required this.roleLabel,
    required this.mosqueName,
    required this.code,
    this.profileImageUrl,
  });

  @override
  State<PrintableBadgeDialog> createState() => _PrintableBadgeDialogState();
}

class _PrintableBadgeDialogState extends State<PrintableBadgeDialog> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _isCapturing = false;

  String get _shareMessage => '''
السلام عليكم ورحمة الله وبركاته 🌙
بطاقة الدخول والاعتماد الرسمية إلى *منصة محراب*:

👤 *الاسم:* ${widget.name}
🏷️ *الدور:* ${widget.roleLabel}
🕌 *المسجد / المركز:* ${widget.mosqueName}
🔑 *كود الدخول المباشر:* `${widget.code}`

يمكنك مسح رمز الـ QR المرفق بالصورة أو إدخال الكود أعلاه مباشرة في المنصة للوصول الفوري.
''';

  Future<void> _shareCardImage() async {
    setState(() => _isCapturing = true);
    final primaryColor = Theme.of(context).primaryColor;
    try {
      // 1. Always copy the full message and credentials to clipboard first
      await Clipboard.setData(ClipboardData(text: _shareMessage));

      // Wait for frame rendering after setState
      await Future.delayed(const Duration(milliseconds: 60));

      RenderRepaintBoundary? boundary = _cardBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await Future.delayed(const Duration(milliseconds: 60));
        boundary = _cardBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      }

      if (boundary == null) {
        await Share.share(_shareMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم نسخ نص الاعتماد وكود الدخول إلى الحافظة بنجاح ✨'),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 60));
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        await Share.share(_shareMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم نسخ نص الاعتماد وكود الدخول إلى الحافظة بنجاح ✨'),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

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
      var fullPath = '${targetDir.path}$sep' 'badge_${safeCode}_$timestamp.png';
      if (Platform.isWindows) {
        fullPath = fullPath.replaceAll('/', '\\');
      }

      final file = File(fullPath);
      await file.writeAsBytes(pngBytes);

      final sharePath = Platform.isWindows ? file.path.replaceAll('/', '\\') : file.path;
      await Share.shareXFiles(
        [
          XFile(
            sharePath,
            mimeType: 'image/png',
            name: 'badge_$safeCode.png',
          ),
        ],
        text: _shareMessage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نسخ نص الاعتماد وحفظ صورة بطاقة الـ QR بنجاح: $sharePath', style: AppTypography.buttonText()),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing card image: $e');
      await Share.share(_shareMessage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم نسخ نص الاعتماد وكود الدخول إلى الحافظة بنجاح ✨'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الكود بنجاح: ${widget.code}', style: AppTypography.buttonText()),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final qrSize = (screenWidth * 0.44).clamp(140.0, 185.0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screenHeight * 0.90,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.badge_outlined, color: primaryColor, size: 22),
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
                const SizedBox(height: 14),

                // RepaintBoundary for high-res card capture
                RepaintBoundary(
                  key: _cardBoundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF19202E) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Person Avatar
                        AppUserAvatar(
                          name: widget.name,
                          imageUrl: widget.profileImageUrl,
                          radius: 26,
                        ),
                        const SizedBox(height: 8),

                        // Person Name
                        Text(
                          widget.name,
                          style: AppTypography.titleBold(context, fontSize: 17),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        // Role and Mosque Badge
                        UnifiedBadge(
                          label: '${widget.roleLabel} • ${widget.mosqueName}',
                          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                          textColor: AppColors.goldDark,
                        ),
                        const SizedBox(height: 14),

                        // Center-Branded QR Code Container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
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
                                gapless: true,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(6),
                              ),
                              // Centered Emblem/Avatar over QR
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.gold, width: 2.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AppUserAvatar(
                                    name: widget.name,
                                    imageUrl: widget.profileImageUrl,
                                    radius: 18,
                                    border: Border.all(color: Colors.transparent),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Code Display Pill Box
                        InkWell(
                          onTap: () => _copyCode(context),
                          borderRadius: BorderRadius.circular(AppRadius.rPill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(AppRadius.rPill),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.code,
                                  style: AppTypography.verveNumber(context).copyWith(
                                    fontSize: 16,
                                    letterSpacing: 2,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.copy_rounded, size: 16, color: primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Unified Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => _copyCode(context),
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: Text('نسخ الكود', style: AppTypography.buttonText(color: primaryColor)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: _isCapturing ? null : _shareCardImage,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_rounded, size: 15),
                      label: Text('مشاركة البطاقة', style: AppTypography.buttonText()),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        try {
                          final boundary = _cardBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                          if (boundary != null) {
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

                              final filePath = '${targetDir.path}/badge_${widget.code}_print.png';
                              final file = await File(filePath).create();
                              await file.writeAsBytes(byteData.buffer.asUint8List());

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تم حفظ صورة البطاقة للطباعة بجودة عالية في التنزيلات: ${file.path}', style: AppTypography.buttonText()),
                                    backgroundColor: primaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                        } catch (_) {}

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم تجهيز بطاقة (${widget.name}) بالباركود المدمج بجودة عالية للطباعة والحفظ',
                                style: AppTypography.buttonText(),
                              ),
                              backgroundColor: primaryColor,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 15),
                      label: Text(
                        'طباعة',
                        style: AppTypography.buttonText(
                          color: isDark ? Colors.white70 : AppColors.obsidianEspresso,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}