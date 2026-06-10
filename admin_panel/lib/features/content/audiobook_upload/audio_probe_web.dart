// Web-only implementation, loaded via conditional import from audio_probe.dart.
// The two lints below are known false positives for this pattern:
// - avoid_web_libraries_in_flutter: file is loaded only on web, never on mobile.
// - deprecated_member_use: dart:html is still functional; package:web migration
//   requires reworking event-stream usage and is tracked separately.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

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
