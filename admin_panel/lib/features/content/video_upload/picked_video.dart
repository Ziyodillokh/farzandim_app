import 'package:flutter_dropzone/flutter_dropzone.dart';

/// Local video selection: native path (IO/desktop) or web dropzone handle (stream upload).
class PickedVideo {
  const PickedVideo({
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

  String get format {
    final i = fileName.lastIndexOf('.');
    if (i < 0) return '—';
    return fileName.substring(i + 1).toUpperCase();
  }
}

class PickedThumbnail {
  const PickedThumbnail({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final List<int> bytes;
}
