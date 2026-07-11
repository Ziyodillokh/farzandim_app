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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/repositories/audiobooks_backend_repository.dart';
import 'package:farzandim_child/features/statistics/presentation/providers/stats_providers.dart';

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  AudioPlayerNotifier(this._ref) : super(const AudioPlayerState()) {
    _positionSub = _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur == null) return;
      state = state.copyWith(duration: dur);
      // Haqiqiy davomiylikni backend'ga yuboramiz (faqat hozir noma'lum
      // bo'lsa va bir marta) — ro'yxatda to'g'ri vaqt chiqsin.
      final book = state.currentBook;
      if (book != null &&
          book.durationSeconds <= 0 &&
          dur.inSeconds > 0 &&
          _reportedDurationFor != book.id) {
        _reportedDurationFor = book.id;
        _ref
            .read(audiobooksBackendRepositoryProvider)
            .reportDuration(book.id, dur.inSeconds);
      }
    });

    _playerStateSub = _player.playerStateStream.listen((s) {
      state = state.copyWith(isPlaying: s.playing);
      // Kitob OXIRIGACHA tinglandi -> BOOK_READ XP (+50) — "O'qilgan
      // kitoblar" real soniga kiradi. Har kitob uchun bir marta.
      final book = state.currentBook;
      if (s.processingState == ProcessingState.completed &&
          book != null &&
          _bookReadReportedFor != book.id) {
        _bookReadReportedFor = book.id;
        _ref.read(bookReadEventProvider)();
      }
    });
  }

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _sleepTimer;
  // Qaysi kitob uchun duration backend'ga yuborilgan (bir marta).
  String? _reportedDurationFor;
  // Qaysi kitob uchun BOOK_READ yuborilgan (bir marta).
  String? _bookReadReportedFor;

  Future<void> play(AudiobookModel book) async {
    // Tinglashlar hisoblagichi (backend analitikasi) — yangi kitob qo'yilganda.
    if (state.currentBook?.id != book.id) {
      _ref.read(audiobooksBackendRepositoryProvider).markPlayed(book.id);
    }
    state = state.copyWith(currentBook: book, clearError: true);

    final url = book.audioUrl.trim();
    if (url.isEmpty) {
      state = state.copyWith(error: 'Audio manzili topilmadi');
      return;
    }

    // ODDIY just_audio — ovozli xabarlar bilan BIR XIL (isbotlangan, ishonchli).
    // Avval just_audio_background + MediaItem tag ishlatilgan edi; release
    // APK'da audio JIM qolib duration 0 bo'lardi (background media servis ishga
    // tushmasdi). Lock-screen controls o'rniga ishonchli ijroni tanladik.
    // Xato bo'lsa jim qolmasdan UI'ga chiqaramiz.
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e, st) {
      debugPrint('[AudioPlayer] yuklab bo\'lmadi url=$url\n$e\n$st');
      state = state.copyWith(error: "Audioni ijro etib bo'lmadi: $e");
    }
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
  (ref) => AudioPlayerNotifier(ref),
);

/// Hozirgi tezlik (UI ko'rsatish uchun). `setSpeed` chaqirilganda
/// shu provider ham yangilanadi.
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
