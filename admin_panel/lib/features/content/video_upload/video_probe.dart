import 'picked_video.dart';
import 'video_probe_result.dart';
import 'video_probe_io.dart' if (dart.library.html) 'video_probe_web.dart' as impl;

Future<VideoProbeResult> probeVideo(PickedVideo v) => impl.probeVideo(v);
