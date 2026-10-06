import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/library_books_data.dart';
import 'package:flutter_app/data/library_cloud_seed.dart';
import 'package:flutter_app/models/book_content.dart';
import 'package:flutter_app/models/library_book.dart';
import 'package:flutter_app/services/library/book_content_repository.dart';
import 'package:flutter_app/services/library/library_content_store.dart';
import 'package:flutter_app/services/library_service.dart';

/// كتاب سحابي صغير: 5 صفحات في جزأين.
const _base = 'https://example.test/books/v2/demo/3';
final _index = {
  'format': 2,
  'id': 'demo',
  'rev': 3,
  'pages': 5,
  'chunks': [1, 4],
  'printPages': [7, 8, 8, 9, 1],
  'volumes': [
    {'name': 'المقدمة', 'from': 1},
    {'name': '1', 'from': 5},
  ],
  'toc': [
    [1, 1, 'المقدمة'],
    [2, 3, 'فصل'],
    [1, 5, 'الباب الأول'],
  ],
  'edition': 'الكتاب: تجريبي',
};
final _chunks = {
  0: {
    'from': 1,
    'pages': [
      {'t': 'أولى', 'f': '(١) حاشية'},
      {'t': 'ثانية'},
      {'t': '## فصل\nثالثة (^١)'},
    ],
  },
  1: {
    'from': 4,
    'pages': [
      {'t': 'رابعة'},
      {'t': 'خامسة'},
    ],
  },
};

const _demoBook = LibraryBook(
  id: 'demo',
  title: 'كتاب تجريبي',
  shortTitle: 'تجريبي',
  author: 'مؤلف',
  category: 'fiqh',
  categoryName: 'الفقه',
  description: 'وصف',
  isBuiltIn: false,
  contentUrl: '$_base/index.json',
  contentFormat: 2,
  contentRev: 3,
);

http.Response _json(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// ينتظر انتهاء المزامنة التي يبدؤها init في الخلفية.
Future<void> _settle(LibraryService service) async {
  do {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  } while (service.isLoadingRemote);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LibraryService().debugReset();
  });

  group('فهرس المكتبة', () {
    test('المضمّن والسحابي معاً يغطيان كل التصنيفات', () {
      expect(kLocalLibraryBooks, isNotEmpty);
      expect(kCloudSeedLibraryBooks.length, greaterThanOrEqualTo(20));

      final categories = kDefaultLibraryBooks.map((b) => b.category).toSet();
      expect(categories, containsAll(['hadith', 'tafsir', 'seerah', 'tazkiyah']));
    });

    test('لا يتكرر معرّف، وكل كتاب بياناته كاملة', () {
      final ids = kDefaultLibraryBooks.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final book in kDefaultLibraryBooks) {
        expect(book.title, isNotEmpty, reason: book.id);
        expect(book.shortTitle, isNotEmpty, reason: book.id);
        expect(book.author, isNotEmpty, reason: book.id);
        expect(book.description, isNotEmpty, reason: book.id);
        expect(book.totalPages, greaterThan(0), reason: book.id);
        // غلاف بلا قناة ألفا يُرسم شفافاً
        expect(book.coverColor >> 24, 0xFF, reason: book.id);
      }
    });

    test('كل كتاب سحابي في البذرة يشير إلى فهرس مراجعته', () {
      for (final book in kCloudSeedLibraryBooks) {
        expect(book.isCloud, isTrue, reason: book.id);
        expect(book.isBuiltIn, isFalse, reason: book.id);
        expect(
          book.contentUrl,
          endsWith('/v2/${book.id}/${book.contentRev}/index.json'),
          reason: book.id,
        );
      }
    });

    test('صف Supabase (snake_case) يُقرأ بكل حقوله', () {
      final book = LibraryBook.fromJson({
        'id': 'x',
        'title': 'عنوان طويل',
        'short_title': 'قصير',
        'author': 'مؤلف',
        'category': 'fiqh',
        'category_name': 'الفقه والأحكام',
        'description': 'وصف',
        'cover_color': 1786674, // 0x1B4332 بلا ألفا
        'total_pages': 640,
        'chapters_count': 103,
        'file_size': '1.3 ميغابايت',
        'content_url': 'https://h/v2/x/4/index.json',
        'content_format': 2,
        'content_rev': 4,
        'sort_order': 420,
        'is_built_in': false,
      });
      expect(book.shortTitle, 'قصير');
      expect(book.categoryName, 'الفقه والأحكام');
      expect(book.coverColor, 0xFF1B4332);
      expect(book.totalPages, 640);
      expect(book.contentRev, 4);
      expect(book.sortOrder, 420);
      expect(book.isCloud, isTrue);
    });

    test('LibraryService يعرض المضمّن أولاً ثم السحابي مرتباً', () async {
      final service = LibraryService();
      await service.init();

      expect(service.isInitialized, isTrue);
      final ids = service.books.map((b) => b.id).toList();
      expect(ids.take(kLocalLibraryBooks.length), kLocalLibraryBooks.map((b) => b.id));

      final cloud = service.books.skip(kLocalLibraryBooks.length).toList();
      expect(cloud.length, kCloudSeedLibraryBooks.length);
      for (var i = 1; i < cloud.length; i++) {
        expect(cloud[i].sortOrder, greaterThanOrEqualTo(cloud[i - 1].sortOrder));
      }
    });
  });

  // كتاب يُضاف في Supabase يجب أن يصل إلى التطبيق بالمزامنة وحدها، بلا إصدار.
  group('مزامنة الفهرس', () {
    Map<String, dynamic> row(
      String id, {
      int rev = 1,
      bool published = true,
      String category = 'tazkiyah',
      String categoryName = 'التزكية والرقائق',
      String updatedAt = '2026-10-02T12:00:00.000000+00:00',
    }) =>
        {
          'id': id,
          'title': 'كتاب $id',
          'short_title': 'كتاب $id',
          'author': 'مؤلف',
          'category': category,
          'category_name': categoryName,
          'description': 'وصف',
          'cover_color': 0xFF1B4332,
          'total_pages': 100,
          'chapters_count': 10,
          'file_size': '1 ميغابايت',
          'content_url': 'https://h/books/v2/$id/$rev/index.json',
          'content_format': 2,
          'content_rev': rev,
          'sort_order': 5000,
          'is_published': published,
          'updated_at': updatedAt,
        };

    /// كل كتب البذرة كما هي في الجدول، ليُضاف فوقها ما يختبره كل اختبار.
    List<Map<String, dynamic>> seedRows() => [
          for (final b in kCloudSeedLibraryBooks)
            row(b.id, rev: b.contentRev, category: b.category, categoryName: b.categoryName),
        ];

    Future<LibraryService> syncedWith(
      List<Map<String, dynamic>> Function() table, {
      List<String?>? sinceLog,
    }) async {
      final service = LibraryService()
        ..debugReset(
          catalogFetcher: ({required since, required offset, required limit}) async {
            sinceLog?.add(since);
            final rows = table().where((r) {
              return since == null ||
                  DateTime.parse(r['updated_at'] as String).isAfter(DateTime.parse(since));
            }).toList();
            return rows.skip(offset).take(limit).toList();
          },
        );
      await service.init();
      await _settle(service);
      return service;
    }

    test('كتاب جديد في الجدول يظهر في المكتبة بعد المزامنة', () async {
      final service = await syncedWith(() => [...seedRows(), row('new_book')]);

      final added = service.bookById('new_book');
      expect(added, isNotNull);
      expect(added!.isCloud, isTrue);
      expect(added.contentUrl, 'https://h/books/v2/new_book/1/index.json');
      expect(service.books.length, kDefaultLibraryBooks.length + 1);
    });

    test('تصنيف جديد يظهر في قائمة التصنيفات بعدد كتبه', () async {
      final service = await syncedWith(() => [
            ...seedRows(),
            row('lang_1', category: 'lugha', categoryName: 'اللغة والأدب'),
            row('lang_2', category: 'lugha', categoryName: 'اللغة والأدب'),
          ]);

      final lugha = service.categories.where((c) => c.id == 'lugha').single;
      expect(lugha.name, 'اللغة والأدب');
      expect(lugha.count, 2);
      // التصنيفات المعروفة تبقى بترتيبها، والحديث أولها
      expect(service.categories.first.id, 'hadith');
    });

    test('إعادة استيراد كتاب ترفع مراجعته فيتبعها التطبيق', () async {
      final seeded = kCloudSeedLibraryBooks.first;
      final service = await syncedWith(() => [
            for (final r in seedRows())
              if (r['id'] == seeded.id) row(seeded.id, rev: seeded.contentRev + 1) else r,
          ]);

      final book = service.bookById(seeded.id)!;
      expect(book.contentRev, seeded.contentRev + 1);
      expect(book.contentUrl, endsWith('/${seeded.id}/${seeded.contentRev + 1}/index.json'));
    });

    test('كتاب أُلغي نشره يختفي ولو كان في نسخة الفهرس المضمّنة', () async {
      final seeded = kCloudSeedLibraryBooks.first;
      final service = await syncedWith(() => [
            for (final r in seedRows())
              if (r['id'] == seeded.id) row(seeded.id, published: false) else r,
          ]);

      expect(service.bookById(seeded.id), isNull);
      expect(service.books.length, kDefaultLibraryBooks.length - 1);
    });

    test('الكتب المضمّنة لا تستبدلها السحابة ولو حمل صفٌّ معرّفها', () async {
      final service = await syncedWith(() => [...seedRows(), row('sahih_bukhari')]);

      final bukhari = service.bookById('sahih_bukhari')!;
      expect(bukhari.isCloud, isFalse);
      expect(bukhari.isInteractiveHadith, isTrue);
    });

    test('المزامنة الأولى كاملة، وما بعدها يطلب ما تغيّر فقط', () async {
      final table = seedRows();
      final sinceLog = <String?>[];
      final service = await syncedWith(() => table, sinceLog: sinceLog);
      expect(sinceLog, [null]);

      table.add(row('later_book', updatedAt: '2026-10-03T08:00:00.000000+00:00'));
      await service.syncWithSupabase();

      expect(sinceLog.last, isNotNull);
      expect(service.bookById('later_book'), isNotNull);
      // ما لم يتغيّر لم يُطلب من جديد، وبقي في مكانه
      expect(service.books.length, kDefaultLibraryBooks.length + 1);
    });

    test('فتح المكتبة لا يكرر المزامنة قبل مضي المهلة', () async {
      final sinceLog = <String?>[];
      final service = await syncedWith(seedRows, sinceLog: sinceLog);
      expect(sinceLog.length, 1);

      service.refreshIfStale();
      await _settle(service);
      expect(sinceLog.length, 1);
    });

    test('تعذّر الاتصال يبقي الفهرس كما هو', () async {
      final service = LibraryService()
        ..debugReset(
          catalogFetcher: ({required since, required offset, required limit}) async =>
              throw const SocketException('offline'),
        );
      await service.init();
      await _settle(service);

      expect(service.books.length, kDefaultLibraryBooks.length);
      expect(service.isLoadingRemote, isFalse);
    });
  });

  group('حالة القارئ', () {
    test('موضع القراءة ونسبة التقدم', () async {
      final service = LibraryService();
      await service.init();

      const bookId = 'riyad_salihin';
      expect(service.getLastReadPage(bookId), 1);

      await service.saveLastReadPage(bookId, 25);
      expect(service.getLastReadPage(bookId), 25);
      expect(service.getLastReadDate(bookId), isNotNull);
      expect(service.getProgress(bookId, 100), 0.25);
    });

    test('موضع القراءة يبقى بعد إعادة التشغيل', () async {
      final service = LibraryService();
      await service.init();
      await service.saveLastReadPage('zad_maad', 1200);
      await service.flushProgress();

      service.debugReset();
      await service.init();
      expect(service.getLastReadPage('zad_maad'), 1200);
    });

    test('المفضلة', () async {
      final service = LibraryService();
      await service.init();

      const bookId = 'arbaeen_nawawi';
      expect(service.isFavorite(bookId), isFalse);
      await service.toggleFavorite(bookId);
      expect(service.isFavorite(bookId), isTrue);
      await service.toggleFavorite(bookId);
      expect(service.isFavorite(bookId), isFalse);
    });

    test('علامات الصفحات', () async {
      final service = LibraryService();
      await service.init();

      const bookId = 'tafsir_muyassar';
      expect(service.isPageBookmarked(bookId, 5), isFalse);
      await service.toggleBookmark(bookId, 5);
      expect(service.getBookmarks(bookId), contains(5));
      await service.toggleBookmark(bookId, 5);
      expect(service.isPageBookmarked(bookId, 5), isFalse);
    });

    test('المضمّن حاضر دائماً، والسحابي غير منزّل حتى يُنزَّل', () async {
      final service = LibraryService();
      await service.init();
      expect(service.isDownloaded('sahih_bukhari'), isTrue);
      expect(service.isDownloaded('zad_maad'), isFalse);
    });
  });

  group('BookIndex', () {
    final index = BookIndex.fromJson(_index);

    test('يحدد الجزء الذي فيه كل صفحة', () {
      expect([for (var p = 1; p <= 5; p++) index.chunkOf(p)], [0, 0, 0, 1, 1]);
      expect(index.chunkLength(0), 3);
      expect(index.chunkLength(1), 2);
    });

    test('رقم المطبوع والمجلد', () {
      expect(index.printLabel(1), 'المقدمة · ص 7');
      // مجلد مرقّم واحد: لا حاجة لذكر رقم الجزء
      expect(index.printLabel(5), 'ص 1');
      // الصفحة 3 تكملة للصفحة الورقية 8 نفسها
      expect(index.startsPrintPage(2), isTrue);
      expect(index.startsPrintPage(3), isFalse);
      // رقم المطبوع يعود إلى 1 مع مجلد جديد
      expect(index.startsPrintPage(5), isTrue);
    });

    test('العنوان الذي تقع تحته الصفحة', () {
      expect(index.headingAt(2)?.title, 'المقدمة');
      expect(index.headingAt(4)?.title, 'فصل');
      expect(index.headingAt(5)?.title, 'الباب الأول');
    });

    test('فهرس بلا أجزاء مرفوض', () {
      expect(() => BookIndex.fromJson({'pages': 3, 'chunks': []}), throwsFormatException);
    });
  });

  test('النص المنسوخ يخلو من علامات التنسيق الداخلية', () {
    const unit = BookUnit(text: '## فصل\nنص (^١) هنا\n* * *\nبعده');
    expect(unit.plainText, 'فصل\nنص (١) هنا\nبعده');
  });

  group('BookContentRepository', () {
    late Directory temp;
    late List<String> requests;
    late Map<String, http.Response Function()> routes;

    BookContentRepository repository() => BookContentRepository(
          store: LibraryContentStore(rootOverride: temp.path),
          client: MockClient((request) async {
            requests.add(request.url.toString());
            final route = routes[request.url.toString()];
            return route == null ? http.Response('not found', 404) : route();
          }),
        );

    setUp(() {
      temp = Directory.systemTemp.createTempSync('mihrab_library_test');
      requests = [];
      routes = {
        '$_base/index.json': () => _json(_index),
        '$_base/c0.json': () => _json(_chunks[0]!),
        '$_base/c1.json': () => _json(_chunks[1]!),
      };
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('يفتح بالفهرس وحده ثم يجلب الجزء المطلوب فقط', () async {
      final content = await repository().open(_demoBook);
      expect(content.index.pageCount, 5);
      expect(requests, ['$_base/index.json']);
      expect(content.peek(4), isNull);

      final page = await content.load(4);
      expect(page.text, 'رابعة');
      expect(requests, ['$_base/index.json', '$_base/c1.json']);
      // باقي صفحات الجزء حاضرة بلا طلب جديد
      expect(content.peek(5)?.text, 'خامسة');
      expect(content.peek(1), isNull);
    });

    test('الحواشي والعناوين تصل كما هي', () async {
      final content = await repository().open(_demoBook);
      expect((await content.load(1)).notes, '(١) حاشية');
      expect((await content.load(3)).text, startsWith(BookUnit.headingMark));
    });

    test('ما قُرئ مرة يُفتح بعدها بلا شبكة', () async {
      final online = await repository().open(_demoBook);
      await online.load(1);

      routes.clear();
      requests.clear();
      final offline = await repository().open(_demoBook);
      expect((await offline.load(2)).text, 'ثانية');
      expect(requests, isEmpty);
      // الجزء الذي لم يُقرأ قط غير متاح بلا شبكة
      await expectLater(offline.load(4), throwsA(isA<BookUnavailableException>()));
    });

    test('التنزيل يجلب كل الأجزاء فيُقرأ الكتاب كاملاً بلا شبكة', () async {
      final progress = <String>[];
      await repository().download(_demoBook, onProgress: (done, total) => progress.add('$done/$total'));
      expect(progress.last, '2/2');

      routes.clear();
      final offline = await repository().open(_demoBook);
      expect((await offline.load(1)).text, 'أولى');
      expect((await offline.load(5)).text, 'خامسة');
    });

    test('خطأ عابر في الشبكة يُعاد بعده الطلب', () async {
      var calls = 0;
      routes['$_base/c0.json'] = () => ++calls < 2 ? http.Response('busy', 503) : _json(_chunks[0]!);
      final content = await repository().open(_demoBook);
      expect((await content.load(1)).text, 'أولى');
      expect(calls, 2);
    });

    test('جزء لا يطابق الفهرس مرفوض ولا يُحفظ', () async {
      routes['$_base/c1.json'] = () => _json({
            'from': 4,
            'pages': [
              {'t': 'رابعة'},
            ],
          });
      final content = await repository().open(_demoBook);
      await expectLater(content.load(4), throwsA(isA<BookUnavailableException>()));

      // بعد إصلاح الملف على الخادم يُجلب سليماً: التالف لم يُخزَّن
      routes['$_base/c1.json'] = () => _json(_chunks[1]!);
      expect((await content.load(4)).text, 'رابعة');
    });

    test('بلا شبكة وبلا نسخة محفوظة: خطأ واضح', () async {
      routes.clear();
      await expectLater(repository().open(_demoBook), throwsA(isA<BookUnavailableException>()));
    });

    test('مراجعة جديدة بلا شبكة: تُفتح المراجعة المنزّلة الأقدم', () async {
      await repository().download(_demoBook);
      routes.clear();

      final bumped = _demoBook.copyWith(
        contentRev: 4,
        contentUrl: 'https://example.test/books/v2/demo/4/index.json',
      );
      final content = await repository().open(bumped);
      expect(content.rev, 3);
      expect((await content.load(5)).text, 'خامسة');
    });
  });

  test('الكتاب المضمّن يُحوَّل إلى صفحات بفهرس عناوين', () {
    final content = LocalBookContent.fromPages(const [
      BookPage(pageNumber: 1, title: 'سورة الفاتحة', section: 'جزء 1', content: 'تفسير', footnote: 'مصدر'),
      BookPage(pageNumber: 2, title: 'سورة البقرة', section: 'جزء 1', content: 'تفسير'),
    ]);
    expect(content.index.pageCount, 2);
    expect(content.peek(1)?.text, '## سورة الفاتحة\nتفسير');
    expect(content.peek(1)?.notes, 'مصدر');
    expect(content.index.toc.map((e) => e.title), ['جزء 1', 'سورة الفاتحة', 'سورة البقرة']);
    expect(content.peek(3), isNull);
  });
}
