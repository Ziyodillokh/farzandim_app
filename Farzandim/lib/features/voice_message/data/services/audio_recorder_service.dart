import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Mikrofon yozish servisi — `record` paketi ustida ingichka qatlam.
///
/// Yozish davomida `amplitudeStream` live waveform uchun amplitudalar
/// beradi. 60 sekund to'lganda timer `onMaxDurationReached` callback'ini
/// chaqiradi — yozishni tugatish ekran zimmasida.
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

  /// Amplitude stream'i — har 100ms da dB qiymat (-60..0).
  /// Waveform widget buni 0..1 oralig'iga normallashtiradi.
  Stream<Amplitude> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .asBroadcastStream();

  /// Yozishni boshlaydi; ruxsat yo'q bo'lsa `Exception` otadi.
  /// `onMaxDurationReached` 60 sek o'tgach timer orqali chaqiriladi.
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
    await _recorder.start(const RecordConfig(), path: _currentFilePath!);

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
