class BookPage {
  final int pageNumber;
  final String title;
  final String content;
  final String? footnote;
  final String? section;

  const BookPage({
    required this.pageNumber,
    required this.title,
    required this.content,
    this.footnote,
    this.section,
  });

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'title': title,
    'content': content,
    'footnote': footnote,
    'section': section,
  };

  factory BookPage.fromJson(Map<String, dynamic> json) => BookPage(
    pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
    footnote: json['footnote'] as String?,
    section: json['section'] as String?,
  );
}

class BookChapter {
  final int index;
  final String title;
  final int startPage;
  final int endPage;

  const BookChapter({
    required this.index,
    required this.title,
    required this.startPage,
    required this.endPage,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'startPage': startPage,
    'endPage': endPage,
  };

  factory BookChapter.fromJson(Map<String, dynamic> json) => BookChapter(
    index: (json['index'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    startPage: (json['startPage'] as num?)?.toInt() ?? 1,
    endPage: (json['endPage'] as num?)?.toInt() ?? 1,
  );
}

class LibraryBook {
  /// صيغة المحتوى السحابي: فهرس + أجزاء في Storage (انظر tool/library).
  static const int cloudFormat = 2;

  final String id;
  final String title;
  final String shortTitle;
  final String author;
  final String category; // 'hadith', 'tafsir', 'seerah', 'tazkiyah', 'fiqh', 'aqeedah'
  final String categoryName;
  final String description;
  final int coverColor; // e.g. 0xFF1B4332
  final String? coverImageUrl;
  final String? contentUrl; // رابط index.json للكتاب السحابي
  final int contentFormat;
  final int contentRev;
  final int totalPages;
  final int chaptersCount;
  final String fileSize;
  final bool isBuiltIn;
  final bool isInteractiveHadith;
  final String? hadithBookKey; // 'bukhari', 'muslim', 'qudsi', 'nawawi', 'riyad'
  final int sortOrder;
  final List<BookChapter> chapters;
  final List<BookPage> pages;

  const LibraryBook({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.author,
    required this.category,
    required this.categoryName,
    required this.description,
    this.coverColor = 0xFF1B4332,
    this.coverImageUrl,
    this.contentUrl,
    this.contentFormat = 1,
    this.contentRev = 0,
    this.totalPages = 100,
    this.chaptersCount = 10,
    this.fileSize = '1.2 ميغابايت',
    this.isBuiltIn = true,
    this.isInteractiveHadith = false,
    this.hadithBookKey,
    this.sortOrder = 1000,
    this.chapters = const [],
    this.pages = const [],
  });

  /// نصّه في السحابة ويُجلب جزءاً جزءاً، لا مضمَّناً في التطبيق.
  bool get isCloud =>
      contentFormat == cloudFormat && contentUrl != null && contentUrl!.isNotEmpty;

  LibraryBook copyWith({
    String? id,
    String? title,
    String? shortTitle,
    String? author,
    String? category,
    String? categoryName,
    String? description,
    int? coverColor,
    String? coverImageUrl,
    String? contentUrl,
    int? contentFormat,
    int? contentRev,
    int? totalPages,
    int? chaptersCount,
    String? fileSize,
    bool? isBuiltIn,
    bool? isInteractiveHadith,
    String? hadithBookKey,
    int? sortOrder,
    List<BookChapter>? chapters,
    List<BookPage>? pages,
  }) {
    return LibraryBook(
      id: id ?? this.id,
      title: title ?? this.title,
      shortTitle: shortTitle ?? this.shortTitle,
      author: author ?? this.author,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      coverColor: coverColor ?? this.coverColor,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      contentUrl: contentUrl ?? this.contentUrl,
      contentFormat: contentFormat ?? this.contentFormat,
      contentRev: contentRev ?? this.contentRev,
      totalPages: totalPages ?? this.totalPages,
      chaptersCount: chaptersCount ?? this.chaptersCount,
      fileSize: fileSize ?? this.fileSize,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isInteractiveHadith: isInteractiveHadith ?? this.isInteractiveHadith,
      hadithBookKey: hadithBookKey ?? this.hadithBookKey,
      sortOrder: sortOrder ?? this.sortOrder,
      chapters: chapters ?? this.chapters,
      pages: pages ?? this.pages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'shortTitle': shortTitle,
    'author': author,
    'category': category,
    'categoryName': categoryName,
    'description': description,
    'coverColor': coverColor,
    'coverImageUrl': coverImageUrl,
    'contentUrl': contentUrl,
    'contentFormat': contentFormat,
    'contentRev': contentRev,
    'totalPages': totalPages,
    'chaptersCount': chaptersCount,
    'fileSize': fileSize,
    'isBuiltIn': isBuiltIn,
    'isInteractiveHadith': isInteractiveHadith,
    'hadithBookKey': hadithBookKey,
    'sortOrder': sortOrder,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'pages': pages.map((p) => p.toJson()).toList(),
  };

  /// يقرأ الصيغتين: مفاتيح التطبيق (camelCase) وأعمدة جدول
  /// `library_books` في Supabase (snake_case).
  factory LibraryBook.fromJson(Map<String, dynamic> json) {
    T? pick<T>(String camel, String snake) {
      final v = json[camel] ?? json[snake];
      return v is T ? v : null;
    }

    final title = json['title'] as String? ?? '';
    return LibraryBook(
      id: json['id'] as String? ?? '',
      title: title,
      shortTitle: pick<String>('shortTitle', 'short_title') ?? title,
      author: json['author'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      categoryName: pick<String>('categoryName', 'category_name') ?? 'عام',
      description: json['description'] as String? ?? '',
      coverColor: _opaque(pick<num>('coverColor', 'cover_color')?.toInt() ?? 0xFF1B4332),
      coverImageUrl: pick<String>('coverImageUrl', 'cover_image_url'),
      contentUrl: pick<String>('contentUrl', 'content_url'),
      contentFormat: pick<num>('contentFormat', 'content_format')?.toInt() ?? 1,
      contentRev: pick<num>('contentRev', 'content_rev')?.toInt() ?? 0,
      totalPages: pick<num>('totalPages', 'total_pages')?.toInt() ?? 100,
      chaptersCount: pick<num>('chaptersCount', 'chapters_count')?.toInt() ?? 10,
      fileSize: pick<String>('fileSize', 'file_size') ?? '1.2 ميغابايت',
      isBuiltIn: pick<bool>('isBuiltIn', 'is_built_in') ?? false,
      isInteractiveHadith: pick<bool>('isInteractiveHadith', 'is_interactive_hadith') ?? false,
      hadithBookKey: pick<String>('hadithBookKey', 'hadith_book_key'),
      sortOrder: pick<num>('sortOrder', 'sort_order')?.toInt() ?? 1000,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((c) => BookChapter.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      pages: (json['pages'] as List<dynamic>?)
              ?.map((p) => BookPage.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// لون بلا قناة ألفا (0x1B4332) يرسم غلافاً شفافاً؛ نكمله إلى معتم.
  static int _opaque(int color) => color <= 0xFFFFFF ? color | 0xFF000000 : color;
}
