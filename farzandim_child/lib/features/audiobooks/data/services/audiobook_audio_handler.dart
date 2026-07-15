// ─────────────────────────────────────────────────────────────────────
// AudiobookAudioHandler — audiokitob uchun background audio (lock-screen +
// bildirishnoma boshqaruvi), FAQAT audiokitob player'iga bog'langan.
// ─────────────────────────────────────────────────────────────────────
//
// MUHIM — nega `just_audio_background` emas: o'sha paket global
// `JustAudioPlatform.instance`ni almashtirib, BUTUN ilova bo'yicha FAQAT
// BITTA `just_audio.AudioPlayer()` instansiyasiga ruxsat beradi ("just_audio_
// background supports only a single player instance" — ikkinchisi
// yaratilganda PlatformException otadi). Bu ilovada esa IKKITA mustaqil
// `just_audio` player bor: bu (audiokitob) va ovozli xabar chat
// (`voice_message/data/services/audio_player_manager.dart`, alohida
// singleton). Avval xuddi shu paket yoqilgan edi va chat/ilova bo'yicha
// audio "jim qolib" (duration 0) buzilgan edi — global almashtirish
// ikkinchi player yaratilganda yiqilgan, deb aniqlandi (`main.dart`dagi
// eslatma bilan mos). Shu sababli bu yerda `audio_service`ning o'zi bilan
// (past darajali, platformani ALMASHTIRMAYDI) CUSTOM handler yozilgan —
// faqat SHU bitta player'ni background service + lock-screen
// bildirishnomasiga ulaydi, chat player'iga umuman tegmaydi.
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AudiobookAudioHandler extends BaseAudioHandler with SeekHandler {
  AudiobookAudioHandler(this._player) {
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object _, StackTrace _) {},
    );
    _player.playingStream.listen((_) => _broadcastState());
  }

  final AudioPlayer _player;

  /// Yangi kitob boshlanganda (yoki duration aniqlanganda) lock-screen
  /// kartochkasini yangilash.
  void setMediaItem(MediaItem item) => mediaItem.add(item);

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() =>
      _player.seek(_player.position + const Duration(seconds: 15));

  @override
  Future<void> rewind() {
    final target = _player.position - const Duration(seconds: 15);
    return _player.seek(target > Duration.zero ? target : Duration.zero);
  }

  @override
  Future<void> stop() async {
    await _player.pause();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
  }
}
