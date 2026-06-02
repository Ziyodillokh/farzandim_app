import 'dart:html' as html;

import 'picked_audio.dart';
import 'audio_probe_result.dart';

Future<AudioProbeResult> probeAudio(PickedAudio v) async {
  final c = v.webController;
  final f = v.webFile;
  if (c == null || f == null) return const AudioProbeResult();
  final url = await c.createFileUrl(f);
  final audio = html.AudioElement()..src = url;
  try {
    await audio.onLoadedMetadata.first;
    final d = audio.duration;
    if (!d.isFinite || d.isNaN || d <= 0) {
      return const AudioProbeResult();
    }
    return AudioProbeResult(durationSec: d.floor());
  } catch (_) {
    return const AudioProbeResult();
  } finally {
    await c.releaseFileUrl(url);
  }
}
