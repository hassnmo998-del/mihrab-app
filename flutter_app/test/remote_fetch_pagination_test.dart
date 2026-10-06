import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app/data/datasources/supabase_remote_datasource.dart';

/// جلب جدول من السحابة يعيده **كاملاً**: الخادم يقصّ كل طلب عند حدّه (ألف صف)،
/// والمزامنة تحذف من الجهاز ما ليس في القائمة العائدة.
///
/// خادم محلي يتصرف كـ PostgREST: يرتّب بالمعرّف، يطبّق `id=gt.`، يقصّ عند حدّه، ويعيد
/// العدد الكلي في `Content-Range`.
void main() {
  late _FakePostgrest server;
  late SupabaseClient client;
  late _LocalRemote remote;

  setUp(() async {
    server = _FakePostgrest();
    await server.start();
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    remote = _LocalRemote(client);
  });

  tearDown(() async {
    SupabaseRemoteDataSource.fetchPageSize = 1000;
    await client.dispose();
    await server.stop();
  });

  List<Map<String, dynamic>> rows(int count) => [
        // معرّفات غير مرتبة في التخزين، كما في قاعدة بيانات حقيقية
        for (final i in (List.generate(count, (i) => i)..shuffle()))
          {'id': 'row-${i.toString().padLeft(5, '0')}', 'n': i},
      ];

  test('جدول صغير: طلب واحد كما كان', () async {
    server.tables['students'] = rows(7);

    final result = await remote.fetchTable('students');

    expect(result, hasLength(7));
    expect(server.requests, 1);
  });

  test('جدول فارغ', () async {
    server.tables['students'] = [];
    expect(await remote.fetchTable('students'), isEmpty);
    expect(server.requests, 1);
  });

  test('2500 صف والخادم يقصّ عند 1000: يعود الجدول كله بلا تكرار ولا نقص', () async {
    server.tables['attendance'] = rows(2500);
    server.maxRows = 1000;

    final result = await remote.fetchTable('attendance');

    expect(result, hasLength(2500));
    expect(result!.map((r) => r['id']).toSet(), hasLength(2500));
    expect(server.requests, 3);
  });

  test('حدّ الخادم أصغر من حجم الصفحة المطلوب: لا يُحسب القصّ نهاية الجدول', () async {
    server.tables['points_logs'] = rows(23);
    server.maxRows = 5;

    final result = await remote.fetchTable('points_logs');

    expect(result!.map((r) => r['n']).toSet(), {for (var i = 0; i < 23; i++) i});
  });

  test('عدد الصفوف مضاعف تام لحجم الصفحة', () async {
    server.tables['students'] = rows(30);
    SupabaseRemoteDataSource.fetchPageSize = 10;

    final result = await remote.fetchTable('students');

    expect(result, hasLength(30));
    expect(server.requests, 3);
  });

  test('صف أُضيف أثناء الجلب لا يُسقط صفاً آخر (الصفحات بعد آخر معرّف لا بالإزاحة)', () async {
    server.tables['students'] = rows(20);
    SupabaseRemoteDataSource.fetchPageSize = 10;
    // بعد الصفحة الأولى يُضاف صف يسبق كل ما جُلب: الإزاحة كانت ستكرر صفاً وتُسقط آخر
    server.afterRequest = (n) {
      if (n == 1) server.tables['students']!.add({'id': 'row-!first', 'n': -1});
    };

    final result = await remote.fetchTable('students');

    final ids = result!.map((r) => r['id']).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (var i = 0; i < 20; i++) {
      expect(ids, contains('row-${i.toString().padLeft(5, '0')}'));
    }
  });

  test('صفحة تفشل في المنتصف: لا يعود جزء من الجدول بل لا شيء', () async {
    server.tables['attendance'] = rows(2500);
    server.maxRows = 1000;
    server.failOnRequest = 2;

    expect(await remote.fetchTable('attendance'), isNull);
  });

  test('الخادم لا يردّ: null لا قائمة فارغة', () async {
    await server.stop();
    expect(await remote.fetchTable('students'), isNull);
  });
}

class _LocalRemote extends SupabaseRemoteDataSource {
  final SupabaseClient _client;

  _LocalRemote(this._client);

  @override
  SupabaseClient? get client => _client;
}

class _FakePostgrest {
  HttpServer? _server;
  final Map<String, List<Map<String, dynamic>>> tables = {};

  /// حدّ الخادم لعدد الصفوف في الردّ الواحد (`max-rows`).
  int maxRows = 1000;
  int requests = 0;
  int? failOnRequest;
  void Function(int request)? afterRequest;

  int get port => _server!.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    requests++;
    final number = requests;
    final response = request.response;
    try {
      final table = request.uri.pathSegments.last;
      if (failOnRequest == number) {
        response.statusCode = 503;
        response.write('Service Unavailable');
        return;
      }
      final query = request.uri.queryParameters;
      var data = List<Map<String, dynamic>>.from(tables[table] ?? const []);
      final after = query['id'];
      if (after != null && after.startsWith('gt.')) {
        final bound = after.substring(3);
        data = data.where((r) => (r['id'] as String).compareTo(bound) > 0).toList();
      }
      if ((query['order'] ?? '').startsWith('id')) {
        data.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      }
      final total = data.length;
      final limit = int.tryParse(query['limit'] ?? '') ?? maxRows;
      final page = data.take(limit < maxRows ? limit : maxRows).toList();

      response.headers.contentType = ContentType.json;
      final wantsCount = (request.headers.value('prefer') ?? '').contains('count=exact');
      response.headers.set(
        'content-range',
        '${page.isEmpty ? '*' : '0-${page.length - 1}'}/${wantsCount ? total : '*'}',
      );
      response.statusCode = page.length < total ? 206 : 200;
      response.write(jsonEncode(page));
    } finally {
      await response.close();
      afterRequest?.call(number);
    }
  }
}
