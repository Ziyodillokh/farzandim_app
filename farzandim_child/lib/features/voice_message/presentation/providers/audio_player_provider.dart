// ─────────────────────────────────────────────────────────────────────
// audio_player_provider — Voice chat audio player Riverpod streams
// ─────────────────────────────────────────────────────────────────────
//
// Eslatma: nomi `audio_player_provider` lekin audiobooks feature'idagi
// bir xil nomdagi fayldan farqli — bu faqat voice chat uchun
// (`AudioPlayerManager` singleton'ga o'rama).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:farzandim_child/features/voice_message/data/services/audio_player_manager.dart';

final audioPlayerManagerProvider = Provider<AudioPlayerManager>(
  (ref) => AudioPlayerManager.instance,
);

/// Hozirgi play bo'layotgan xabar id'si — null bo'lsa hech narsa o'ynamayapti.
final currentlyPlayingIdProvider = StreamProvider<String?>((ref) {
  return AudioPlayerManager.instance.currentIdStream;
});

/// Real-time pozitsiya (waveform progress uchun).
final audioPositionProvider = StreamProvider<Duration>((ref) {
  return AudioPlayerManager.instance.positionStream;
});

/// Real-time duration (yuklanguncha null bo'lishi mumkin).
final audioDurationProvider = StreamProvider<Duration?>((ref) {
  return AudioPlayerManager.instance.durationStream;
});

/// Player state (playing, paused, completed).
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  return AudioPlayerManager.instance.playerStateStream;
});

/// Joriy speed (1.0 / 1.5 / 2.0).
final audioSpeedProvider = StreamProvider<double>((ref) {
  return AudioPlayerManager.instance.speedStream;
});
