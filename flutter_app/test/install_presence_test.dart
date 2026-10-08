import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/models/install_stats.dart';
import 'package:flutter_app/services/install_presence.dart';

/// عدّ الأجهزة: كل جهاز يُعدّ مرة في يوم الخادم، فتحُه يُسجَّل ولو سبقته إشارة خلفية،
/// ولا يضيع شيء بلا إنترنت. والمعرّف ثابت للجهاز ولا يتكرر.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final validId = RegExp(r'^[0-9a-f]{32}$');

  // خادم مزيّف بيوم دمشق: اليوم يتغير عند منتصف الليل بساعة الاختبار
  late DateTime now;
  late List<Map<String, dynamic>> sent;
  late bool offline;

  DateTime nextMidnight(DateTime t) => DateTime(t.year, t.month, t.day + 1);
  String dayOf(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 8, 17, 50);
    sent = [];
    offline = false;
    InstallPresence.clock = () => now;
    InstallPresence.sender = (body) async {
      if (offline) throw Exception('no network');
      sent.add(body);
      return {'day': dayOf(now), 'seconds_left': nextMidnight(now).difference(now).inSeconds};
    };
  });

  tearDown(InstallPresence.resetForTest);

  Future<bool> open({String version = '1.0.14', String? deviceKey}) => InstallPresence.report(
        opened: true,
        version: () async => version,
        deviceKey: deviceKey == null ? null : () async => deviceKey,
      );

  Future<bool> background({String version = '1.0.14'}) =>
      InstallPresence.report(opened: false, version: () async => version, createId: false);

  group('مرة في اليوم', () {
    test('أول فتح يُرسل المعرّف والمنصة والإصدار، وفتح ثانٍ في اليوم نفسه لا يُرسل', () async {
      expect(await open(), isTrue);
      expect(sent, hasLength(1));
      final body = sent.single;
      expect(body['p_install_id'], matches(validId));
      expect(body['p_platform'], InstallPresence.platformName);
      expect(body['p_version'], '1.0.14');
      expect(body['p_opened'], isTrue);
      // لا شيء آخر يُرسل عن الجهاز أو صاحبه
      expect(body.keys, unorderedEquals(['p_install_id', 'p_platform', 'p_version', 'p_opened']));

      now = now.add(const Duration(hours: 2));
      expect(await open(), isFalse);
      expect(sent, hasLength(1));
    });

    test('بعد منتصف الليل (يوم الخادم) يُرسل من جديد بالمعرّف نفسه', () async {
      await open();
      now = DateTime(2026, 10, 9, 0, 5);
      expect(await open(), isTrue);
      expect(sent, hasLength(2));
      expect(sent[1]['p_install_id'], sent[0]['p_install_id']);
    });

    test('إشارة خلفية ثم فتح في اليوم نفسه: الفتح يُرسل كي يُعدّ «فتحوه اليوم»', () async {
      await open(); // أول فتح بعد التثبيت ينشئ المعرّف
      now = DateTime(2026, 10, 9, 3, 0);
      expect(await background(), isTrue);
      expect(sent.last['p_opened'], isFalse);

      now = DateTime(2026, 10, 9, 9, 0);
      expect(await open(), isTrue);
      expect(sent.last['p_opened'], isTrue);

      // والخلفية بعده لا تُرسل شيئاً: الجهاز عُدّ وفُتح اليوم
      now = DateTime(2026, 10, 9, 15, 0);
      expect(await background(), isFalse);
      expect(sent, hasLength(3));
    });

    test('تحديث التطبيق في منتصف اليوم يُرسل الإصدار الجديد، والفتح المسجَّل يبقى', () async {
      await open(version: '1.0.13');
      now = now.add(const Duration(minutes: 30));
      expect(await background(version: '1.0.14'), isTrue);
      expect(sent.last['p_version'], '1.0.14');

      // الفتح سُجّل اليوم قبل التحديث، فلا حاجة لإشارة أخرى
      now = now.add(const Duration(minutes: 30));
      expect(await open(version: '1.0.14'), isFalse);
    });

    test('بلا إنترنت لا يُعدّ مرسلاً: يُعاد في الفحص التالي', () async {
      offline = true;
      expect(await open(), isFalse);
      expect(sent, isEmpty);

      offline = false;
      now = now.add(const Duration(minutes: 15));
      expect(await open(), isTrue);
      expect(sent, hasLength(1));
    });

    test('ساعة الجهاز رجعت إلى الوراء: يُرسل ولا يبقى صامتاً', () async {
      await open();
      now = now.subtract(const Duration(days: 3));
      expect(await open(), isTrue);
    });

    test('ساعة الجهاز متقدمة يومين: اليوم التالي يُحسب من فرق الخادم لا من تاريخ الجهاز', () async {
      final real = now;
      now = real.add(const Duration(days: 2));
      // الخادم يردّ بيومه هو: بقي 6 ساعات و10 دقائق
      InstallPresence.sender = (body) async {
        sent.add(body);
        return {'day': '2026-10-08', 'seconds_left': 6 * 3600 + 600};
      };
      await open();
      now = now.add(const Duration(hours: 1));
      expect(await open(), isFalse, reason: 'ساعة واحدة من يوم الخادم: لا إشارة ثانية');
      now = now.add(const Duration(hours: 6));
      expect(await open(), isTrue, reason: 'بدأ يوم الخادم التالي');
    });

    test('ردّ غير مفهوم من الخادم: لا يُحفظ شيء ويُعاد لاحقاً', () async {
      InstallPresence.sender = (body) async {
        sent.add(body);
        return {'unexpected': true};
      };
      expect(await open(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(InstallPresence.statePrefsKey), isNull);
    });

    test('حالة محفوظة تالفة تُعامل كأن لا إشارة سابقة', () async {
      SharedPreferences.setMockInitialValues({InstallPresence.statePrefsKey: '{not json'});
      expect(await open(), isTrue);
    });
  });

  group('المعرّف', () {
    test('مهمة الخلفية لا تنشئ معرّفاً: جهاز لم يُفتح بعد هذا الإصدار لا يُعدّ مرتين', () async {
      expect(await background(), isFalse);
      expect(sent, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(InstallPresence.idPrefsKey), isNull);
    });

    test('بلا مفتاح جهاز: رقم عشوائي يُحفظ ويبقى نفسه', () async {
      final prefs = await SharedPreferences.getInstance();
      final a = await InstallPresence.resolveInstallId(prefs);
      final b = await InstallPresence.resolveInstallId(prefs);
      expect(a, matches(validId));
      expect(b, a);

      SharedPreferences.setMockInitialValues({});
      final other = await InstallPresence.resolveInstallId(await SharedPreferences.getInstance());
      expect(other, isNot(a), reason: 'جهازان لا يتشاركان معرّفاً');
    });

    test('أندرويد: بصمة ANDROID_ID لا قيمته، ثابتة، وتغلب المعرّف المنسوخ من هاتف آخر', () async {
      // إعدادات استُعيدت من نسخة احتياطية لهاتف قديم
      SharedPreferences.setMockInitialValues({InstallPresence.idPrefsKey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'});
      final prefs = await SharedPreferences.getInstance();

      final id = await InstallPresence.resolveInstallId(prefs, deviceKey: () async => '9774d56d682e549c');
      final expected = sha256.convert(utf8.encode('mihrab-install:9774d56d682e549c')).toString().substring(0, 32);
      expect(id, expected);
      expect(id, isNot(contains('9774d56d682e549c')));
      // محفوظ لمهمة الخلفية التي لا تصل إلى أندرويد
      expect(prefs.getString(InstallPresence.idPrefsKey), expected);
      expect(await InstallPresence.resolveInstallId(prefs, create: false), expected);

      final other = await InstallPresence.resolveInstallId(prefs, deviceKey: () async => '0f1e2d3c4b5a6978');
      expect(other, isNot(expected));
    });

    test('قناة أندرويد غير متاحة: يرجع إلى المحفوظ ولا يفشل', () async {
      final prefs = await SharedPreferences.getInstance();
      final stored = await InstallPresence.resolveInstallId(prefs);
      final id = await InstallPresence.resolveInstallId(prefs, deviceKey: () async => throw Exception('no channel'));
      expect(id, stored);
    });

    test('معرّف محفوظ بصيغة خاطئة يُستبدل', () async {
      SharedPreferences.setMockInitialValues({InstallPresence.idPrefsKey: 'not-an-id'});
      final id = await InstallPresence.resolveInstallId(await SharedPreferences.getInstance());
      expect(id, matches(validId));
    });

    test('تغيّر المعرّف (أول فتح على هاتف استُعيدت إليه الإعدادات) يُرسل فوراً', () async {
      await open();
      expect(await open(deviceKey: 'abc123'), isTrue);
      expect(sent, hasLength(2));
      expect(sent[1]['p_install_id'], isNot(sent[0]['p_install_id']));
    });
  });

  group('جلب الأرقام بكلمة السر', () {
    test('كلمة السر تُرسل بأحرف صغيرة بلا مسافات ولا شرطات', () async {
      Map<String, dynamic>? body;
      InstallPresence.statsRequester = (b) async {
        body = b;
        return {'error': 'wrong_secret'};
      };
      await expectLater(InstallPresence.fetchStats(' AbCd-eFgH ijkl–MNOP '), throwsA(isA<InstallStatsException>()));
      expect(body, {'p_secret': 'abcdefghijklmnop'});
    });

    Future<InstallStatsError?> errorOf(Future<Map<String, dynamic>> Function() reply) async {
      InstallPresence.statsRequester = (_) => reply();
      try {
        await InstallPresence.fetchStats('x');
        return null;
      } on InstallStatsException catch (e) {
        return e.error;
      }
    }

    test('ردود الخادم: خطأ كلمة السر، كثرة المحاولات، وما سواها تعذّر', () async {
      expect(await errorOf(() async => {'error': 'wrong_secret'}), InstallStatsError.wrongSecret);
      expect(await errorOf(() async => {'error': 'too_many_attempts'}), InstallStatsError.tooManyAttempts);
      expect(await errorOf(() async => {'error': 'something_new'}), InstallStatsError.unavailable);
      expect(await errorOf(() async => throw Exception('no network')), InstallStatsError.unavailable);
      expect(await errorOf(() async => {'today': 'not a date', 'daily': 'oops'}), InstallStatsError.unavailable);
    });

    test('ردّ سليم يُقرأ أرقاماً', () async {
      InstallPresence.statsRequester = (_) async => {
            'today': '2026-10-08',
            'counting_since': '2026-10-08T14:52:31+00:00',
            'installed': 3,
            'total': 3,
            'opened_today': 2,
            'opened_7d': 3,
            'new_7d': 3,
            'by_platform': [
              {'key': 'android', 'count': 3},
            ],
            'by_version': [
              {'key': '1.0.15', 'count': 3},
            ],
            'daily': [
              {'day': '2026-10-08', 'seen': 3, 'opened': 2},
            ],
          };
      final s = await InstallPresence.fetchStats('anything');
      expect(s.installed, 3);
      expect(s.byPlatform.single.key, 'android');
    });
  });

  group('قراءة الأرقام', () {
    test('تُقرأ كما يعيدها app_install_stats', () {
      final json = jsonDecode('''
        {"daily":[{"day":"2026-10-07","seen":0,"opened":0},{"day":"2026-10-08","seen":4,"opened":3}],
         "today":"2026-10-08","total":4,"new_7d":4,"installed":4,"opened_7d":3,
         "by_version":[{"key":"1.0.14","count":2},{"key":"1.0.13","count":1},{"key":"","count":1}],
         "by_platform":[{"key":"android","count":2},{"key":"ios","count":1},{"key":"windows","count":1}],
         "opened_today":3,"counting_since":"2026-10-08T14:52:31.753063+00:00"}
      ''') as Map<String, dynamic>;
      final s = InstallStats.fromJson(json);
      expect(s.installed, 4);
      expect(s.total, 4);
      expect(s.openedToday, 3);
      expect(s.opened7d, 3);
      expect(s.new7d, 4);
      expect(s.today, DateTime(2026, 10, 8));
      expect(s.countingSince, DateTime.utc(2026, 10, 8, 14, 52, 31, 753, 63).toLocal());
      expect([for (final p in s.byPlatform) InstallStats.platformLabel(p.key)], ['أندرويد', 'آيفون', 'ويندوز']);
      expect(s.byVersion.map((v) => v.key), ['1.0.14', '1.0.13', '']);
      expect(s.daily.last.day, DateTime(2026, 10, 8));
      expect(s.daily.last.opened, 3);
    });

    test('بلا أي جهاز بعد', () {
      final s = InstallStats.fromJson({
        'today': '2026-10-08',
        'counting_since': null,
        'installed': 0,
        'total': 0,
        'opened_today': 0,
        'opened_7d': 0,
        'new_7d': 0,
        'by_platform': [],
        'by_version': [],
        'daily': [],
      });
      expect(s.total, 0);
      expect(s.countingSince, isNull);
      expect(s.byPlatform, isEmpty);
    });
  });
}
