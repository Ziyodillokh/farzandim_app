// ─────────────────────────────────────────────────────────────────────
// AudioPlayerState — global audio holati
// ─────────────────────────────────────────────────────────────────────
//
// `sleepTimerRemaining` Duration.zero bo'lsa taymer faol emas. Aks
// holda — qolgan vaqt. UI shu maydondan o'qib indikator ko'rsatadi.

import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';

class AudioPlayerState {
  final AudiobookModel? currentBook;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration sleepTimerRemaining;

  /// Audio yuklab/ijro etib bo'lmaganda xato matni (null = xato yo'q). UI shu
  /// orqali jim 0:00 o'rniga foydalanuvchiga xabar ko'rsatadi.
  final String? error;

  const AudioPlayerState({
    this.currentBook,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.sleepTimerRemaining = Duration.zero,
    this.error,
  });

  bool get hasAudio => currentBook != null;

  bool get hasSleepTimer => sleepTimerRemaining > Duration.zero;

  AudioPlayerState copyWith({
    AudiobookModel? currentBook,
    bool clearBook = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? sleepTimerRemaining,
    String? error,
    bool clearError = false,
  }) {
    return AudioPlayerState(
      currentBook: clearBook ? null : (currentBook ?? this.currentBook),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      sleepTimerRemaining:
          sleepTimerRemaining ?? this.sleepTimerRemaining,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
