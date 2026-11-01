/// بند واحد من ملاحظات الإصدار: «عنوان: وصف» أو وصف فقط.
class ReleaseNoteItem {
  final String title;
  final String body;
  const ReleaseNoteItem({this.title = '', required this.body});
}

/// ملاحظات الإصدار كما تصل من `RELEASE_NOTES.md` (عبر update.json أو GitHub)، مفصولة
/// لتعرضها نافذة التحديث بوضوح:
/// - [headline]: عنوان الإصدار (السطر الأول) بلا اسم التطبيق ورقمه.
/// - [current]: **الجديد في هذا الإصدار**، يظهر كاملاً بخط كبير.
/// - [previous]: ما بعد «ومن الإصدارات السابقة»، يُطوى ولا يزاحم الجديد.
/// - [plain]: نص بلا نقاط (ملاحظات كتبها أحد بغير الصيغة المعتادة)، يُعرض كما هو.
class ParsedReleaseNotes {
  final String headline;
  final List<ReleaseNoteItem> current;
  final List<ReleaseNoteItem> previous;
  final String plain;

  const ParsedReleaseNotes({
    this.headline = '',
    this.current = const [],
    this.previous = const [],
    this.plain = '',
  });

  bool get isEmpty => current.isEmpty && previous.isEmpty && plain.isEmpty;

  static final RegExp _bullet = RegExp(r'^(?:[•·▪◦‣\-\*]|\d+[.)])\s+(.*)$');

  /// عنوان قسم «السابقة» يُطوى ما بعده.
  static bool _isPreviousHeader(String line) {
    final l = line.toLowerCase();
    return l.contains('السابقة') || l.contains('الماضية') || l.contains('previous');
  }

  /// «🕌 محراب 1.0.20 — دقة المواقيت:» ← «دقة المواقيت»
  static String _cleanHeadline(String line) {
    var s = line.trim();
    s = s.replaceFirst(RegExp(r'[:：]\s*$'), '');
    s = s.replaceFirst(RegExp(r'^[^\p{L}\p{N}]*محراب\s+v?[\d.]+\s*[—–\-:：]?\s*', unicode: true), '');
    return s.trim();
  }

  /// يفصل «عنوان: وصف» حين يكون العنوان قصيراً فعلاً (لا جملة فيها نقطتان عرضاً).
  static ReleaseNoteItem _item(String text) {
    final t = text.trim();
    for (final sep in const [':', '：', ' — ']) {
      final i = t.indexOf(sep);
      if (i >= 3 && i <= 40 && i + sep.length < t.length) {
        final title = t.substring(0, i).trim();
        final body = t.substring(i + sep.length).trim();
        // «الرابط: https://…» أو ساعة «6:00» ليست عناوين
        if (body.isNotEmpty && !RegExp(r'^\d').hasMatch(body)) {
          return ReleaseNoteItem(title: title, body: body);
        }
      }
    }
    return ReleaseNoteItem(body: t);
  }

  static ParsedReleaseNotes parse(String raw) {
    var text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return const ParsedReleaseNotes();

    // ملاحظات جيت هاب الآلية (رابط التغييرات فقط): جملة عامة بدل رابط لا يفيد أحداً
    if (text.contains('Full Changelog') &&
        (text.startsWith('**Full Changelog**') || text.startsWith('Full Changelog'))) {
      return const ParsedReleaseNotes(current: [
        ReleaseNoteItem(body: 'تحسينات عامة في الأداء واستقرار التطبيق.'),
        ReleaseNoteItem(body: 'إصلاحات برمجية وتحديثات شاملة.'),
      ]);
    }

    // علامات الماركداون لا تُعرض نجوماً وشباكاً
    text = text.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');
    text = text.replaceAll('**', '').replaceAll('__', '');

    var headline = '';
    var inPrevious = false;
    final current = <String>[];
    final previous = <String>[];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        (inPrevious ? previous : current).add(bullet.group(1)!.trim());
        continue;
      }
      if (_isPreviousHeader(line)) {
        inPrevious = true;
        continue;
      }
      if (headline.isEmpty && current.isEmpty && previous.isEmpty) {
        headline = _cleanHeadline(line);
        continue;
      }
      final target = inPrevious ? previous : current;
      if (target.isNotEmpty && !line.endsWith(':') && !line.endsWith('：')) {
        // سطر تابع لنقطة التفّ نصها
        target[target.length - 1] = '${target.last} $line';
      }
      // عنوان قسم آخر (ينتهي بنقطتين): لا يُعرض
    }

    // لا نقاط إطلاقاً: النص كله يُعرض كما كتبه صاحبه (لا يُبتلع سطره الأول عنواناً)
    if (current.isEmpty && previous.isEmpty) {
      return ParsedReleaseNotes(plain: text.trim());
    }

    if (current.isEmpty) {
      current.addAll(previous);
      previous.clear();
    }

    return ParsedReleaseNotes(
      headline: headline,
      current: [for (final c in current) _item(c)],
      previous: [for (final p in previous) _item(p)],
    );
  }
}
