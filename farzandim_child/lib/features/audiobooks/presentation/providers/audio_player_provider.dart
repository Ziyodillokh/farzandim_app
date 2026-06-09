// ─────────────────────────────────────────────────────────────────────
// audio_player_provider — global audio playback (StateNotifier)
// ─────────────────────────────────────────────────────────────────────
//
// Spotify uslubidagi global audio: bir vaqtda faqat bitta audiokitob
// o'ynaydi. MiniAudioPlayer va AudioPlayerScreen shu provider'ga obuna.
//
// Sleep timer: `startSleepTimer(minutes)` → har sekundda state'ning
// sleepTimerRemaining maydoni yangilanadi; 0'ga yetganda audio pause.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  AudioPlayerNotifier() : super(const AudioPlayerState()) {
    _positionSub = _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });

    _playerStateSub = _player.playerStateStream.listen((s) {
      state = state.copyWith(isPlaying: s.playing);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _sleepTimer;

  Future<void> play(AudiobookModel book) async {
    state = state.copyWith(currentBook: book);
    // MediaItem tag — lock screen va notification'da rasm + sarlavha
    // ko'rsatish uchun. just_audio_background buni o'qib system media
    // controls'ga uzatadi (Android: MediaSession, iOS: MPNowPlayingInfo).
    await _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(book.audioUrl),
        tag: MediaItem(
          id: book.id,
          title: book.title,
          artist: book.author,
          album: 'Farzandim Edu',
          duration: Duration(seconds: book.durationSeconds),
          artUri: book.coverUrl.isNotEmpty
              ? Uri.parse(book.coverUrl)
              : null,
        ),
      ),
    );
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekForward([int seconds = 15]) async {
    final newPos = state.position + Duration(seconds: seconds);
    await seek(newPos < state.duration ? newPos : state.duration);
  }

  Future<void> seekBackward([int seconds = 15]) async {
    final newPos = state.position - Duration(seconds: seconds);
    await seek(newPos > Duration.zero ? newPos : Duration.zero);
  }

  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> stop() async {
    await _player.stop();
    cancelSleepTimer();
    state = state.copyWith(clearBook: true);
  }

  void startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    state =
        state.copyWith(sleepTimerRemaining: Duration(minutes: minutes));

    _sleepTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = state.sleepTimerRemaining;
      if (remaining.inSeconds <= 1) {
        timer.cancel();
        _sleepTimer = null;
        await _player.pause();
        state = state.copyWith(sleepTimerRemaining: Duration.zero);
      } else {
        state = state.copyWith(
          sleepTimerRemaining:
              Duration(seconds: remaining.inSeconds - 1),
        );
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    state = state.copyWith(sleepTimerRemaining: Duration.zero);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  (ref) => AudioPlayerNotifier(),
);

/// Hozirgi tezlik (UI ko'rsatish uchun). `setSpeed` chaqirilganda
/// shu provider ham yangilanadi.
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
