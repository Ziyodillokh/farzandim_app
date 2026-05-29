// ─────────────────────────────────────────────────────────────────────
// AudioPlayerManager — Voice chat uchun singleton audio player
// ─────────────────────────────────────────────────────────────────────
//
// Bir vaqtda faqat 1 ta xabar play bo'ladi. Cross-bubble switching:
// boshqa bubble tap qilinsa eski to'xtaydi, yangi boshlanadi.
// `currentIdStream` UI'ga qaysi xabar play bo'layotganini bildiradi.
//
// Speed control: `toggleSpeed` 1.0 → 1.5 → 2.0 → 1.0 cycle. Tanlangan
// tezlik keyingi xabarlar uchun ham saqlanadi.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerManager {
  AudioPlayerManager._() {
    // Tugagach state'ni reset qilamiz — barcha kuzatuvchilar
    // (UI bubble'lar) avtomatik play→pause holatga o'tadi.
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _currentMessageId = null;
        _currentIdController.add(null);
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  static final AudioPlayerManager instance = AudioPlayerManager._();

  final AudioPlayer _player = AudioPlayer();
  final StreamController<String?> _currentIdController =
      StreamController<String?>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();

  String? _currentMessageId;
  double _speed = 1.0;

  Stream<String?> get currentIdStream => _currentIdController.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _speedController.stream;

  String? get currentMessageId => _currentMessageId;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  double get speed => _speed;

  /// Play yoki toggle. Agar `messageId` hozirgi xabar bo'lsa pause/resume,
  /// aks holda eskisini stop qilib yangisini yuklaydi va play qiladi.
  /// Xato bo'lsa exception throw qiladi — UI catch qilib SnackBar ko'rsatadi.
  Future<void> playOrToggle({
    required String messageId,
    required String audioUrl,
  }) async {
    if (_currentMessageId == messageId) {
      if (_player.playing) {
        await _player.pause();
      } else {
        final dur = _player.duration;
        if (dur != null && _player.position >= dur) {
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
      debugPrint('AudioPlayerManager error: $e');
      _currentMessageId = null;
      _currentIdController.add(null);
      rethrow;
    }
  }

  /// Speed cycle: 1.0 → 1.5 → 2.0 → 1.0.
  Future<void> toggleSpeed() async {
    if (_speed == 1.0) {
      _speed = 1.5;
    } else if (_speed == 1.5) {
      _speed = 2.0;
    } else {
      _speed = 1.0;
    }
    await _player.setSpeed(_speed);
    _speedController.add(_speed);
  }

  /// Speed'ni qo'lda o'rnatish (kelajakda ishlatish uchun).
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setSpeed(speed);
    _speedController.add(_speed);
  }

  /// To'xtatish (chat ekrandan chiqayotganda chaqiriladi).
  Future<void> stop() async {
    await _player.stop();
    _currentMessageId = null;
    _currentIdController.add(null);
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _currentIdController.close();
    await _speedController.close();
  }
}
