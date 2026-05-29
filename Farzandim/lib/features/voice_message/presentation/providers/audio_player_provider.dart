import 'package:farzandim/features/voice_message/data/services/audio_player_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// `AudioPlayerManager` singleton'ni Riverpod orqali olish — testda
/// override qilish va bubble ichidan chaqirish qulayligi uchun.
final audioPlayerManagerProvider = Provider<AudioPlayerManager>((ref) {
  return AudioPlayerManager.instance;
});

/// Hozir qaysi xabar o'ynayapti — bubble UI shu provider'ga reaktiv.
final currentlyPlayingIdProvider = StreamProvider<String?>((ref) {
  return AudioPlayerManager.instance.currentIdStream;
});

/// Joriy pozitsiya — bubble waveform progress uchun.
final audioPositionProvider = StreamProvider<Duration>((ref) {
  return AudioPlayerManager.instance.positionStream;
});

/// Audio umumiy davomiyligi.
final audioDurationProvider = StreamProvider<Duration?>((ref) {
  return AudioPlayerManager.instance.durationStream;
});

/// Player state — play/pause/loading icon'i uchun.
final audioPlayerStateProvider = StreamProvider<PlayerState>((ref) {
  return AudioPlayerManager.instance.playerStateStream;
});

/// Joriy tezlik (1× / 1.5× / 2×) — speed badge uchun.
final audioSpeedProvider = StreamProvider<double>((ref) {
  return AudioPlayerManager.instance.speedStream;
});
