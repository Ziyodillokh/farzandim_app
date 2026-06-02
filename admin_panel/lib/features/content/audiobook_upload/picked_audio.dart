import 'package:flutter_dropzone/flutter_dropzone.dart';

class PickedAudio {
  const PickedAudio({
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
}
