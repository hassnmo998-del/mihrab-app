import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// تصدير كشوف الصراف: مشاركة نصية سريعة، أو ملف CSV يُفتح في Excel.
class CashierLedgerExport {
  CashierLedgerExport._();

  /// يشارك الكشف كنص عادي (واتساب، بريد، ملاحظات...).
  static Future<void> shareText(String statement) async {
    await Share.share(statement);
  }

  static Future<void> copyToClipboard(String statement) async {
    await Clipboard.setData(ClipboardData(text: statement));
  }

  /// يحفظ الملف في مجلد التنزيلات (سطح المكتب) أو مستندات التطبيق، ثم يشاركه.
  ///
  /// يعيد مسار الملف عند النجاح، و`null` إن تعذّر الحفظ.
  static Future<String?> shareCsv({
    required String csv,
    required String fileNamePrefix,
  }) async {
    final file = await _writeFile(
      content: csv,
      fileNamePrefix: fileNamePrefix,
      extension: 'csv',
    );
    if (file == null) return null;

    try {
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'text/csv',
            name: file.uri.pathSegments.last,
          ),
        ],
        text: 'كشف صرف الجوائز (ملف Excel)',
      );
    } catch (e) {
      debugPrint('CashierLedgerExport.shareCsv share error: $e');
    }
    return file.path;
  }

  static Future<File?> _writeFile({
    required String content,
    required String fileNamePrefix,
    required String extension,
  }) async {
    if (kIsWeb) return null;
    try {
      Directory? targetDir;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        try {
          targetDir = await getDownloadsDirectory();
        } catch (_) {}
      }
      targetDir ??= await getApplicationDocumentsDirectory();

      final safePrefix =
          fileNamePrefix.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final sep = Platform.isWindows ? '\\' : '/';
      var fullPath = '${targetDir.path}$sep${safePrefix}_$stamp.$extension';
      if (Platform.isWindows) fullPath = fullPath.replaceAll('/', '\\');

      final file = File(fullPath);
      // UTF-8 مع BOM (مضمّن في المحتوى) ليقرأ Excel العربية بشكل صحيح
      await file.writeAsString(content, encoding: const Utf8Codec());
      return file;
    } catch (e) {
      debugPrint('CashierLedgerExport._writeFile error: $e');
      return null;
    }
  }
}
