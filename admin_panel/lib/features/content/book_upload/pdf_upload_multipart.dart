import 'package:dio/dio.dart';

import 'picked_pdf.dart';

/// `PickedPdf` → `MultipartFile`.
/// Web tomonida `flutter_dropzone` orqali stream qilamiz; IO/desktop'da
/// `MultipartFile.fromFile` ishlatamiz (path mavjud).
Future<MultipartFile> pdfToMultipart(PickedPdf v) async {
  if (v.platformPath != null && v.platformPath!.isNotEmpty) {
    return MultipartFile.fromFile(v.platformPath!, filename: v.fileName);
  }
  final f = v.webFile;
  final c = v.webController;
  if (f != null && c != null) {
    final len = await c.getFileSize(f);
    return MultipartFile.fromStream(
      () => c.getFileStream(f),
      len,
      filename: v.fileName,
    );
  }
  throw StateError('Invalid PickedPdf: missing path and web file');
}
