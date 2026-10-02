import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/library_books_data.dart';
import '../data/library_cloud_seed.dart';
import '../models/book_content.dart';
import '../models/library_book.dart';
import 'library/book_content_repository.dart';
import 'library/library_content_store.dart';
import 'library/local_book_pages.dart';

export 'library/book_content_repository.dart' show BookContent, BookUnavailableException;

/// يجلب صفحة من صفوف `library_books` التي تغيّرت بعد [since] (أو كلها إن كان null)،
/// مرتبة بـ updated_at ثم id.
typedef LibraryCatalogFetcher = Future<List<Map<String, dynamic>>> Function({
  required String? since,
  required int offset,
  required int limit,
});

/// تصنيف في المكتبة كما يظهر في الفهرس الحالي.
typedef LibraryCategory = ({String id, String name, int count});

/// المكتبة الشاملة: فهرس الكتب، مزامنته مع Supabase، وحالة القارئ
/// (موضع القراءة، المفضلة، التنزيلات، العلامات).
///
/// الفهرس يتكوّن من ثلاث طبقات، كل واحدة تغلب ما قبلها:
///  1. الكتب المضمّنة في التطبيق ([kLocalLibraryBooks]) — لا تمسّها السحابة.
///  2. نسخة مضمّنة من فهرس السحابة ([kCloudSeedLibraryBooks]).
///  3. ما وصل من جدول `library_books`، محفوظاً على الجهاز بين التشغيلات.
///
/// نصوص الكتب السحابية لا تُحمَّل هنا؛ يفتحها [openContent] جزءاً جزءاً.
class LibraryService extends ChangeNotifier {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  LibraryService._internal();

  static const _progressKey = 'lib2_progress';
  static const _favoritesKey = 'lib2_favorites';
  static const _downloadsKey = 'lib2_downloads';
  static const _bookmarksKey = 'lib2_bookmarks';
  static const _catalogKey = 'lib2_catalog';
  static const _catalogFile = 'catalog.json';

  /// أعمدة الفهرس فقط؛ لا نص ولا فهرس عناوين.
  static const _catalogColumns =
      'id,title,short_title,author,category,category_name,description,cover_color,'
      'total_pages,chapters_count,file_size,content_url,content_format,content_rev,'
      'sort_order,is_published,updated_at';
  static const _syncPageSize = 1000;

  /// مزامنة كاملة كل أسبوع تلتقط ما حُذف من الجدول حذفاً نهائياً.
  static const _fullSyncEvery = Duration(days: 7);

  /// هامش يعيد قراءة آخر دقيقتين: صف التزم بعد قراءتنا بطابع زمني أقدم.
  static const _syncOverlap = Duration(minutes: 2);

  /// فتح تبويب المكتبة يزامن إن مضى هذا على آخر محاولة؛ كتاب أُضيف للتو يظهر
  /// بلا إعادة تشغيل للتطبيق.
  static const _staleAfter = Duration(minutes: 5);

  /// ترتيب التصنيفات المعروفة في الواجهة؛ ما عداها يتبعها حسب عدد كتبه.
  static const _categoryOrder = [
    'hadith', 'tafsir', 'seerah', 'aqeedah', 'fiqh', 'usul', 'tazkiyah', 'tarikh', 'lugha', 'general',
  ];

  BookContentRepository _repository = BookContentRepository();
  LibraryContentStore get _store => _repository.store;
  LibraryCatalogFetcher _fetchCatalog = _fetchCatalogFromSupabase;

  List<LibraryBook> _books = [];
  List<LibraryBook> _booksView = const [];
  Map<String, LibraryBook> _byId = {};
  List<LibraryCategory> _categories = const [];
  DateTime? _lastSyncAttempt;
  final Map<String, LibraryBook> _remote = {};
  final Set<String> _hidden = {};
  String? _syncedAt;
  DateTime? _fullSyncAt;

  final Map<String, int> _lastReadPages = {};
  final Map<String, DateTime> _lastReadDates = {};
  final Set<String> _favoriteBookIds = {};
  final Set<String> _downloads = {}; // "id@rev"
  final Map<String, Set<int>> _bookmarkedPages = {};
  final Map<String, double> _downloadProgress = {};

  bool _isInitialized = false;
  bool _isLoadingRemote = false;
  Future<void>? _initFuture;
  Timer? _progressSaveTimer;

  /// الفهرس الحالي. القائمة نفسها تُعاد إلى أن يتغيّر الفهرس، فتصلح مفتاحاً
  /// لما يُحسب منه مرة واحدة.
  List<LibraryBook> get books => _booksView;

  /// التصنيفات التي فيها كتب، بترتيب العرض.
  List<LibraryCategory> get categories => _categories;
  bool get isInitialized => _isInitialized;
  bool get isLoadingRemote => _isLoadingRemote;

  /// التنزيل للقراءة بلا إنترنت يحتاج نظام ملفات؛ غير متاح في المتصفح.
  bool get canDownload => _store.isPersistent;

  LibraryBook? bookById(String id) => _byId[id];

  @visibleForTesting
  void debugReset({BookContentRepository? repository, LibraryCatalogFetcher? catalogFetcher}) {
    _repository = repository ?? BookContentRepository();
    _fetchCatalog = catalogFetcher ?? _fetchCatalogFromSupabase;
    _lastSyncAttempt = null;
    _books = [];
    _booksView = const [];
    _byId = {};
    _categories = const [];
    _remote.clear();
    _hidden.clear();
    _syncedAt = null;
    _fullSyncAt = null;
    _lastReadPages.clear();
    _lastReadDates.clear();
    _favoriteBookIds.clear();
    _downloads.clear();
    _bookmarkedPages.clear();
    _downloadProgress.clear();
    _isInitialized = false;
    _initFuture = null;
  }

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    _rebuildCatalog();
    try {
      final prefs = await SharedPreferences.getInstance();
      _loadReaderState(prefs);
      await _loadCachedCatalog(prefs);
      _rebuildCatalog();
      unawaited(_dropLegacyCaches(prefs));
    } catch (e) {
      debugPrint('⚠️ Error initializing LibraryService local state: $e');
    }

    _isInitialized = true;
    notifyListeners();

    unawaited(syncWithSupabase());
  }

  // ───────────────────────────── الفهرس ─────────────────────────────

  void _rebuildCatalog() {
    final cloud = <String, LibraryBook>{
      for (final b in kCloudSeedLibraryBooks) b.id: b,
      ..._remote,
    }..removeWhere((id, _) => LocalBookPages.bookIds.contains(id) || _hidden.contains(id));

    final cloudSorted = cloud.values.toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.title.compareTo(b.title);
      });
    _books = [...kLocalLibraryBooks, ...cloudSorted];
    _publishCatalog();
  }

  /// يحدّث ما يُشتق من [_books]: القائمة المعروضة، الفهرس بالمعرّف، التصنيفات.
  void _publishCatalog() {
    _booksView = List.unmodifiable(_books);
    _byId = {for (final b in _books) b.id: b};

    final counts = <String, int>{};
    final names = <String, String>{};
    for (final b in _books) {
      counts[b.category] = (counts[b.category] ?? 0) + 1;
      names.putIfAbsent(b.category, () => b.categoryName);
    }
    int rank(String id) {
      final i = _categoryOrder.indexOf(id);
      return i < 0 ? _categoryOrder.length : i;
    }

    final ids = counts.keys.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : counts[b]!.compareTo(counts[a]!);
      });
    _categories = List.unmodifiable([
      for (final id in ids) (id: id, name: names[id]!, count: counts[id]!),
    ]);
  }

  /// يزامن إن لم تجرِ محاولة منذ [_staleAfter]. تستدعيها شاشة المكتبة عند فتحها.
  void refreshIfStale() {
    final last = _lastSyncAttempt;
    if (!_isInitialized || _isLoadingRemote) return;
    if (last != null && DateTime.now().difference(last) < _staleAfter) return;
    unawaited(syncWithSupabase());
  }

  static Future<List<Map<String, dynamic>>> _fetchCatalogFromSupabase({
    required String? since,
    required int offset,
    required int limit,
  }) async {
    var query = Supabase.instance.client
        .from('library_books')
        .select(_catalogColumns)
        .eq('content_format', LibraryBook.cloudFormat);
    if (since != null) query = query.gt('updated_at', since);
    return query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1)
        .timeout(const Duration(seconds: 20));
  }

  Future<void> _loadCachedCatalog(SharedPreferences prefs) async {
    final raw = await _store.read(_catalogFile) ?? prefs.getString(_catalogKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final blob = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in blob['books'] as List) {
        final book = LibraryBook.fromJson(item as Map<String, dynamic>);
        if (book.id.isNotEmpty && book.isCloud) _remote[book.id] = book;
      }
      _hidden.addAll((blob['hidden'] as List? ?? const []).cast<String>());
      _syncedAt = blob['syncedAt'] as String?;
      _fullSyncAt = DateTime.tryParse(blob['fullSyncAt'] as String? ?? '');
    } catch (e) {
      debugPrint('⚠️ Cached library catalog unreadable, will resync: $e');
      _remote.clear();
      _hidden.clear();
      _syncedAt = null;
      _fullSyncAt = null;
    }
  }

  Future<void> _saveCachedCatalog() async {
    final raw = jsonEncode({
      'syncedAt': _syncedAt,
      'fullSyncAt': _fullSyncAt?.toIso8601String(),
      'hidden': _hidden.toList(),
      'books': [
        for (final b in _remote.values) b.toJson()..remove('chapters')..remove('pages'),
      ],
    });
    if (_store.isPersistent) {
      await _store.write(_catalogFile, raw);
      return;
    }
    // المتصفح: التخزين المحلي ضيق؛ فهرس كبير يُعاد جلبه بدل حشره هناك
    final prefs = await SharedPreferences.getInstance();
    if (raw.length < 400000) {
      await prefs.setString(_catalogKey, raw);
    } else {
      await prefs.remove(_catalogKey);
    }
  }

  /// يجلب ما تغيّر في `library_books` منذ آخر مزامنة، صفحةً صفحة.
  /// لا يرمي: بلا شبكة أو بلا جدول يبقى الفهرس المحفوظ كما هو.
  Future<void> syncWithSupabase() async {
    if (_isLoadingRemote) return;
    _isLoadingRemote = true;
    _lastSyncAttempt = DateTime.now();
    notifyListeners();

    try {
      final now = DateTime.now();
      final full = _syncedAt == null ||
          _fullSyncAt == null ||
          now.difference(_fullSyncAt!) > _fullSyncEvery;

      String? since;
      if (!full) {
        final last = DateTime.tryParse(_syncedAt!);
        since = last?.subtract(_syncOverlap).toUtc().toIso8601String();
      }

      final seen = <String>{};
      var newest = _syncedAt;
      for (var offset = 0;; offset += _syncPageSize) {
        final rows = await _fetchCatalog(since: since, offset: offset, limit: _syncPageSize);

        for (final row in rows) {
          final id = row['id'] as String? ?? '';
          if (id.isEmpty) continue;
          seen.add(id);
          final updatedAt = row['updated_at'] as String?;
          if (updatedAt != null && (newest == null || _isAfter(updatedAt, newest))) {
            newest = updatedAt;
          }
          if (row['is_published'] == false) {
            _remote.remove(id);
            _hidden.add(id);
            continue;
          }
          try {
            final book = LibraryBook.fromJson(row);
            if (!book.isCloud) continue;
            _remote[id] = book;
            _hidden.remove(id);
          } catch (e) {
            debugPrint('⚠️ Error parsing remote library book $id: $e');
          }
        }
        if (rows.length < _syncPageSize) break;
      }

      if (full) {
        // ما غاب عن مزامنة كاملة حُذف من الجدول
        _remote.removeWhere((id, _) => !seen.contains(id));
        for (final seed in kCloudSeedLibraryBooks) {
          if (!seen.contains(seed.id)) _hidden.add(seed.id);
        }
        _fullSyncAt = now;
      }
      _syncedAt = newest;

      _rebuildCatalog();
      await _saveCachedCatalog();
    } catch (e) {
      debugPrint('ℹ️ Supabase library sync note (using saved catalog): $e');
    } finally {
      _isLoadingRemote = false;
      notifyListeners();
    }
  }

  static bool _isAfter(String a, String b) {
    final da = DateTime.tryParse(a), db = DateTime.tryParse(b);
    if (da == null || db == null) return a.compareTo(b) > 0;
    return da.isAfter(db);
  }

  /// نسخ قديمة كانت تحفظ نصوص كتب كاملة داخل SharedPreferences.
  Future<void> _dropLegacyCaches(SharedPreferences prefs) async {
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('lib_pages_cache_') || key == 'lib_cached_dynamic_books') {
        await prefs.remove(key);
      }
    }
  }

  // ───────────────────────────── المحتوى ─────────────────────────────

  /// يفتح محتوى الكتاب للقراءة. يرمي [BookUnavailableException] إن تعذّر.
  Future<BookContent> openContent(LibraryBook book) async {
    final current = bookById(book.id) ?? book;
    if (current.isCloud) {
      BookContent content;
      try {
        content = await _repository.open(current);
      } on BookUnavailableException {
        // ربما أُعيد استيراد الكتاب وحُذفت المراجعة التي نعرفها قبل أن نزامن
        final fresh = await _refreshBook(current.id);
        if (fresh == null || fresh.contentRev == current.contentRev) rethrow;
        content = await _repository.open(fresh);
      }
      _alignPageCount(current.id, content.index.pageCount);
      return content;
    }
    final pages = await LocalBookPages.load(current);
    if (pages.isEmpty) {
      throw const BookUnavailableException('لا يوجد محتوى لهذا الكتاب.');
    }
    _alignPageCount(current.id, pages.length);
    return LocalBookContent.fromPages(pages);
  }

  /// يقرأ صف كتاب واحد من الجدول ويحدّث به الفهرس. null إن تعذّر.
  Future<LibraryBook?> _refreshBook(String bookId) async {
    try {
      final row = await Supabase.instance.client
          .from('library_books')
          .select(_catalogColumns)
          .eq('id', bookId)
          .eq('content_format', LibraryBook.cloudFormat)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      if (row == null || row['is_published'] == false) return null;
      final book = LibraryBook.fromJson(row);
      if (!book.isCloud) return null;
      _remote[bookId] = book;
      _rebuildCatalog();
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      unawaited(_saveCachedCatalog());
      return book;
    } catch (e) {
      debugPrint('ℹ️ Could not refresh library book $bookId: $e');
      return null;
    }
  }

  /// فهرس عناوين كتاب سحابي (لبطاقة التفاصيل)، أو null إن تعذّر.
  Future<BookIndex?> loadIndex(LibraryBook book) async {
    try {
      return (await openContent(book)).index;
    } catch (_) {
      return null;
    }
  }

  void _alignPageCount(String bookId, int pageCount) {
    final i = _books.indexWhere((b) => b.id == bookId);
    if (i < 0 || _books[i].totalPages == pageCount) return;
    _books[i] = _books[i].copyWith(totalPages: pageCount);
    _publishCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  // ───────────────────────────── التنزيل ─────────────────────────────

  static String _downloadKey(LibraryBook b) => '${b.id}@${b.contentRev}';

  /// الكتب المضمّنة حاضرة دائماً؛ السحابية حين تُنزَّل مراجعتها الحالية.
  bool isDownloaded(String bookId) {
    final book = bookById(bookId);
    if (book == null) return false;
    return !book.isCloud || _downloads.contains(_downloadKey(book));
  }

  /// نسبة التنزيل الجاري (0–1)، أو null إن لم يكن هناك تنزيل.
  double? downloadProgress(String bookId) => _downloadProgress[bookId];

  /// يرمي [BookUnavailableException] إن انقطع التنزيل؛ ما نزل يبقى محفوظاً
  /// فتُكمل المحاولة التالية من حيث توقفت.
  Future<void> downloadBook(String bookId) async {
    final book = bookById(bookId);
    if (book == null || !book.isCloud || !canDownload) return;
    if (_downloadProgress.containsKey(bookId)) return;

    _downloadProgress[bookId] = 0;
    notifyListeners();
    try {
      await _repository.download(book, onProgress: (done, total) {
        _downloadProgress[bookId] = total == 0 ? 1 : done / total;
        notifyListeners();
      });
      _downloads
        ..removeWhere((key) => key.startsWith('$bookId@'))
        ..add(_downloadKey(book));
      await _saveStringSet(_downloadsKey, _downloads);
    } finally {
      _downloadProgress.remove(bookId);
      notifyListeners();
    }
  }

  Future<void> removeDownload(String bookId) async {
    final book = bookById(bookId);
    if (book == null || !book.isCloud) return;
    _downloads.removeWhere((key) => key.startsWith('$bookId@'));
    notifyListeners();
    await _repository.removeFromDevice(bookId);
    await _saveStringSet(_downloadsKey, _downloads);
  }

  // ───────────────────────────── حالة القارئ ─────────────────────────────

  void _loadReaderState(SharedPreferences prefs) {
    _favoriteBookIds.addAll(prefs.getStringList(_favoritesKey) ?? const []);
    _downloads.addAll(prefs.getStringList(_downloadsKey) ?? const []);

    final progress = prefs.getString(_progressKey);
    if (progress != null) {
      (jsonDecode(progress) as Map<String, dynamic>).forEach((id, value) {
        final pair = value as List;
        _lastReadPages[id] = (pair[0] as num).toInt();
        _lastReadDates[id] = DateTime.fromMillisecondsSinceEpoch((pair[1] as num).toInt());
      });
    }

    final bookmarks = prefs.getString(_bookmarksKey);
    if (bookmarks != null) {
      (jsonDecode(bookmarks) as Map<String, dynamic>).forEach((id, pages) {
        _bookmarkedPages[id] = (pages as List).map((p) => (p as num).toInt()).toSet();
      });
    }
  }

  Future<void> _saveStringSet(String key, Set<String> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, values.toList());
    } catch (e) {
      debugPrint('⚠️ Error saving $key: $e');
    }
  }

  int getLastReadPage(String bookId) => _lastReadPages[bookId] ?? 1;

  DateTime? getLastReadDate(String bookId) => _lastReadDates[bookId];

  /// يحفظ موضع القراءة. الكتابة إلى القرص مؤجَّلة قليلاً لأن القارئ يستدعيها
  /// مع كل صفحة تمرّ أثناء التمرير.
  Future<void> saveLastReadPage(String bookId, int page, {bool notify = true}) async {
    if (page < 1 || _lastReadPages[bookId] == page) return;

    _lastReadPages[bookId] = page;
    _lastReadDates[bookId] = DateTime.now();

    if (notify) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }

    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(milliseconds: 600), flushProgress);
  }

  /// يكتب مواضع القراءة فوراً. القارئ يستدعيها عند إغلاقه مع [notify] لتحدّث
  /// المكتبة شريط التقدم؛ أثناء القراءة لا إشعار كي لا تُعاد بناء الرفوف خلفه.
  Future<void> flushProgress({bool notify = false}) async {
    _progressSaveTimer?.cancel();
    if (notify) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _progressKey,
        jsonEncode({
          for (final e in _lastReadPages.entries)
            e.key: [e.value, (_lastReadDates[e.key] ?? DateTime.now()).millisecondsSinceEpoch],
        }),
      );
    } catch (e) {
      debugPrint('⚠️ Error saving reading progress: $e');
    }
  }

  /// نسبة القراءة (0.0 – 1.0).
  double getProgress(String bookId, int totalPages) {
    if (totalPages <= 0) return 0.0;
    return (getLastReadPage(bookId) / totalPages).clamp(0.0, 1.0);
  }

  bool isFavorite(String bookId) => _favoriteBookIds.contains(bookId);

  Future<void> toggleFavorite(String bookId) async {
    if (!_favoriteBookIds.remove(bookId)) _favoriteBookIds.add(bookId);
    notifyListeners();
    await _saveStringSet(_favoritesKey, _favoriteBookIds);
  }

  bool isPageBookmarked(String bookId, int page) =>
      _bookmarkedPages[bookId]?.contains(page) ?? false;

  Future<void> toggleBookmark(String bookId, int page) async {
    final set = _bookmarkedPages.putIfAbsent(bookId, () => <int>{});
    if (!set.remove(page)) set.add(page);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bookmarksKey,
        jsonEncode({
          for (final e in _bookmarkedPages.entries)
            if (e.value.isNotEmpty) e.key: e.value.toList(),
        }),
      );
    } catch (e) {
      debugPrint('⚠️ Error saving bookmarks: $e');
    }
  }

  Set<int> getBookmarks(String bookId) => _bookmarkedPages[bookId] ?? const <int>{};
}
