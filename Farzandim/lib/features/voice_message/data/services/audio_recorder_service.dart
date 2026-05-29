import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Mikrofon yozish servisi — `record` paketi ustida ingichka qatlam.
///
/// **Lifecycle:**
/// 1. `startRecording()` — yozish boshlash (mikrofon ruxsati avval
///    [AudioRecorderService.hasPermission] orqali tekshirilishi kerak).
/// 2. Yozish davomida `amplitudeStream` orqali real-time amplitudalar
///    keladi (live waveform uchun).
/// 3. `stopRecording()` — yozish to'xtatish, fayl yo'lini qaytaradi.
/// 4. `cancelRecording()` — yozish to'xtatib, fayl o'chirish.
/// 5. `dispose()` — recorder resurslarini bo'shatish.
///
/// **60 sek max** — `Timer` orqali avtomatik chaqiriladi
/// `onMaxDurationReached` callback (ekran tomon `_stopRecording`
/// chaqiradi).
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _maxDurationTimer;
  String? _currentFilePath;

  /// Maksimal yozish davomiyligi (sekundda).
  static const int maxDurationSeconds = 60;

  /// Hozir yozish davom etyaptimi.
  bool get isRecording => _isRecording;

  /// Mikrofon ruxsati bormi (runtime so'rashdan oldin tekshirish uchun).
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Real-time amplitude stream'i — har 100ms da yangi qiymat.
  ///
  /// `Amplitude.current` — dB qiymati (-60..0). Live waveform widget
  /// `(current + 60) / 60` formulasi bilan 0..1 ga normallashtiradi.
  Stream<Amplitude> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .asBroadcastStream();

  /// Yozishni boshlash.
  ///
  /// `onMaxDurationReached` — 60 sek o'tgach chaqiriladi (timer orqali).
  /// Ekran tomonidan `_stopRecording()` chaqirib yozishni tugatadi.
  ///
  /// Throws: ruxsat yo'q bo'lsa `Exception`.
  Future<void> startRecording({
    required VoidCallback onMaxDurationReached,
  }) async {
    if (_isRecording) return;

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw Exception('Mikrofon ruxsati berilmagan');
    }

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = '${directory.path}/voice_$timestamp.m4a';

    // RecordConfig default'lari shu loyiha uchun mos: AAC LC encoder,
    // 128 kbps, 44.1 kHz — Telegram-style ovozli xabarlar uchun standart.
    await _recorder.start(
      const RecordConfig(),
      path: _currentFilePath!,
    );

    _isRecording = true;

    _maxDurationTimer = Timer(
      const Duration(seconds: maxDurationSeconds),
      onMaxDurationReached,
    );

    debugPrint('AudioRecorder: yozish boshlandi — $_currentFilePath');
  }

  /// Yozishni to'xtatish — fayl yo'lini qaytaradi (yoki `null` agar
  /// yozish boshlanmagan bo'lsa).
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _maxDurationTimer?.cancel();

    final path = await _recorder.stop();
    _isRecording = false;

    debugPrint('AudioRecorder: yozish tugadi — $path');
    return path;
  }

  /// Yozishni bekor qilish — fayl o'chiriladi (faqat shu sessiya'da
  /// yaratilgan tmp fayl).
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _maxDurationTimer?.cancel();

    await _recorder.stop();
    _isRecording = false;

    if (_currentFilePath != null) {
      try {
        await File(_currentFilePath!).delete();
      } catch (_) {
        // Fayl topilmasa ham OK — tmp directory o'zi tozalanadi.
      }
    }
    _currentFilePath = null;
  }

  /// Recorder resurslarini bo'shatish (ekran dispose'ida).
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
