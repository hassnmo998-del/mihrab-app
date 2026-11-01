import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/sync/discover_search.dart';

/// بحث «اكتشف»: الحروف العربية المتشابهة، وسلامة النص الذي يدخل استعلام الخادم.
void main() {
  Mosque mosque(String name, {String city = 'دمشق', String? address}) => Mosque(
        id: 'm',
        name: name,
        city: city,
        address: address,
        gender: 'male',
        accessCode: '',
      );

  CommunityEvent event(String title, {String organizer = '', String mosqueId = 'm'}) =>
      CommunityEvent.fromJson({
        'id': 'e',
        'mosque_id': mosqueId,
        'title': title,
        'organizer_name': organizer,
      });

  group('normalize', () {
    test('التاء المربوطة والهاء، وأنواع الألف، والياء والألف المقصورة', () {
      expect(DiscoverSearch.normalize('الروضة'), DiscoverSearch.normalize('الروضه'));
      expect(DiscoverSearch.normalize('أحمد'), DiscoverSearch.normalize('احمد'));
      expect(DiscoverSearch.normalize('إبراهيم'), DiscoverSearch.normalize('ابراهيم'));
      expect(DiscoverSearch.normalize('مصطفى'), DiscoverSearch.normalize('مصطفي'));
    });

    test('التشكيل والتطويل لا يمنعان المطابقة', () {
      expect(DiscoverSearch.normalize('الرَّحْمَن'), DiscoverSearch.normalize('الرحمن'));
      expect(DiscoverSearch.normalize('الـــرحمن'), DiscoverSearch.normalize('الرحمن'));
    });

    test('مسافات متعددة ولاتينية', () {
      expect(DiscoverSearch.normalize('  جامع   الروضة '), 'جامع الروضه');
      expect(DiscoverSearch.normalize('ALEPPO'), 'aleppo');
    });
  });

  group('likeTerm: نص آمن لاستعلام الخادم', () {
    test('الأحرف المتشابهة تصير _ فيطابق الصورتين', () {
      final t = DiscoverSearch.likeTerm('الروضة')!;
      expect(t.contains('ة'), isFalse);
      expect(t.endsWith('_'), isTrue);
      expect(t.startsWith('_'), isTrue, reason: 'الألف في البداية');
      expect(DiscoverSearch.likeTerm('احمد'), DiscoverSearch.likeTerm('أحمد'));
    });

    test('محارف صياغة المرشّح تُحذف ولا تصل الاستعلام', () {
      final t = DiscoverSearch.likeTerm('حلب),city.eq."x"*%\\');
      expect(t, isNotNull);
      for (final bad in [',', '(', ')', '"', '*', '%', '\\', "'", ':']) {
        expect(t!.contains(bad), isFalse, reason: 'بقي $bad');
      }
      // الشرطة السفلية من المستخدم لا تتحول إلى «أي حرف» عنده
      expect(DiscoverSearch.likeTerm('ح_ب')!.contains('_'), isFalse);
    });

    test('أقل من حرفين، أو محارف صياغة فقط: لا بحث', () {
      expect(DiscoverSearch.likeTerm('ح'), isNull);
      expect(DiscoverSearch.likeTerm('   '), isNull);
      expect(DiscoverSearch.likeTerm('*%,()'), isNull);
      expect(DiscoverSearch.isSearchable('ح'), isFalse);
      expect(DiscoverSearch.isSearchable('حل'), isTrue);
    });

    test('المسافة داخل الاسم تبقى (جامع الروضة)', () {
      expect(DiscoverSearch.likeTerm('جامع الروضة')!.contains(' '), isTrue);
    });
  });

  group('المطابقة المحلية', () {
    test('مسجد بالاسم أو المدينة أو العنوان، بتجاهل الاختلافات', () {
      final m = mosque('جامع الروضة', city: 'حلب', address: 'حي الشعار');
      expect(DiscoverSearch.matchesMosque(m, 'الروضه'), isTrue);
      expect(DiscoverSearch.matchesMosque(m, 'حلب'), isTrue);
      expect(DiscoverSearch.matchesMosque(m, 'الشعار'), isTrue);
      expect(DiscoverSearch.matchesMosque(m, 'حمص'), isFalse);
    });

    test('درس بعنوانه أو محاضره أو مسجده أو مدينة مسجده', () {
      final m = mosque('جامع النور', city: 'حمص');
      expect(DiscoverSearch.matchesEvent(event('شرح الأربعين'), m, 'اربعين'), isTrue);
      expect(DiscoverSearch.matchesEvent(event('درس', organizer: 'الشيخ أحمد'), m, 'احمد'), isTrue);
      expect(DiscoverSearch.matchesEvent(event('درس'), m, 'حمص'), isTrue, reason: 'مدينة المسجد');
      expect(DiscoverSearch.matchesEvent(event('درس'), m, 'النور'), isTrue);
      expect(DiscoverSearch.matchesEvent(event('درس'), null, 'حمص'), isFalse);
      expect(DiscoverSearch.matchesEvent(event('درس'), m, 'دمشق'), isFalse);
    });

    test('بحث فارغ يطابق الكل', () {
      expect(DiscoverSearch.matchesEvent(event('أي شيء'), null, ''), isTrue);
    });
  });
}
