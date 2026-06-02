import 'package:video_player/video_player.dart';

import 'picked_video.dart';
import 'video_probe_result.dart';

Future<VideoProbeResult> probeVideo(PickedVideo v) async {
  final c = v.webController;
  final f = v.webFile;
  if (c == null || f == null) return const VideoProbeResult();
  final url = await c.createFileUrl(f);
  VideoPlayerController? ctrl;
  try {
    ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await ctrl.initialize();
    if (!ctrl.value.isInitialized) return const VideoProbeResult();
    final sec = ctrl.value.duration.inSeconds;
    final sz = ctrl.value.size;
    String? res;
    if (sz.width > 0 && sz.height > 0) {
      res = '${sz.width.toInt()}×${sz.height.toInt()}';
    }
    return VideoProbeResult(durationSec: sec, resolution: res);
  } catch (_) {
    return const VideoProbeResult();
  } finally {
    await ctrl?.dispose();
    await c.releaseFileUrl(url);
  }
}
