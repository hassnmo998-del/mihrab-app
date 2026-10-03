import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/zad_seed.dart';
import '../models/zad_content.dart';

/// يجلب صف الحزمة إن كانت مراجعته أحدث من [currentRev]، وإلا null.
typedef ZadPackFetcher = Future<Map<String, dynamic>?> Function(int currentRev);

/// محتوى تبويب «الأذكار والرقية»، يُحدَّث بلا إصدار جديد للتطبيق.
///
/// ثلاث طبقات، والأحدث مراجعةً يغلب:
///   1. النسخة المضمَّنة في التطبيق: تعمل من أول تشغيل بلا إنترنت.
///   2. آخر حزمة نزلت إلى الجهاز: تُحفظ في ملف وتبقى.
///   3. ما نُشر في Supabase (`tool/zad/publish.mjs`): يُطلب فقط إن كان أحدث مما
///      على الجهاز، فيُنزَّل مرة واحدة ثم يُقرأ من الجهاز بلا إنترنت.
/// حزمة معطوبة لا تُعرض ولا تُحفظ: يبقى ما كان.
class ZadContentService extends ChangeNotifier {
  ZadContentService._();
  static final ZadContentService instance = ZadContentService._();

  static const String _table = 'content_packs';
  static const String _key = 'zad';
  static const String _webPrefsKey = 'zad_content_pack';
  static const String _checkedAtPrefsKey = 'zad_content_checked_at';
  static const Duration _staleAfter = Duration(hours: 6);

  ZadContent? _content;
  ZadPackFetcher _fetch = _fetchFromSupabase;
  String? _dirOverride;
  ZadContent? _seedOverride;
  Future<void>? _loading;
  Future<bool>? _syncing;
  DateTime? _lastCheck;

  /// يُقرأ في بناء الواجهة: المضمَّن فوراً، ثم ما على الجهاز حين يُحمَّل.
  ZadContent get content => _content ??= _seedOverride ?? _seed();

  static ZadContent _seed() => ZadContent.fromJson(jsonDecode(kZadSeedJson) as Map<String, dynamic>);

  /// يحمّل ما حُفظ على الجهاز. آمن أن يُنادى أكثر من مرة.
  Future<void> init() => _loading ??= _loadStored();

  Future<void> _loadStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checked = prefs.getInt(_checkedAtPrefsKey);
      if (checked != null) _lastCheck = DateTime.fromMillisecondsSinceEpoch(checked);

      final raw = await _readStored(prefs);
      if (raw == null) return;
      final stored = ZadContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (stored.rev > content.rev) {
        _content = stored;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ℹ️ [ZadContent] stored pack ignored: $e');
    }
  }

  /// يسأل عن محتوى أحدث إن مضى على آخر سؤال [_staleAfter]. يُنادى عند فتح التبويب.
  void refreshIfStale() {
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < _staleAfter) return;
    unawaited(sync());
  }

  /// يجلب المحتوى الأحدث إن وُجد. يعيد true إن وصل جديد. لا يرمي: بلا إنترنت
  /// يبقى ما على الجهاز ويُعاد السؤال لاحقاً.
  Future<bool> sync() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<bool> _sync() async {
    await init();
    try {
      final row = await _fetch(content.rev);
      _lastCheck = DateTime.now();
      unawaited(_rememberCheck());
      if (row == null) return false;

      final payload = row['payload'];
      if (payload is! Map) throw const FormatException('payload ليس كائناً');
      final json = Map<String, dynamic>.from(payload);
      final fresh = ZadContent.fromJson(json);
      if (fresh.rev <= content.rev) return false;

      // يُحفظ قبل أن يُعرض: ما رآه المستخدم مرة يجده في كل فتح بعدها
      await _writeStored(jsonEncode(json));
      _content = fresh;
      notifyListeners();
      debugPrint('✅ [ZadContent] updated to rev ${fresh.rev}');
      return true;
    } catch (e) {
      debugPrint('ℹ️ [ZadContent] sync skipped: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _fetchFromSupabase(int currentRev) =>
      fetchPack(Supabase.instance.client, currentRev);

  /// الطلب نفسه الذي يرسله التطبيق: الصف فقط إن كانت مراجعته أحدث من [currentRev].
  @visibleForTesting
  static Future<Map<String, dynamic>?> fetchPack(SupabaseClient client, int currentRev) {
    return client
        .from(_table)
        .select('rev,payload')
        .eq('key', _key)
        .gt('rev', currentRev)
        .maybeSingle()
        .timeout(const Duration(seconds: 25));
  }

  Future<void> _rememberCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_checkedAtPrefsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // في المتصفح (نسخة الآيفون) لا نظام ملفات: الحزمة صغيرة فتُحفظ في تخزين المتصفح
  Future<File?> _storeFile() async {
    if (kIsWeb) return null;
    final base = _dirOverride ?? (await getApplicationSupportDirectory()).path;
    return File('$base${Platform.pathSeparator}content${Platform.pathSeparator}zad.json');
  }

  Future<String?> _readStored(SharedPreferences prefs) async {
    final file = await _storeFile();
    if (file == null) return prefs.getString(_webPrefsKey);
    return await file.exists() ? file.readAsString() : null;
  }

  /// يكتب إلى ملف مؤقت ثم يعيد تسميته، فلا يبقى ملف ناقص إن أُغلق التطبيق في منتصف الكتابة.
  Future<void> _writeStored(String raw) async {
    final file = await _storeFile();
    if (file == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webPrefsKey, raw);
      return;
    }
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.part');
    await temp.writeAsString(raw, flush: true);
    await temp.rename(file.path);
  }

  /// للاختبارات: حالة نظيفة بمصدر ومجلد بديلين.
  @visibleForTesting
  void debugReset({ZadPackFetcher? fetcher, String? dir, ZadContent? seed}) {
    _content = null;
    _seedOverride = seed;
    _loading = null;
    _syncing = null;
    _lastCheck = null;
    _fetch = fetcher ?? _fetchFromSupabase;
    _dirOverride = dir;
  }
}
