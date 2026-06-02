import 'picked_audio.dart';
import 'audio_probe_result.dart';
import 'audio_probe_io.dart' if (dart.library.html) 'audio_probe_web.dart' as impl;

Future<AudioProbeResult> probeAudio(PickedAudio v) => impl.probeAudio(v);
