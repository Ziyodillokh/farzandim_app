import 'dart:io';

import 'package:video_player/video_player.dart';

import 'picked_video.dart';
import 'video_probe_result.dart';

Future<VideoProbeResult> probeVideo(PickedVideo v) async {
  final p = v.platformPath;
  if (p == null || p.isEmpty) {
    return const VideoProbeResult();
  }
  final c = VideoPlayerController.file(File(p));
  try {
    await c.initialize();
    if (!c.value.isInitialized) return const VideoProbeResult();
    final sec = c.value.duration.inSeconds;
    final sz = c.value.size;
    String? res;
    if (sz.width > 0 && sz.height > 0) {
      res = '${sz.width.toInt()}×${sz.height.toInt()}';
    }
    return VideoProbeResult(durationSec: sec, resolution: res);
  } catch (_) {
    return const VideoProbeResult();
  } finally {
    await c.dispose();
  }
}
