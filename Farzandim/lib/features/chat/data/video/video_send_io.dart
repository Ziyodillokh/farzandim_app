// Video yuborish — telefon (dart:io File + videoUploadProvider).

import 'dart:io';

import 'package:farzandim/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yozib olingan videoni backendga yuboradi (telefon).
Future<bool> sendRecordedVideo(
  WidgetRef ref, {
  required String childId,
  required String path,
  required int seconds,
}) {
  return ref.read(videoUploadProvider.notifier).send(
    childId: childId,
    videoFile: File(path),
    durationSeconds: seconds,
  );
}
