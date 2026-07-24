// ─────────────────────────────────────────────────────────────────────
// AudioRecorderService — Telegram-style audio xabar
// ─────────────────────────────────────────────────────────────────────
//
// AAC LC encoder, 128 kbps, 44.1 kHz — kichik fayl, sifatli ovoz.
// 60 sek max davomiylik. `amplitudeStream` waveform UI uchun.

import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  static const int maxDurationSeconds = 60;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _maxDurationTimer;
  String? _currentFilePath;

  bool get isRecording => _isRecording;

  /// Decibel amplitude stream (waveform vizualizatsiya uchun).
  /// `record` paket single-subscription stream qaytaradi — bir nechta
  /// recording urinishi orasida `Bad state: Stream has already been
  /// listened to` xatoga olib keladi. `asBroadcastStream` bu muammoni
  /// hal qiladi (har subscription mustaqil bo'ladi).
  Stream<Amplitude> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .asBroadcastStream();

  Future<void> startRecording({
    required VoidCallback onMaxDurationReached,
  }) async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('voiceChat.micPermission'.tr());
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = '${directory.path}/voice_$timestamp.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentFilePath!,
    );

    _isRecording = true;

    _maxDurationTimer = Timer(
      const Duration(seconds: maxDurationSeconds),
      onMaxDurationReached,
    );

    debugPrint('AudioRecorder: yozish boshlandi — $_currentFilePath');
  }

  /// Yozishni to'xtatadi va `.m4a` fayl yo'lini qaytaradi.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _maxDurationTimer?.cancel();
    final path = await _recorder.stop();
    _isRecording = false;

    debugPrint('AudioRecorder: yozish tugadi — $path');
    return path;
  }

  /// Yozishni bekor qilish — fayl darhol o'chiriladi.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _maxDurationTimer?.cancel();
    await _recorder.stop();
    _isRecording = false;

    if (_currentFilePath != null) {
      try {
        final file = File(_currentFilePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // ignore
      }
    }
    _currentFilePath = null;
  }

  Future<void> dispose() async {
    _maxDurationTimer?.cancel();
    if (_isRecording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    await _recorder.dispose();
  }
}
