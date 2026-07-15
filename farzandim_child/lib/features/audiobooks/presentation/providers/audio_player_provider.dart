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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/repositories/audiobooks_backend_repository.dart';
import 'package:farzandim_child/features/audiobooks/data/services/audiobook_audio_handler.dart';
import 'package:farzandim_child/features/statistics/presentation/providers/stats_providers.dart';

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  AudioPlayerNotifier(this._ref) : super(const AudioPlayerState()) {
    _positionSub = _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
      // Qolgan joydan davom etish uchun pozitsiyani saqlaymiz (throttle 5s).
      unawaited(_maybeSavePosition(pos));
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
      // Lock-screen/bildirishnoma kartochkasidagi davomiylikni ham
      // yangilaymiz (boshida noma'lum bo'lishi mumkin — stream orqali).
      if (book != null) _updateMediaItem(book, duration: dur);
    });

    _playerStateSub = _player.playerStateStream.listen((s) {
      state = state.copyWith(isPlaying: s.playing);
      // Kitob OXIRIGACHA tinglandi -> DON mukofoti (feed'dagi "N DON").
      // Faqat completion'da — chala chiqib ketsa berilmaydi. Har kitob
      // uchun bir marta (backend ham relatedId bo'yicha dedup qiladi).
      final book = state.currentBook;
      if (s.processingState == ProcessingState.completed &&
          book != null &&
          _bookReadReportedFor != book.id) {
        _bookReadReportedFor = book.id;
        unawaited(_onBookCompleted(book));
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

  // Background audio (lock-screen/bildirishnoma) — FAQAT shu player'ga
  // ulangan custom handler (sabab: `audiobook_audio_handler.dart` fayl
  // boshidagi izoh — `just_audio_background` global almashtirish chat
  // player'ini sindiradi). Init muvaffaqiyatsiz bo'lsa `null` qoladi —
  // audio baribir oddiy (faqat foreground) rejimda ishlayveradi.
  AudiobookAudioHandler? _audioHandler;
  bool _audioServiceInitAttempted = false;

  Future<void> _ensureAudioService() async {
    if (_audioServiceInitAttempted) return;
    _audioServiceInitAttempted = true;
    try {
      _audioHandler = await AudioService.init(
        builder: () => AudiobookAudioHandler(_player),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.farzandim.farzandim_child.audiobook',
          androidNotificationChannelName: 'Audiokitob',
          // `androidNotificationOngoing` faqat `androidStopForegroundOnPause:
          // true` (default) bilan birga ishlaydi (paket o'zi shart qo'yadi) —
          // shu kombinatsiya bildirishnomani pauza paytida ham ko'rsatadi.
          androidNotificationOngoing: true,
        ),
      );
    } catch (e) {
      debugPrint(
        '[AudioPlayer] Background audio init xato (foreground rejimda '
        'davom etadi): $e',
      );
    }
  }

  void _updateMediaItem(AudiobookModel book, {Duration? duration}) {
    final handler = _audioHandler;
    if (handler == null) return;
    handler.setMediaItem(
      MediaItem(
        id: book.id,
        title: book.title,
        artist: book.author,
        duration: duration ?? state.duration,
        artUri: Uri.tryParse(book.coverUrl),
      ),
    );
  }

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

    // Background audio — ilova fondan/ekran o'chsa ham davom etishi uchun
    // (bir martalik, best-effort — xato bo'lsa ham audio foreground'da
    // ishlayveradi, pastdagi asosiy try/catch buzilmaydi).
    await _ensureAudioService();

    // Xato bo'lsa jim qolmasdan UI'ga chiqaramiz.
    try {
      final dur = await _player.setUrl(url);
      // Lock-screen/bildirishnoma kartochkasi — darhol (duration hali
      // noma'lum bo'lsa keyin `_durationSub` orqali yangilanadi).
      _updateMediaItem(book, duration: dur);
      // Qolgan joydan davom: saqlangan pozitsiya bo'lsa o'sha yerga o'tamiz
      // (juda boshi/oxiri bo'lsa — noldan). Aks holda 0dan boshlanadi.
      final saved = await _loadSavedPosition(book.id);
      _lastSavedPos = saved ?? Duration.zero;
      if (saved != null &&
          saved > const Duration(seconds: 3) &&
          (dur == null || saved < dur - const Duration(seconds: 5))) {
        await _player.seek(saved);
      }
      await _player.play();
    } catch (e, st) {
      debugPrint('[AudioPlayer] yuklab bo\'lmadi url=$url\n$e\n$st');
      state = state.copyWith(error: "Audioni ijro etib bo'lmadi: $e");
    }
  }

  // ── Qolgan joydan davom (SharedPreferences: audiobook_pos_<id> = soniya) ──

  static String _posKey(String id) => 'audiobook_pos_$id';

  /// Oxirgi saqlangan pozitsiya (5 sekunddan kam farqда qayta yozmaymiz).
  Duration _lastSavedPos = Duration.zero;

  Future<void> _maybeSavePosition(Duration pos) async {
    final book = state.currentBook;
    if (book == null) return;
    // FAQAT haqiqatan IJRO paytida va boshidan uzoqda saqlaymiz. Aks holda
    // `setUrl`/`stop`/`seek` chiqargan 0-pozitsiya saqlangan "davom" nuqtasini
    // o'chirib yuborardi → audio har safar boshidan boshlanardi (bir sessiyada
    // ikkinchi marta o'ynatilganda). Bu 0-emission'lardan himoya.
    if (!_player.playing || pos.inSeconds <= 3) return;
    if ((pos - _lastSavedPos).abs() < const Duration(seconds: 5)) return;
    _lastSavedPos = pos;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_posKey(book.id), pos.inSeconds);
    } catch (_) {}
  }

  Future<Duration?> _loadSavedPosition(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sec = prefs.getInt(_posKey(id));
      if (sec == null || sec <= 0) return null;
      return Duration(seconds: sec);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSavedPosition(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_posKey(id));
    } catch (_) {}
  }

  /// Kitob to'liq tinglandi: DON (backend, idempotent) + pozitsiyani tozalash
  /// (keyingi safar noldan) + statistikani yangilash.
  Future<void> _onBookCompleted(AudiobookModel book) async {
    _lastSavedPos = Duration.zero;
    await _clearSavedPosition(book.id);
    await _ref
        .read(audiobooksBackendRepositoryProvider)
        .reportCompleted(book.id);
    _ref.invalidate(developmentSummaryProvider);
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
    state = state.copyWith(sleepTimerRemaining: Duration(minutes: minutes));

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = state.sleepTimerRemaining;
      if (remaining.inSeconds <= 1) {
        timer.cancel();
        _sleepTimer = null;
        await _player.pause();
        state = state.copyWith(sleepTimerRemaining: Duration.zero);
      } else {
        state = state.copyWith(
          sleepTimerRemaining: Duration(seconds: remaining.inSeconds - 1),
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
