import '../../models/models.dart';

/// بحث «اكتشف» والتبرع: عن مسجد أو مدينة أو عنوان أو عنوان درس أو اسم محاضِر.
///
/// بالمزامنة بالنطاق لا تحمل الأجهزة كل المساجد، فيسأل التطبيق الخادم عمّا يكتبه
/// المستخدم. الكتابة بالعربية تختلف عمّا في القاعدة في أحرف متشابهة (الروضة / الروضه،
/// أحمد / احمد) فيُطبَّع الطرفان: محلياً بـ[normalize]، وفي الخادم بتحويل هذه الأحرف
/// إلى `_` (أي حرف واحد) في نمط `ilike`، فتطابق أياً من صورتيها.
class DiscoverSearch {
  const DiscoverSearch._();

  /// أقل طول للبحث (بعد التنظيف): حرف واحد يطابق نصف المنصة.
  static const int minLength = 2;

  static final RegExp _tashkeel = RegExp('[ً-ٰٟـ]');
  static const String _alef = 'أإآٱا';
  static const String _teh = 'ةه';
  static const String _yeh = 'يىئ';

  /// نص موحَّد للمقارنة: بلا تشكيل ولا تطويل، والألفات واحدة، والتاء المربوطة هاء،
  /// والياء والألف المقصورة واحدة، وصغير للاتينية، ومسافة واحدة.
  static String normalize(String raw) {
    final b = StringBuffer();
    for (final unit in raw.toLowerCase().replaceAll(_tashkeel, '').runes) {
      final ch = String.fromCharCode(unit);
      if (_alef.contains(ch)) {
        b.write('ا');
      } else if (_teh.contains(ch)) {
        b.write('ه');
      } else if (_yeh.contains(ch)) {
        b.write('ي');
      } else {
        b.write(ch);
      }
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// هل صار البحث بطول يكفي لتنفيذه؟
  static bool isSearchable(String raw) => normalize(raw).length >= minLength;

  /// جزء النمط الذي يوضع بين نجمتين في مرشّح `ilike` لـPostgREST، أو `null` إن لم يصلح.
  ///
  /// - المحارف التي لها معنى في صياغة المرشّح (`, ( ) " * % \ '` والنقطتان) تُحذف:
  ///   بقاؤها يكسر الاستعلام أو يغيّر معناه.
  /// - `_` من المستخدم يُحذف (له معنى «أي حرف» في LIKE).
  /// - الأحرف المتشابهة تصير `_`، فيطابق النمط الصورتين.
  static String? likeTerm(String raw) {
    final cleaned = raw
        .replaceAll(_tashkeel, '')
        .replaceAll(RegExp(r'''[,()"*%\\'_:;<>=!?&|{}\[\]]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final b = StringBuffer();
    var letters = 0;
    for (final unit in cleaned.runes) {
      final ch = String.fromCharCode(unit);
      if (ch == ' ') {
        b.write(' ');
        continue;
      }
      letters++;
      b.write(
        (_alef.contains(ch) || _teh.contains(ch) || _yeh.contains(ch)) ? '_' : ch,
      );
    }
    if (letters < minLength) return null;
    return b.toString();
  }

  /// مطابقة محلية لمسجد (الاسم أو المدينة أو العنوان).
  static bool matchesMosque(Mosque m, String rawQuery) {
    final q = normalize(rawQuery);
    if (q.isEmpty) return true;
    return normalize(m.name).contains(q) ||
        normalize(m.city).contains(q) ||
        normalize(m.address ?? '').contains(q);
  }

  /// مطابقة محلية لدرس: عنوانه أو محاضِره أو مسجده أو مدينة مسجده.
  static bool matchesEvent(CommunityEvent e, Mosque? m, String rawQuery) {
    final q = normalize(rawQuery);
    if (q.isEmpty) return true;
    if (normalize(e.title).contains(q) || normalize(e.organizerName).contains(q)) {
      return true;
    }
    return m != null && matchesMosque(m, rawQuery);
  }
}
