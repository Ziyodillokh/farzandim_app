// Sprint 5.6d — Books PDF upload chegaralari va MIME ruxsatlari.
//
// Backend cheklov (`admin-content/books.ts` MAX_PDF_BYTES): 50 MB.
// Frontend bir oz qattiqroq — chunki RAM'ga butun fayl yuklanadi.

const int kMaxPdfUploadBytes = 50 * 1024 * 1024; // 50 MB

bool isAllowedPdfFileName(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0) return false;
  final ext = name.substring(i).toLowerCase();
  return ext == '.pdf';
}

String formatPdfSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
