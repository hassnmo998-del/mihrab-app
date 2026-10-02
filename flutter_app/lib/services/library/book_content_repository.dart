import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/book_content.dart';
import '../../models/library_book.dart';
import 'library_content_store.dart';

/// تعذّر فتح الكتاب: لا شبكة ولا نسخة محفوظة على الجهاز.
class BookUnavailableException implements Exception {
  final String message;
  const BookUnavailableException(this.message);

  @override
  String toString() => message;
}

/// محتوى كتاب مفتوح: فهرسه حاضر، وصفحاته تُحمَّل عند الطلب.
abstract class BookContent {
  BookIndex get index;

  /// الصفحة إن كانت في الذاكرة، وإلا null (اطلبها بـ [load]).
  BookUnit? peek(int page);

  Future<BookUnit> load(int page);

  /// يحمّل مسبقاً ما حول [page] ليصل القارئ إليه وهو جاهز.
  void warm(int page);
}

/// كتاب مضمَّن في التطبيق: كل صفحاته في الذاكرة.
class LocalBookContent implements BookContent {
  LocalBookContent._(this.index, this._units);

  @override
  final BookIndex index;
  final List<BookUnit> _units;

  factory LocalBookContent.fromPages(List<BookPage> pages) {
    final toc = <BookTocEntry>[];
    String? lastSection;
    final units = <BookUnit>[];
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      final section = p.section ?? '';
      if (section.isNotEmpty && section != lastSection) {
        toc.add(BookTocEntry(level: 1, page: i + 1, title: section));
        lastSection = section;
      }
      toc.add(BookTocEntry(level: section.isEmpty ? 1 : 2, page: i + 1, title: p.title));
      units.add(BookUnit(
        text: '${BookUnit.headingMark}${p.title}\n${p.content}',
        notes: p.footnote,
      ));
    }
    return LocalBookContent._(
      BookIndex(
        rev: 0,
        pageCount: units.length,
        chunkStarts: const [1],
        printPages: const [],
        volumes: const [],
        toc: toc,
      ),
      units,
    );
  }

  @override
  BookUnit? peek(int page) => page >= 1 && page <= _units.length ? _units[page - 1] : null;

  @override
  Future<BookUnit> load(int page) async => _units[page - 1];

  @override
  void warm(int page) {}
}

/// كتاب سحابي: يُحمَّل جزءاً جزءاً، وكل جزء يصل يُحفظ على الجهاز.
class CloudBookContent implements BookContent {
  CloudBookContent._(this._repository, this.bookId, this.rev, this.baseUrl, this.index);

  static const int _maxChunksInMemory = 16;

  final BookContentRepository _repository;
  final String bookId;
  final int rev;
  final String baseUrl;

  @override
  final BookIndex index;

  final LinkedHashMap<int, List<BookUnit>> _chunks = LinkedHashMap();
  final Map<int, Future<List<BookUnit>>> _pending = {};

  @override
  BookUnit? peek(int page) {
    if (page < 1 || page > index.pageCount) return null;
    final chunk = index.chunkOf(page);
    final units = _chunks.remove(chunk);
    if (units == null) return null;
    _chunks[chunk] = units; // الأحدث استعمالاً في آخر القائمة
    return units[page - index.chunkStarts[chunk]];
  }

  @override
  Future<BookUnit> load(int page) async {
    final chunk = index.chunkOf(page);
    final units = await loadChunk(chunk);
    return units[page - index.chunkStarts[chunk]];
  }

  @override
  void warm(int page) {
    final chunk = index.chunkOf(page.clamp(1, index.pageCount));
    for (final c in [chunk, chunk + 1, chunk - 1]) {
      if (c < 0 || c >= index.chunkCount || _chunks.containsKey(c)) continue;
      loadChunk(c).then((_) {}, onError: (_) {});
    }
  }

  Future<List<BookUnit>> loadChunk(int chunk) {
    final cached = _chunks[chunk];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(chunk, () async {
      try {
        final units = await _repository._chunk(this, chunk);
        _chunks[chunk] = units;
        while (_chunks.length > _maxChunksInMemory) {
          _chunks.remove(_chunks.keys.first);
        }
        return units;
      } finally {
        _pending.remove(chunk);
      }
    });
  }
}

/// يجلب فهارس الكتب وأجزاءها من Supabase Storage.
///
/// ترتيب المصادر لكل ملف: الذاكرة، ثم الجهاز، ثم الشبكة (بإعادة محاولة).
/// الملف الذي يصل من الشبكة يُتحقق من سلامته قبل حفظه، والتالف على الجهاز
/// يُحذف ويُجلب من جديد.
class BookContentRepository {
  BookContentRepository({LibraryContentStore? store, http.Client? client})
      : store = store ?? LibraryContentStore(),
        _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 25);
  static const int _attempts = 3;

  final LibraryContentStore store;
  final http.Client _client;

  static String _dir(String bookId, int rev) => '$bookId/r$rev';

  /// يفتح الكتاب السحابي. إن تعذّرت المراجعة الحالية (لا شبكة) وعلى الجهاز
  /// مراجعة أقدم، تُفتح الأقدم بدل أن يفشل الفتح.
  Future<CloudBookContent> open(LibraryBook book) async {
    final url = book.contentUrl;
    if (!book.isCloud || url == null) {
      throw const BookUnavailableException('هذا الكتاب ليس له محتوى سحابي.');
    }
    final base = url.substring(0, url.lastIndexOf('/'));
    try {
      final content = await _openRev(book.id, book.contentRev, base);
      _dropOtherRevs(book.id, book.contentRev);
      return content;
    } catch (e) {
      debugPrint('ℹ️ Book ${book.id} r${book.contentRev} unavailable: $e');
      final revsRoot = base.substring(0, base.lastIndexOf('/'));
      final older = (await store.listDirs(book.id))
          .map((name) => int.tryParse(name.replaceFirst('r', '')))
          .whereType<int>()
          .where((rev) => rev != book.contentRev)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      for (final rev in older) {
        try {
          return await _openRev(book.id, rev, '$revsRoot/$rev', diskOnly: true);
        } catch (_) {}
      }
      throw const BookUnavailableException(
        'تعذّر تحميل الكتاب. تحقق من اتصالك بالإنترنت ثم أعد المحاولة.',
      );
    }
  }

  Future<CloudBookContent> _openRev(String bookId, int rev, String base, {bool diskOnly = false}) async {
    final index = await _fetch<BookIndex>(
      path: '${_dir(bookId, rev)}/index.json',
      url: '$base/index.json',
      diskOnly: diskOnly,
      parse: (raw) => BookIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    );
    return CloudBookContent._(this, bookId, rev, base, index);
  }

  void _dropOtherRevs(String bookId, int keepRev) {
    store.listDirs(bookId).then((names) {
      for (final name in names) {
        if (name != 'r$keepRev') store.deleteDir('$bookId/$name');
      }
    }, onError: (_) {});
  }

  Future<List<BookUnit>> _chunk(CloudBookContent content, int chunk) {
    final expectedFrom = content.index.chunkStarts[chunk];
    final expectedLength = content.index.chunkLength(chunk);
    return _fetch<List<BookUnit>>(
      path: '${_dir(content.bookId, content.rev)}/c$chunk.json',
      url: '${content.baseUrl}/c$chunk.json',
      parse: (raw) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final pages = json['pages'] as List;
        if ((json['from'] as num).toInt() != expectedFrom || pages.length != expectedLength) {
          throw const FormatException('جزء لا يطابق الفهرس');
        }
        return [
          for (final p in pages)
            BookUnit(text: (p as Map)['t'] as String? ?? '', notes: p['f'] as String?),
        ];
      },
    );
  }

  /// ينزّل كل أجزاء الكتاب إلى الجهاز للقراءة بلا إنترنت.
  Future<void> download(
    LibraryBook book, {
    void Function(int done, int total)? onProgress,
  }) async {
    final content = await open(book);
    final total = content.index.chunkCount;
    var done = 0;
    var next = 0;
    onProgress?.call(0, total);

    Future<void> worker() async {
      while (next < total) {
        final chunk = next++;
        await _chunk(content, chunk);
        onProgress?.call(++done, total);
      }
    }

    await Future.wait([for (var i = 0; i < 3; i++) worker()]);
  }

  Future<void> removeFromDevice(String bookId) => store.deleteDir(bookId);

  Future<T> _fetch<T>({
    required String path,
    required String url,
    required T Function(String raw) parse,
    bool diskOnly = false,
  }) async {
    final onDisk = await store.read(path);
    if (onDisk != null) {
      try {
        return parse(onDisk);
      } catch (_) {
        await store.delete(path);
      }
    }
    if (diskOnly) throw const BookUnavailableException('غير محفوظ على الجهاز');

    Object? lastError;
    for (var attempt = 0; attempt < _attempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
      try {
        final res = await _client.get(Uri.parse(url)).timeout(_timeout);
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          // ملف غير موجود لن يظهر بإعادة المحاولة
          if (res.statusCode == 400 || res.statusCode == 404) break;
          continue;
        }
        final raw = utf8.decode(res.bodyBytes);
        final parsed = parse(raw);
        await store.write(path, raw);
        return parsed;
      } catch (e) {
        lastError = e;
      }
    }
    throw BookUnavailableException('تعذّر تحميل $url: $lastError');
  }
}
