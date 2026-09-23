import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';

class DesignExportService {
  DesignExportService._();

  /// Captures a RepaintBoundary key into high-resolution PNG bytes.
  static Future<Uint8List?> capturePng(GlobalKey boundaryKey, {double pixelRatio = 3.0}) async {
    try {
      RenderRepaintBoundary? boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await Future.delayed(const Duration(milliseconds: 60));
        boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      }
      if (boundary == null) return null;

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 60));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('DesignExportService capture error: $e');
      return null;
    }
  }

  /// Saves the bytes to user downloads/documents directory.
  static Future<File?> savePngToFile(Uint8List bytes, {required String fileNamePrefix}) async {
    try {
      Directory? targetDir;
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          try {
            targetDir = await getDownloadsDirectory();
          } catch (_) {}
        }
        targetDir ??= await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) return null;

      final sep = Platform.isWindows ? '\\' : '/';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safePrefix = fileNamePrefix.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      var fullPath = '${targetDir.path}$sep${safePrefix}_$timestamp.png';
      if (Platform.isWindows) {
        fullPath = fullPath.replaceAll('/', '\\');
      }
      final file = File(fullPath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('DesignExportService save error: $e');
      return null;
    }
  }

  /// Shares high-res image and copies formatted text to clipboard.
  static Future<void> shareDesign({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String fileNamePrefix,
    required String shareMessage,
    double pixelRatio = 3.0,
  }) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      // 1. Copy formatted text to clipboard first
      await Clipboard.setData(ClipboardData(text: shareMessage));

      final bytes = await capturePng(boundaryKey, pixelRatio: pixelRatio);
      if (bytes == null) {
        // Fallback to text share
        await Share.share(shareMessage);
        if (context.mounted) {
          _showToast(context, 'تم نسخ بيانات الاعتماد إلى الحافظة بنجاح ✨', primaryColor);
        }
        return;
      }

      final file = await savePngToFile(bytes, fileNamePrefix: fileNamePrefix);
      if (file != null) {
        final sharePath = Platform.isWindows ? file.path.replaceAll('/', '\\') : file.path;
        await Share.shareXFiles(
          [
            XFile(
              sharePath,
              mimeType: 'image/png',
              name: '$fileNamePrefix.png',
            ),
          ],
          text: shareMessage,
        );

        if (context.mounted) {
          _showToast(
            context,
            'تم تجهيز التصميم بنجاح وحفظ نسخة منه في: $sharePath',
            primaryColor,
          );
        }
      } else {
        await Share.share(shareMessage);
      }
    } catch (e) {
      debugPrint('Share design error: $e');
      await Share.share(shareMessage);
    }
  }

  /// Saves to storage and informs the user.
  static Future<void> saveToDevice({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String fileNamePrefix,
    double pixelRatio = 3.0,
  }) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      final bytes = await capturePng(boundaryKey, pixelRatio: pixelRatio);
      if (bytes == null) {
        if (context.mounted) {
          _showToast(context, 'تعذر التقاط صورة التصميم، يرجى المحاولة مجدداً', Colors.red);
        }
        return;
      }

      final file = await savePngToFile(bytes, fileNamePrefix: fileNamePrefix);
      if (file != null && context.mounted) {
        _showToast(
          context,
          'تم حفظ الصورة بدقة فائقة بنجاح 📁\nالمسار: ${file.path}',
          primaryColor,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'حدث خطأ أثناء حفظ الصورة: $e', Colors.red);
      }
    }
  }

  static void _showToast(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.font(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
