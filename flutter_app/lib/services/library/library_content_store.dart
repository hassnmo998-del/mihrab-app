import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ملفات المكتبة على الجهاز: فهارس الكتب وأجزاؤها ونسخة الفهرس العام.
///
/// في المتصفح (نسخة الآيفون) لا نظام ملفات، فكل قراءة تعيد null وكل كتابة
/// تُتجاهل؛ هناك يكفي كاش المتصفح لأن روابط الأجزاء لا يتغيّر محتواها.
class LibraryContentStore {
  LibraryContentStore({this.rootOverride});

  /// مجلد بديل للاختبارات.
  final String? rootOverride;

  Directory? _root;
  bool _resolved = false;

  bool get isPersistent => !kIsWeb;

  Future<Directory?> _rootDir() async {
    if (kIsWeb) return null;
    if (_resolved) return _root;
    _resolved = true;
    try {
      final base = rootOverride ?? (await getApplicationSupportDirectory()).path;
      _root = Directory('$base${Platform.pathSeparator}library');
    } catch (e) {
      debugPrint('ℹ️ Library store unavailable (memory only): $e');
      _root = null;
    }
    return _root;
  }

  Future<File?> _file(String relativePath) async {
    final root = await _rootDir();
    if (root == null) return null;
    return File('${root.path}${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}');
  }

  Future<String?> read(String relativePath) async {
    try {
      final file = await _file(relativePath);
      if (file == null || !await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('⚠️ Library store read $relativePath: $e');
      return null;
    }
  }

  /// يكتب إلى ملف مؤقت ثم يعيد تسميته، فلا يبقى ملف ناقص إن أُغلق التطبيق
  /// في منتصف الكتابة.
  Future<void> write(String relativePath, String content) async {
    try {
      final file = await _file(relativePath);
      if (file == null) return;
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.part');
      await temp.writeAsString(content, flush: true);
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('⚠️ Library store write $relativePath: $e');
    }
  }

  Future<void> delete(String relativePath) async {
    try {
      final file = await _file(relativePath);
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> deleteDir(String relativeDir) async {
    try {
      final root = await _rootDir();
      if (root == null) return;
      final dir = Directory('${root.path}${Platform.pathSeparator}'
          '${relativeDir.replaceAll('/', Platform.pathSeparator)}');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('⚠️ Library store delete $relativeDir: $e');
    }
  }

  /// أسماء المجلدات الفرعية المباشرة داخل [relativeDir].
  Future<List<String>> listDirs(String relativeDir) async {
    try {
      final root = await _rootDir();
      if (root == null) return const [];
      final dir = Directory('${root.path}${Platform.pathSeparator}'
          '${relativeDir.replaceAll('/', Platform.pathSeparator)}');
      if (!await dir.exists()) return const [];
      return [
        await for (final entity in dir.list())
          if (entity is Directory) entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      ];
    } catch (_) {
      return const [];
    }
  }
}
