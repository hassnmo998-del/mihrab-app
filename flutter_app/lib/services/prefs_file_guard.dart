import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ما وجده الحارس عند فتح التطبيق.
enum PrefsFileState {
  /// الملف سليم (أو لا ملف بعد: تثبيت جديد).
  healthy,

  /// الملف تالف واستُعيد من النسخة المرآة.
  restored,

  /// الملف تالف ولا نسخة مرآة صالحة: أُزيح جانباً ليبدأ التطبيق نظيفاً بدل أن يتعطل.
  reset,
}

/// يحمي ملف الإعدادات والبيانات المحلية على ويندوز ولينكس من انقطاع الكهرباء.
///
/// على هاتين المنصتين تحفظ `shared_preferences` كل شيء (الجلسات، بيانات المساجد،
/// طابور المزامنة، إعدادات الأذان) في ملف JSON واحد، وتعيد كتابته كاملاً فوق نفسه مع
/// كل حفظ. انقطاع الكهرباء أثناء الكتابة يترك الملف مبتوراً، والحزمة لا تقرأ ملفاً
/// مبتوراً: كل قراءة وكل حفظ بعدها يرمي خطأ، فلا يتذكر التطبيق شيئاً حتى يُحذف الملف
/// يدوياً.
///
/// الحارس يبقي بجانب الملف نسخة مرآة مكتملة دائماً (تُكتب في ملف مؤقت، تُثبَّت على
/// القرص، ثم تُبدَّل باسمها)، ويستعيد منها عند الفتح إن وُجد الملف تالفاً. أندرويد
/// والويب وآيفون يحفظون بطريقة آمنة أصلاً، فالحارس لا يعمل عليها.
class PrefsFileGuard {
  PrefsFileGuard._();

  static const String fileName = 'shared_preferences.json';
  static const String mirrorName = 'shared_preferences.mirror.json';

  static Directory? _dir;
  static Timer? _timer;
  static bool _mirroring = false;
  static DateTime? _mirroredModified;
  static int? _mirroredLength;

  static bool get _supported => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// يُستدعى أول شيء عند التشغيل، قبل أي قراءة من `SharedPreferences`.
  ///
  /// [directory] للاختبار؛ بدونه يُستعمل مجلد بيانات التطبيق على المنصات المعنيّة فقط.
  static Future<PrefsFileState> init({
    Directory? directory,
    Duration mirrorEvery = const Duration(seconds: 5),
  }) async {
    try {
      if (directory == null) {
        if (!_supported || Platform.environment.containsKey('FLUTTER_TEST')) {
          return PrefsFileState.healthy;
        }
        directory = await getApplicationSupportDirectory();
      }
      _dir = directory;
      final state = repair(directory);
      _timer?.cancel();
      _timer = Timer.periodic(mirrorEvery, (_) => mirrorNow());
      return state;
    } catch (e) {
      debugPrint('⚠️ PrefsFileGuard init: $e');
      return PrefsFileState.healthy;
    }
  }

  /// يوقف المرآة الدورية (للاختبار).
  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _dir = null;
    _mirroredModified = null;
    _mirroredLength = null;
  }

  static File _file(Directory dir, String name) => File('${dir.path}${Platform.pathSeparator}$name');

  static bool _isJsonMap(String content) {
    try {
      return content.isNotEmpty && jsonDecode(content) is Map;
    } catch (_) {
      return false;
    }
  }

  static bool _readable(File f) {
    try {
      return f.existsSync() && _isJsonMap(f.readAsStringSync());
    } catch (_) {
      return false;
    }
  }

  /// يفحص الملف، ويستعيده من المرآة إن كان تالفاً. لا يرمي.
  @visibleForTesting
  static PrefsFileState repair(Directory dir) {
    final file = _file(dir, fileName);
    final mirror = _file(dir, mirrorName);
    try {
      final exists = file.existsSync();
      if (exists && _readable(file)) return PrefsFileState.healthy;
      final hasMirror = _readable(mirror);
      // تثبيت جديد: لا ملف ولا مرآة
      if (!exists && !hasMirror) return PrefsFileState.healthy;

      if (exists) {
        // يُحتفظ بالتالف مرة واحدة للتشخيص، ولا يبقى في طريق التطبيق
        final aside = _file(dir, 'shared_preferences.damaged.json');
        try {
          if (aside.existsSync()) aside.deleteSync();
          file.renameSync(aside.path);
        } catch (_) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      }
      if (hasMirror) {
        mirror.copySync(file.path);
        debugPrint('🛟 PrefsFileGuard: ملف الإعدادات كان تالفاً واستُعيد من النسخة المرآة');
        return PrefsFileState.restored;
      }
      debugPrint('⚠️ PrefsFileGuard: ملف الإعدادات تالف ولا نسخة مرآة؛ يبدأ التطبيق نظيفاً');
      return PrefsFileState.reset;
    } catch (e) {
      debugPrint('⚠️ PrefsFileGuard repair: $e');
      return PrefsFileState.healthy;
    }
  }

  /// يحدّث المرآة إن تغيّر الملف منذ آخر مرة. لا يكتب إلا محتوى مكتملاً صالحاً.
  static Future<void> mirrorNow() async {
    final dir = _dir;
    if (dir == null || _mirroring) return;
    _mirroring = true;
    try {
      final file = _file(dir, fileName);
      if (!file.existsSync()) return;
      final stat = file.statSync();
      if (stat.modified == _mirroredModified && stat.size == _mirroredLength) return;

      // قراءة متزامنة على الخيط نفسه الذي تكتب منه الحزمة: لا تقع في منتصف كتابة
      final content = file.readAsStringSync();
      if (!await compute(_isJsonMap, content)) return;

      final mirror = _file(dir, mirrorName);
      final tmp = _file(dir, '$mirrorName.tmp');
      await tmp.writeAsString(content, flush: true);
      await tmp.rename(mirror.path);
      _mirroredModified = stat.modified;
      _mirroredLength = stat.size;
    } catch (e) {
      debugPrint('⚠️ PrefsFileGuard mirror: $e');
    } finally {
      _mirroring = false;
    }
  }
}
