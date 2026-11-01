import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/update/release_notes.dart';

/// ملاحظات الإصدار كما تصل نافذة التحديث: الجديد يُفصل عن السابق، والعناوين عن الأوصاف.
void main() {
  test('الصيغة المعتادة: عنوان الإصدار، الجديد، ثم السابقة مطوية', () {
    final n = ParsedReleaseNotes.parse(
      '🕌 محراب 1.0.20 — مزامنة أخف:\n'
      '• مزامنة أخف وأسرع: كل جهاز يحمّل مسجده فقط.\n'
      '• لوحة المشرف العام: أرقام وبحث.\n'
      '\n'
      '📚 ومن الإصدارات السابقة:\n'
      '• 1.0.19: مواقيت بدقة الموقع.\n'
      '• رفع تسجيل الدرس من ملف.\n',
    );
    expect(n.headline, 'مزامنة أخف');
    expect(n.current, hasLength(2));
    expect(n.current.first.title, 'مزامنة أخف وأسرع');
    expect(n.current.first.body, 'كل جهاز يحمّل مسجده فقط.');
    expect(n.previous, hasLength(2));
    expect(n.previous.first.title, '1.0.19');
    expect(n.previous.last.title, isEmpty);
    expect(n.previous.last.body, 'رفع تسجيل الدرس من ملف.');
    expect(n.plain, isEmpty);
  });

  test('نقطة بلا عنوان تبقى وصفاً كاملاً، والنقطتان في ساعة أو رابط ليستا عنواناً', () {
    final n = ParsedReleaseNotes.parse(
      '🕌 محراب 1.0.5:\n'
      '• الأذان يكتمل والتطبيق مغلق.\n'
      '• الدرس يبدأ 6:30 مساءً كل سبت.\n'
      '• راجع الشرح: https://example.test/help\n',
    );
    expect(n.current[0].title, isEmpty);
    expect(n.current[0].body, 'الأذان يكتمل والتطبيق مغلق.');
    expect(n.current[1].title, isEmpty, reason: 'الساعة ليست عنواناً');
    expect(n.current[2].title, 'راجع الشرح');
  });

  test('سطر تابع لنقطة التفّ نصها يُضم إليها', () {
    final n = ParsedReleaseNotes.parse('🕌 محراب 1.0.6:\n• تحسين مهم في الأداء\nيشمل المكتبة والأذكار.\n');
    expect(n.current, hasLength(1));
    expect(n.current.single.body, contains('يشمل المكتبة والأذكار.'));
  });

  test('ماركداون: النجوم والشباك لا تظهر', () {
    final n = ParsedReleaseNotes.parse('## ما الجديد\n- **مزامنة**: أخف\n- __الأذان__: أدق\n');
    expect(n.current.map((i) => i.title), ['مزامنة', 'الأذان']);
    expect(n.current.first.body, 'أخف');
  });

  test('نص بلا نقاط يُعرض كله كما كتبه صاحبه (لا يُبتلع سطره الأول)', () {
    final n = ParsedReleaseNotes.parse('إصلاحات مهمة في الأذان\nوتحسينات في الأداء');
    expect(n.current, isEmpty);
    expect(n.plain, 'إصلاحات مهمة في الأذان\nوتحسينات في الأداء');
  });

  test('ملاحظات جيت هاب الآلية (Full Changelog فقط): جملة عامة لا رابط', () {
    final n = ParsedReleaseNotes.parse('**Full Changelog**: https://github.com/x/y/compare/v1...v2');
    expect(n.current, hasLength(2));
    expect(n.current.first.body, contains('تحسينات عامة'));
  });

  test('فارغ، أو سابقة فقط: الجديد غير فارغ دائماً حين يوجد ما يُعرض', () {
    expect(ParsedReleaseNotes.parse('   ').isEmpty, isTrue);
    final onlyPrev = ParsedReleaseNotes.parse('📚 ومن الإصدارات السابقة:\n• أ\n• ب\n');
    expect(onlyPrev.current, hasLength(2));
    expect(onlyPrev.previous, isEmpty);
  });

  test('RELEASE_NOTES.md الحقيقي في المستودع يُفكّ كما ينبغي', () {
    final file = File('../RELEASE_NOTES.md');
    if (!file.existsSync()) return;
    final n = ParsedReleaseNotes.parse(file.readAsStringSync());
    expect(n.current.length, inInclusiveRange(1, 8), reason: 'الجديد قصير وواضح');
    expect(n.headline, isNotEmpty);
    for (final item in n.current) {
      expect(item.body, isNotEmpty);
      expect(item.title.length, lessThanOrEqualTo(40));
    }
  });
}
