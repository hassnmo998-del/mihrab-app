import 'package:flutter_app/data/datasources/supabase_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات انتظار استرجاع جلسة المصادقة عند الإقلاع.
///
/// الخلل الذي تحرسه: `Supabase.initialize()` لا ينتظر استرجاع الجلسة المحفوظة،
/// فقراءة `currentSession` مباشرة بعده تُرجع null دائماً، وكان التطبيق يفسّر
/// ذلك بأن المشرف العام سجّل خروجه فيمحو علامته المحلية ويطلب الدخول من جديد.
void main() {
  group('SupabaseRemoteDataSource.waitUntil', () {
    test('يعود فوراً إذا كانت الجلسة جاهزة أصلاً', () async {
      final stopwatch = Stopwatch()..start();
      final result = await SupabaseRemoteDataSource.waitUntil(
        () => true,
        timeout: const Duration(seconds: 5),
      );
      stopwatch.stop();

      expect(result, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('ينتظر الجلسة التي تصل متأخرة بدل أن يحكم عليها فوراً', () async {
      // محاكاة الاسترجاع الخلفي: الجلسة تظهر بعد 300 مللي ثانية
      var sessionReady = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        sessionReady = true;
      });

      final result = await SupabaseRemoteDataSource.waitUntil(
        () => sessionReady,
        timeout: const Duration(seconds: 5),
        interval: const Duration(milliseconds: 20),
      );

      expect(result, isTrue, reason: 'كان يجب أن ينتظر ظهور الجلسة');
    });

    test('يستسلم بعد المهلة إن لم تظهر جلسة إطلاقاً', () async {
      final stopwatch = Stopwatch()..start();
      final result = await SupabaseRemoteDataSource.waitUntil(
        () => false,
        timeout: const Duration(milliseconds: 200),
        interval: const Duration(milliseconds: 20),
      );
      stopwatch.stop();

      expect(result, isFalse);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(180));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('لا يعلّق التطبيق: المهلة محترمة حتى مع فحص بطيء التغيّر', () async {
      var checks = 0;
      final result = await SupabaseRemoteDataSource.waitUntil(
        () {
          checks++;
          return false;
        },
        timeout: const Duration(milliseconds: 150),
        interval: const Duration(milliseconds: 30),
      );

      expect(result, isFalse);
      expect(checks, greaterThan(1), reason: 'يجب أن يُعيد الفحص لا مرة واحدة');
    });
  });
}
