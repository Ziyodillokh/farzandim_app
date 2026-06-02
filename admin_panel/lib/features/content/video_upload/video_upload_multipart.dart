import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'picked_video.dart';

Future<MultipartFile> videoToMultipart(PickedVideo v) async {
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
  throw StateError('Invalid PickedVideo: missing path and web file');
}

Future<MultipartFile?> thumbnailToMultipart(PickedThumbnail? t) async {
  if (t == null || t.bytes.isEmpty) return null;
  return MultipartFile.fromBytes(Uint8List.fromList(t.bytes), filename: t.fileName);
}
