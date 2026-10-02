/// عنوان في فهرس الكتاب.
class BookTocEntry {
  final int level; // 1 = باب رئيسي
  final int page; // رقم الصفحة داخل التطبيق، يبدأ من 1
  final String title;

  const BookTocEntry({required this.level, required this.page, required this.title});
}

/// مجلد من الكتاب يبدأ عند الصفحة [from].
class BookVolume {
  final String name;
  final int from;

  const BookVolume({required this.name, required this.from});
}

/// صفحة واحدة: متنها وحواشيها.
///
/// في المتن: السطر الذي يبدأ بـ [headingMark] عنوان، والسطر [ruleLine] فاصل،
/// و`(^١)` إحالة إلى حاشية.
class BookUnit {
  static const String headingMark = '## ';
  static const String ruleLine = '* * *';

  final String text;
  final String? notes;

  const BookUnit({required this.text, this.notes});

  /// النص كما يُنسخ أو يُشارك: بلا علامات التنسيق الداخلية.
  String get plainText => text
      .split('\n')
      .map((l) => l.startsWith(headingMark) ? l.substring(headingMark.length) : l)
      .where((l) => l != ruleLine)
      .join('\n')
      .replaceAllMapped(RegExp(r'\(\^([^)]+)\)'), (m) => '(${m[1]})');
}

/// فهرس الكتاب: كل ما يلزم لفتحه والتنقل فيه قبل تحميل أي صفحة.
class BookIndex {
  final int rev;
  final int pageCount;

  /// رقم أول صفحة في كل جزء، تصاعدياً؛ الجزء `n` ملفه `c<n>.json`.
  final List<int> chunkStarts;

  /// رقم الصفحة في الطبعة الورقية لكل صفحة (0 = غير معروف).
  final List<int> printPages;
  final List<BookVolume> volumes;
  final List<BookTocEntry> toc;

  /// بيانات الطبعة: المحقق والناشر وسنة النشر.
  final String edition;
  final String source;

  BookIndex({
    required this.rev,
    required this.pageCount,
    required this.chunkStarts,
    required this.printPages,
    required this.volumes,
    required this.toc,
    this.edition = '',
    this.source = '',
  });

  factory BookIndex.fromJson(Map<String, dynamic> json) {
    final pageCount = (json['pages'] as num).toInt();
    final chunkStarts = (json['chunks'] as List).map((e) => (e as num).toInt()).toList();
    if (pageCount < 1 || chunkStarts.isEmpty || chunkStarts.first != 1) {
      throw const FormatException('فهرس كتاب غير صالح');
    }
    return BookIndex(
      rev: (json['rev'] as num?)?.toInt() ?? 0,
      pageCount: pageCount,
      chunkStarts: chunkStarts,
      printPages: (json['printPages'] as List? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      volumes: (json['volumes'] as List? ?? const [])
          .map((v) => BookVolume(
                name: (v as Map)['name']?.toString() ?? '',
                from: (v['from'] as num).toInt(),
              ))
          .toList(),
      toc: (json['toc'] as List? ?? const [])
          .map((e) => BookTocEntry(
                level: ((e as List)[0] as num).toInt(),
                page: (e[1] as num).toInt(),
                title: e[2] as String,
              ))
          .toList(),
      edition: json['edition'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  int get chunkCount => chunkStarts.length;

  /// رقم الجزء الذي يحوي [page].
  int chunkOf(int page) {
    var lo = 0, hi = chunkStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (chunkStarts[mid] <= page) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// عدد صفحات الجزء [chunk].
  int chunkLength(int chunk) {
    final end = chunk + 1 < chunkStarts.length ? chunkStarts[chunk + 1] : pageCount + 1;
    return end - chunkStarts[chunk];
  }

  BookVolume? volumeOf(int page) {
    BookVolume? found;
    for (final v in volumes) {
      if (v.from > page) break;
      found = v;
    }
    return found;
  }

  int printPageOf(int page) =>
      page >= 1 && page <= printPages.length ? printPages[page - 1] : 0;

  /// هل تبدأ عند [page] صفحة ورقية جديدة؟ الصفحة الورقية الواحدة قد تنقسم
  /// إلى أكثر من صفحة هنا عند كل عنوان، فلا يتكرر الترقيم بينها.
  bool startsPrintPage(int page) {
    if (page <= 1) return true;
    return printPageOf(page) != printPageOf(page - 1) ||
        volumeOf(page)?.name != volumeOf(page - 1)?.name;
  }

  bool get hasPrintPages => printPages.any((p) => p > 0);

  /// أول صفحة رقمها في المطبوع [printed]: في مجلد [near] أولاً، ثم في أي مجلد.
  int? pageForPrint(int printed, {required int near}) {
    final volume = volumeOf(near)?.from;
    int? anywhere;
    for (var i = 0; i < printPages.length; i++) {
      if (printPages[i] != printed) continue;
      if (volumeOf(i + 1)?.from == volume) return i + 1;
      anywhere ??= i + 1;
    }
    return anywhere;
  }

  /// "ج٢ · ص ٣١" أو "المقدمة · ص ٥" أو "ص ٣١"؛ فارغ إن لم يُعرف رقم المطبوع.
  String printLabel(int page) {
    final printed = printPageOf(page);
    if (printed <= 0) return '';
    final vol = volumeOf(page)?.name ?? '';
    final numbered = volumes.where((v) => int.tryParse(v.name) != null).map((v) => v.name).toSet();
    if (int.tryParse(vol) == null) {
      return vol.isEmpty ? 'ص $printed' : '$vol · ص $printed';
    }
    return numbered.length > 1 ? 'ج$vol · ص $printed' : 'ص $printed';
  }

  /// ترتيب آخر عنوان يبدأ عند [page] أو قبلها في [toc]، أو -1.
  int tocIndexAt(int page) {
    var found = -1;
    for (var i = 0; i < toc.length; i++) {
      if (toc[i].page <= page) {
        found = i;
      } else if (toc[i].page > page) {
        break;
      }
    }
    return found;
  }

  BookTocEntry? headingAt(int page) {
    final i = tocIndexAt(page);
    return i < 0 ? null : toc[i];
  }
}
