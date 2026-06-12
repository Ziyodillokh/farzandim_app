import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Singleton — bir vaqtda faqat bitta xabar o'ynashi uchun.
///
/// Yangi xabar play bosilsa, oldingi avtomatik to'xtaydi. Tugaganda
/// position 0'ga qaytariladi va keyingi tap'da yangidan boshlanadi.
///
/// Audio session `speech` rejimida sozlangan — zvonok yoki boshqa audio
/// kelganda player avtomatik pause bo'ladi. Auto-resume bermaymiz:
/// bola ovozi ochiq joyda to'satdan o'ynab ketmasin.
class AudioPlayerManager {
  AudioPlayerManager._() {
    unawaited(_initSession());
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _currentMessageId = null;
        _currentIdController.add(null);
        _player
          ..seek(Duration.zero)
          ..pause();
      }
    });
  }

  static final AudioPlayerManager instance = AudioPlayerManager._();

  /// Audio session sozlash: zvonok yoki boshqa audio kelganda pause.
  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      session.interruptionEventStream.listen((event) {
        if (event.begin && _player.playing) {
          _player.pause();
        }
        // Auto-resume yo'q — foydalanuvchi qo'lda davom ettiradi
        // (bola ovozi to'satdan boshlanmasligi uchun).
      });
    } catch (e) {
      // Session konfiguratsiyasi xato bersa player baribir ishlaydi —
      // faqat interruption auto-pause bo'lmaydi.
      debugPrint('AudioSession init error: $e');
    }
  }

  final AudioPlayer _player = AudioPlayer();
  String? _currentMessageId;
  double _speed = 1;

  final StreamController<String?> _currentIdController =
      StreamController<String?>.broadcast();

  /// Hozir o'ynayotgan xabar ID'si stream'i (`null` — o'ynamayapti).
  Stream<String?> get currentIdStream => _currentIdController.stream;

  final StreamController<double> _speedController =
      StreamController<double>.broadcast();

  /// Hozirgi tezlik stream'i (1.0 / 1.5 / 2.0).
  Stream<double> get speedStream => _speedController.stream;

  /// Joriy ijro pozitsiyasi.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Audio umumiy davomiyligi (`null` — hali yuklanmagan).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Player state'i (playing/paused/loading/buffering/completed).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Hozir o'ynayotgan xabar ID'si.
  String? get currentMessageId => _currentMessageId;

  /// Hozir o'ynayaptimi (sync read).
  bool get isPlaying => _player.playing;

  /// Hozirgi tezlik (sync read).
  double get speed => _speed;

  /// Xabarni o'ynatish yoki to'xtatish (toggle).
  ///
  /// Agar shu xabar allaqachon o'ynayotgan bo'lsa — pause/resume.
  /// Boshqa xabar bosilsa — eski to'xtab, yangisi boshlanadi.
  Future<void> playOrToggle({
    required String messageId,
    required String audioUrl,
  }) async {
    if (_currentMessageId == messageId) {
      if (_player.playing) {
        await _player.pause();
      } else {
        // Tugagan bo'lsa boshidan boshlaymiz.
        if (_player.position >= (_player.duration ?? Duration.zero)) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      }
      return;
    }

    await _player.stop();
    _currentMessageId = messageId;
    _currentIdController.add(messageId);

    try {
      await _player.setUrl(audioUrl);
      await _player.setSpeed(_speed);
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayer error: $e');
      _currentMessageId = null;
      _currentIdController.add(null);
      rethrow;
    }
  }

  /// Tezlikni 1× → 1.5× → 2× → 1× tartibida aylantiradi.
  Future<void> toggleSpeed() async {
    if (_speed == 1) {
      _speed = 1.5;
    } else if (_speed == 1.5) {
      _speed = 2;
    } else {
      _speed = 1;
    }
    await _player.setSpeed(_speed);
    _speedController.add(_speed);
  }

  /// Player'ni butunlay to'xtatadi (chat ekrandan chiqishda).
  Future<void> stop() async {
    await _player.stop();
    _currentMessageId = null;
    _currentIdController.add(null);
  }
}
