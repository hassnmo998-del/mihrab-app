import 'package:flutter/material.dart';

import '../../models/library_book.dart';
import '../../services/library_service.dart';
import 'book_reader_screen.dart';
import 'hadith_book_viewer_screen.dart';

/// كتب الحديث التفاعلية تُفتح في عارض الحديث، وباقي الكتب في القارئ.
bool isHadithViewerBook(LibraryBook book) =>
    book.isInteractiveHadith ||
    book.hadithBookKey != null ||
    book.id == 'sahih_bukhari' ||
    book.id == 'sahih_muslim' ||
    book.id == 'riyad_salihin' ||
    book.id == 'arbaeen_nawawi' ||
    book.id == 'qudsi_hadiths';

/// يفتح الكتاب عند آخر موضع قراءة (أو عند [page] إن حُدّدت).
void openLibraryBook(BuildContext context, LibraryBook book, {int? page}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => isHadithViewerBook(book)
          ? HadithBookViewerScreen(book: book)
          : BookReaderScreen(
              book: book,
              initialPage: page ?? LibraryService().getLastReadPage(book.id),
            ),
    ),
  );
}
