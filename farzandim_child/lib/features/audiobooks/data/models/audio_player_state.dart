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

  const AudioPlayerState({
    this.currentBook,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.sleepTimerRemaining = Duration.zero,
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
  }) {
    return AudioPlayerState(
      currentBook: clearBook ? null : (currentBook ?? this.currentBook),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      sleepTimerRemaining:
          sleepTimerRemaining ?? this.sleepTimerRemaining,
    );
  }
}
