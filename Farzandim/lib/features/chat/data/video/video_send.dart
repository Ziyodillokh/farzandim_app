// Yozib olingan videoni backendga yuboradi — platforma-mustaqil kirish nuqtasi.
// Telefon: `videoUploadProvider` (File). Web: yuborib bo'lmaydi (false qaytadi).

// ignore_for_file: lines_longer_than_80_chars

import 'package:farzandim/features/chat/data/video/video_send_io.dart'
    if (dart.library.html) 'package:farzandim/features/chat/data/video/video_send_web.dart'
    as impl;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yozib olingan videoni yuboradi. Web'da `false` (fayl yuklab bo'lmaydi).
Future<bool> sendRecordedVideo(
  WidgetRef ref, {
  required String childId,
  required String path,
  required int seconds,
}) =>
    impl.sendRecordedVideo(ref, childId: childId, path: path, seconds: seconds);
