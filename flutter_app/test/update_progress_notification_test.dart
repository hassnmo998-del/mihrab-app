import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/update/update_models.dart';
import 'package:flutter_app/services/update/update_progress_notification.dart';

/// شريط تقدّم التحديث في الإشعارات: ما يعرضه، متى يُحدَّث، ومتى يختفي.
void main() {
  const mb = 1024 * 1024;
  final posted = <UpdateProgressView?>[];

  UpdateStatus status(UpdatePhase phase, int received, {int total = 100 * mb, String version = '1.0.14'}) =>
      UpdateStatus(
        owner: 'ui',
        atMs: DateTime.now().millisecondsSinceEpoch,
        phase: phase,
        received: received,
        total: total,
        version: version,
      );

  setUp(() async {
    posted.clear();
    UpdateProgressNotification.poster = (view) async => posted.add(view);
    await UpdateProgressNotification.clear();
    posted.clear();
  });

  tearDown(() => UpdateProgressNotification.poster = null);

  group('ما يعرضه الشريط', () {
    test('أثناء التنزيل: النسبة والحجم كما في الإعدادات', () {
      final view = UpdateProgressNotification.describe(status(UpdatePhase.downloading, 45 * mb));

      expect(view.title, 'جارٍ تنزيل تحديث محراب v1.0.14');
      expect(view.body, '45% • 45.0 من 100.0 ميغابايت');
      expect(view.percent, 45);
      expect(view.indeterminate, isFalse);
    });

    test('النسبة لا تتجاوز 100 ولا تُقرَّب إلى 100 قبل الاكتمال', () {
      expect(UpdateProgressNotification.describe(status(UpdatePhase.downloading, 100 * mb - 1)).percent, 99);
      expect(UpdateProgressNotification.describe(status(UpdatePhase.downloading, 100 * mb)).percent, 100);
      expect(UpdateProgressNotification.describe(status(UpdatePhase.downloading, 0)).percent, 0);
    });

    test('انقطاع الاتصال: يبقى الشريط عند نسبته ويقول إنه ينتظر', () {
      final view = UpdateProgressNotification.describe(status(UpdatePhase.waiting, 30 * mb));

      expect(view.body, contains('بانتظار الاتصال بالإنترنت'));
      expect(view.body, contains('30%'));
      expect(view.percent, 30);
      expect(view.indeterminate, isFalse);
    });

    test('التحقق من الملف وحجم غير معروف: شريط متحرك بلا نسبة', () {
      expect(UpdateProgressNotification.describe(status(UpdatePhase.verifying, 100 * mb)).indeterminate, isTrue);
      final unknown = UpdateProgressNotification.describe(status(UpdatePhase.downloading, 5 * mb, total: 0));
      expect(unknown.indeterminate, isTrue);
      expect(unknown.body, contains('5.0 ميغابايت'));
    });

    test('لا مساحة على الجهاز: رسالة واضحة', () {
      expect(UpdateProgressNotification.describe(status(UpdatePhase.noSpace, 10 * mb)).body, contains('مساحة'));
    });
  });

  group('متى يُحدَّث ومتى يختفي', () {
    test('أول نبضة تعرضه، ومئات النبضات في الثانية لا تُغرق النظام', () async {
      for (var i = 0; i < 300; i++) {
        await UpdateProgressNotification.show(status(UpdatePhase.downloading, 10 * mb + i * 1024));
      }

      expect(posted, hasLength(1));
      expect(posted.single!.percent, 10);
    });

    test('تغيّر الطور يُعرض فوراً', () async {
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 10 * mb));
      await UpdateProgressNotification.show(status(UpdatePhase.waiting, 10 * mb));
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 10 * mb));

      expect(posted.map((v) => v!.body.contains('بانتظار')), [false, true, false]);
    });

    test('تقدّم النسبة يُعرض بعد مهلة قصيرة', () async {
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 10 * mb));
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 11 * mb));
      expect(posted, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 750));
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 12 * mb));

      expect(posted, hasLength(2));
      expect(posted.last!.percent, 12);
    });

    test('اكتمال التنزيل يزيل الشريط، وكذلك الإلغاء', () async {
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 99 * mb));
      await UpdateProgressNotification.show(status(UpdatePhase.ready, 100 * mb));
      expect(posted.last, isNull);

      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 5 * mb));
      expect(posted.last, isNotNull);
      await UpdateProgressNotification.clear();
      expect(posted.last, isNull);
    });

    test('بلا مرسل (ويندوز والويب): لا شيء يحدث ولا خطأ', () async {
      UpdateProgressNotification.poster = null;
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 5 * mb));
      await UpdateProgressNotification.clear();
    });

    test('مرسل يرمي خطأ (إذن الإشعارات مرفوض) لا يوقف التنزيل', () async {
      UpdateProgressNotification.poster = (_) async => throw StateError('no permission');
      await UpdateProgressNotification.show(status(UpdatePhase.downloading, 5 * mb));
      await UpdateProgressNotification.clear();
    });
  });
}
