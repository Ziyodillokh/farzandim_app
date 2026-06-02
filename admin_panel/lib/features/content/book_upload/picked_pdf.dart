import 'package:flutter_dropzone/flutter_dropzone.dart';

/// Lokal PDF tanlovi: native path (IO/desktop) yoki web dropzone handle (stream upload).
class PickedPdf {
  const PickedPdf({
    required this.fileName,
    required this.sizeBytes,
    this.platformPath,
    this.webFile,
    this.webController,
  });

  final String fileName;
  final int sizeBytes;
  final String? platformPath;
  final DropzoneFileInterface? webFile;
  final DropzoneViewController? webController;

  bool get isWeb => webFile != null && webController != null;
}
