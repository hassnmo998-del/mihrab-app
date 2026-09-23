import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// حدود التخزين في أرشيف تيليجرام ومدة تسجيل الدرس.
class MediaLimits {
  MediaLimits._();

  /// أكبر ملف يستطيع البوت تنزيله عبر `getFile` (حد تيليجرام الرسمي).
  /// الملف الأكبر يُرفع لكنه لا يُفتح أبداً، لذلك نمنعه قبل الرفع.
  static const int maxFileBytes = 20 * 1024 * 1024;

  /// أقصى مدة لتسجيل الدرس. بضغط 32kbps تبلغ الساعة نحو 14MB.
  static const Duration maxRecording = Duration(minutes: 60);

  /// إعدادات ضغط الصوت: كلام أحادي القناة بوضوح ممتاز وحجم صغير.
  static const int recordingBitRate = 32000;
  static const int recordingSampleRate = 16000;

  static String formatMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  static String get maxFileMbLabel => formatMb(maxFileBytes);
}

/// سبب تعذّر تجهيز رابط الملف.
enum TelegramResolveError { none, tooBig, unavailable }

class TelegramResolveResult {
  final String? url;
  final TelegramResolveError error;
  const TelegramResolveResult(this.url, this.error);
}

/// حلّ مراجع الوسائط المحفوظة في أرشيف تيليجرام.
///
/// تيليجرام لا يمنح رابطاً دائماً إطلاقاً: الرابط الناتج عن `getFile` مضمون
/// لساعة واحدة فقط ثم يصبح 404. الشيء الدائم الوحيد هو `file_id`، لذلك يُحفظ
/// في قاعدة البيانات بصيغة `tg:audio:<file_id>` أو `tg:video:<file_id>` أو
/// `tg:file:<file_id>|<اسم الملف>` للمرفقات، ويُحوَّل إلى رابط طازج عند كل فتح.
class TelegramMediaResolver {
  TelegramMediaResolver._();

  static const String botToken = '8892398548:AAHYb1zNhswSWLyvAhygYkUqXeBNi3-fvqM';

  static const String _prefix = 'tg:';

  /// يفصل معرّف الملف عن اسمه الأصلي في مراجع المرفقات.
  static const String _nameSeparator = '|';

  /// تيليجرام يضمن الرابط لساعة؛ نجدّده قبلها بهامش أمان.
  static const Duration _cacheTtl = Duration(minutes: 45);

  static final Map<String, _CachedUrl> _cache = {};

  /// المرجع الدائم الذي يُحفظ في قاعدة البيانات بدل الرابط المؤقت.
  static String buildRef({required String fileId, required bool isVideo}) =>
      '$_prefix${isVideo ? 'video' : 'audio'}:$fileId';

  /// مرجع مرفق عام (مستند، فيديو قصير، صوت...) مع اسمه الأصلي لعرضه وفتحه.
  static String buildFileRef({required String fileId, required String fileName}) =>
      '${_prefix}file:$fileId$_nameSeparator${Uri.encodeComponent(fileName)}';

  static bool isRef(String? value) =>
      value != null && value.trim().startsWith(_prefix);

  static bool isVideoRef(String value) =>
      value.trim().startsWith('${_prefix}video:');

  static bool isFileRef(String value) =>
      value.trim().startsWith('${_prefix}file:');

  /// الاسم الأصلي لملف مرفق، أو null للمراجع الأخرى.
  static String? fileNameOf(String value) {
    if (!isFileRef(value)) return null;
    final idx = value.indexOf(_nameSeparator);
    if (idx < 0) return null;
    try {
      return Uri.decodeComponent(value.substring(idx + 1).trim());
    } catch (_) {
      return null;
    }
  }

  /// رابط تيليجرام مباشر محفوظ بالطريقة القديمة: انتهت صلاحيته ولا يمكن
  /// تجديده لأن الـ file_id لم يكن يُحفظ وقتها.
  static bool isExpiredLegacyLink(String value) =>
      value.trim().startsWith('https://api.telegram.org/file/bot');

  static String? fileIdOf(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 3) return null;
    final rest = parts.sublist(2).join(':');
    final idx = rest.indexOf(_nameSeparator);
    final id = idx < 0 ? rest : rest.substring(0, idx);
    return id.isEmpty ? null : id;
  }

  /// يحوّل القيمة المخزّنة إلى مسار قابل للتشغيل.
  /// المسارات المحلية والروابط الخارجية العادية تُعاد كما هي.
  /// يُعيد null إذا تعذّر تجديد الرابط (انقطاع إنترنت، ملف محذوف، أو ملف أكبر من الحد).
  static Future<String?> resolve(String stored) async => (await resolveResult(stored)).url;

  /// مثل [resolve] مع سبب الفشل، ليعرف المستخدم هل المشكلة بالاتصال أم بحجم الملف.
  static Future<TelegramResolveResult> resolveResult(String stored) async {
    final clean = stored.trim();
    if (clean.isEmpty) return const TelegramResolveResult(null, TelegramResolveError.unavailable);
    if (!isRef(clean)) return TelegramResolveResult(clean, TelegramResolveError.none);

    final fileId = fileIdOf(clean);
    if (fileId == null) return const TelegramResolveResult(null, TelegramResolveError.unavailable);

    final cached = _cache[fileId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return TelegramResolveResult(cached.url, TelegramResolveError.none);
    }

    try {
      final res = await http
          .get(Uri.parse('https://api.telegram.org/bot$botToken/getFile'
              '?file_id=${Uri.encodeQueryComponent(fileId)}'))
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        final url =
            'https://api.telegram.org/file/bot$botToken/${body['result']['file_path']}';
        _cache[fileId] = _CachedUrl(url, DateTime.now().add(_cacheTtl));
        return TelegramResolveResult(url, TelegramResolveError.none);
      }
      final description = body['description']?.toString() ?? '';
      debugPrint('⚠️ getFile رفض المعرّف: $description');
      if (description.toLowerCase().contains('too big')) {
        return const TelegramResolveResult(null, TelegramResolveError.tooBig);
      }
    } catch (e) {
      debugPrint('⚠️ تعذر تجديد رابط تيليجرام: $e');
    }
    return const TelegramResolveResult(null, TelegramResolveError.unavailable);
  }

  /// رسالة واضحة للمستخدم حسب سبب الفشل.
  static String failureMessage(TelegramResolveError error) => error == TelegramResolveError.tooBig
      ? 'هذا الملف أكبر من ${MediaLimits.maxFileMbLabel} ميغابايت، ولا يمكن تشغيله من الأرشيف'
      : 'تعذّر تجهيز الملف، تحقق من الاتصال بالإنترنت وأعد المحاولة';

  static void clearCache() => _cache.clear();
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  const _CachedUrl(this.url, this.expiresAt);
}
