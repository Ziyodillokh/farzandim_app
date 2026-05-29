// ─────────────────────────────────────────────────────────────────────
// VoiceChatScreen — Telegram/WhatsApp-style ovozli + video xabar suhbati
// ─────────────────────────────────────────────────────────────────────
//
// Inline recording: chat ekran ichida mic tugmani bossib turish bilan
// yozish boshlanadi. Qo'yib yuborilsa darhol upload, chap delete tugma
// bilan bekor qilinadi.
//
// Yumaloq video xabar (Sprint 4.4.18 port): chap tomondagi videocam
// tugma — tap bilan to'liq ekran modal (Telegram-style) ochiladi,
// long-press bilan yoziladi, qo'yib yuborilganda compress + upload.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim_child/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim_child/features/voice_message/data/services/audio_player_manager.dart';
import 'package:farzandim_child/features/voice_message/data/services/audio_recorder_service.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/voice_message_provider.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/chat_bubble.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/round_video_bubble.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/round_video_recorder.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with WidgetsBindingObserver {
  static const int _minDurationMs = 1500;
  static const int _maxBars = 80;

  final ScrollController _scrollController = ScrollController();
  final AudioRecorderService _service = AudioRecorderService();

  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _amplitudes = [];
  DateTime? _recordingStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Sprint 4.4.31: chat ochilganda barcha Parent'dan kelgan unread
    // xabarlarni bulk Backend'ga mark qilamiz — UI darhol ✓✓ bo'ladi.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pairing = ref.read(pairingStateProvider);
      if (pairing.parentUid == null || pairing.childId == null) return;
      try {
        final ok = await ref
            .read(backendVoiceMessageRepositoryProvider)
            .markAllRead(fromUserId: pairing.parentUid);
        if (ok) {
          ref.invalidate(voiceMessagesProvider);
        }
      } catch (e) {
        debugPrint('markAllRead error: $e');
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ─── Voice recording handlers ────────────────────────────────────

  Future<void> _onLongPressStart() async {
    if (_isRecording) return;

    final uploadStatus = ref.read(voiceMessageUploadProvider).status;
    if (uploadStatus == VoiceUploadStatus.uploading) return;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('voiceChat.micPermission'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _amplitudes.clear();
      _recordingStartedAt = DateTime.now();

      await _service.startRecording(
        onMaxDurationReached: () => unawaited(_stopRecording()),
      );

      _amplitudeSub = _service.amplitudeStream.listen((amp) {
        final normalized =
            ((amp.current + 60) / 60).clamp(0.0, 1.0).toDouble();
        if (!mounted) return;
        setState(() {
          _amplitudes.add(normalized);
          if (_amplitudes.length > _maxBars) {
            _amplitudes.removeAt(0);
          }
        });
      });

      _elapsedSeconds = 0;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });

      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Audio recording error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _onLongPressEnd() {
    if (_isRecording) unawaited(_stopRecording());
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _elapsedTimer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final elapsed = _recordingStartedAt != null
        ? DateTime.now().difference(_recordingStartedAt!).inMilliseconds
        : 0;

    final filePath = await _service.stopRecording();

    if (!mounted) return;
    final waveformSnapshot = List<double>.from(_amplitudes);
    setState(() {
      _isRecording = false;
      _elapsedSeconds = 0;
    });

    if (filePath == null) return;

    if (elapsed < _minDurationMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('voiceChat.tooShort'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return;
    }

    final ok =
        await ref.read(voiceMessageUploadProvider.notifier).send(
              audioFile: File(filePath),
              durationSeconds: (elapsed / 1000).round(),
              waveform: waveformSnapshot,
            );

    if (!mounted) return;
    if (ok) {
      ref.read(voiceMessageUploadProvider.notifier).reset();
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      // Auto-scroll bottom (yangi xabar pastda).
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      final err = ref.read(voiceMessageUploadProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'voiceChat.errorPrefix'.tr(
              namedArgs: {
                'error': err ?? 'voiceChat.sendErrorFallback'.tr(),
              },
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _abortRecording() async {
    _elapsedTimer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _service.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _elapsedSeconds = 0;
        _amplitudes.clear();
      });
    }
  }

  // ─── Round video recorder (Telegram-uslubi) ──────────────────────

  /// Yumaloq video modalini ochadi, tugagach client-side compress qilib
  /// upload qiladi (Backend 413 oldini olish — Sprint 4.4.34).
  Future<void> _onVideoRecordPressed() async {
    // Voice recording davom etayotgan bo'lsa avval to'xtatamiz.
    if (_isRecording) {
      await _abortRecording();
    }
    if (!mounted) return;

    final xfile = await showRoundVideoRecorder(context);
    if (xfile == null) return;
    if (!mounted) return;

    final original = File(xfile.path);

    // Compress UI feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Video tayyorlanmoqda...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    File fileToUpload = original;
    int? durationSeconds;
    try {
      final info = await VideoCompress.compressVideo(
        original.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info != null && info.path != null) {
        fileToUpload = File(info.path!);
        durationSeconds = info.duration != null
            ? (info.duration! / 1000).round()
            : null;
        debugPrint(
          'VideoCompress: ${original.lengthSync()} → ${fileToUpload.lengthSync()} bytes',
        );
      }
    } catch (e) {
      debugPrint('VideoCompress xato — original yuborilmoqda: $e');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final ok =
        await ref.read(videoMessageUploadProvider.notifier).send(
              videoFile: fileToUpload,
              durationSeconds: durationSeconds ?? 0,
            );

    if (!mounted) return;

    if (ok) {
      try {
        await original.delete();
      } catch (_) {}
      if (fileToUpload.path != original.path) {
        try {
          await fileToUpload.delete();
        } catch (_) {}
      }
      ref.read(videoMessageUploadProvider.notifier).reset();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      final state = ref.read(videoMessageUploadProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'voiceChat.errorPrefix'.tr(
              namedArgs: {
                'error':
                    state.errorMessage ?? 'voiceChat.sendErrorFallback'.tr(),
              },
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isRecording) {
      unawaited(_abortRecording());
    }
    // Foreground'ga qaytganda voice + video providerlarni refresh.
    if (state == AppLifecycleState.resumed) {
      ref
        ..invalidate(voiceMessagesProvider)
        ..invalidate(videoMessagesProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    _amplitudeSub?.cancel();
    _service.dispose();
    AudioPlayerManager.instance.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Voice + video birlashtirilgan lenta (ASC).
    final messagesAsync = ref.watch(chatMessagesProvider);
    final voiceUpload = ref.watch(voiceMessageUploadProvider).status;
    final videoUpload = ref.watch(videoMessageUploadProvider).status;
    final isVoiceUploading = voiceUpload == VoiceUploadStatus.uploading;
    final isVideoUploading = videoUpload == UploadStatus.uploading;

    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBottom,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              // ignore: deprecated_member_use
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: const Icon(
                AppIcons.profile,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'voiceChat.headerParent'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'voiceChat.headerSubtitle'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) return const _EmptyState();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final item = messages[i];
                    // Sealed switch — exhaustive (yangi tip qo'shilsa
                    // compiler xato beradi).
                    return switch (item) {
                      VoiceItem(:final message) => ChatBubble(
                          key: ValueKey(item.id),
                          message: message,
                          isOwn: message.sender == 'child',
                        ),
                      VideoItem(:final message) => RoundVideoBubble(
                          key: ValueKey(item.id),
                          message: message,
                          isOwn: message.sender == 'child',
                        ),
                    };
                  },
                );
              },
              loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'voiceChat.errorPrefix'.tr(
                      namedArgs: {'error': '$e'},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
          _ChatInputBar(
            isRecording: _isRecording,
            isUploading: isVoiceUploading,
            isVideoUploading: isVideoUploading,
            elapsedSeconds: _elapsedSeconds,
            amplitudes: _amplitudes,
            onLongPressStart: () => unawaited(_onLongPressStart()),
            onLongPressEnd: _onLongPressEnd,
            onCancel: () => unawaited(_abortRecording()),
            onVideoPressed: isVoiceUploading || isVideoUploading
                ? null
                : () => unawaited(_onVideoRecordPressed()),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // FARO faceIdle — "tinch holatda, javob kutmoqda" feel
    return EmptyStateMascot(
      faroVariant: FaroVariant.faceIdle,
      title: 'voiceChat.emptyTitle'.tr(),
      subtitle: 'voiceChat.emptySubtitle'.tr(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Input bar — Telegram/WhatsApp-style mic + premium video tugma
// ─────────────────────────────────────────────────────────────────────
//
// Mic gesture'i widget tree'da DOIMO bir xil pozitsiyada (oxirgi child)
// — recording boshlangach faqat atrofidagi UI o'zgaradi. Aks holda
// Flutter eski subscription'ni yo'qotib, `onLongPressEnd` chaqirilmaydi.

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.isRecording,
    required this.isUploading,
    required this.isVideoUploading,
    required this.elapsedSeconds,
    required this.amplitudes,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onCancel,
    required this.onVideoPressed,
  });

  final bool isRecording;
  final bool isUploading;
  final bool isVideoUploading;
  final int elapsedSeconds;
  final List<double> amplitudes;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback onCancel;
  final VoidCallback? onVideoPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundBottom,
        border: Border(
          top: BorderSide(
            // ignore: deprecated_member_use
            color: AppColors.textSecondary.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isRecording)
              IconButton(
                onPressed: onCancel,
                icon: const Icon(
                  AppIcons.delete,
                  color: Colors.red,
                  size: 28,
                ),
              ),
            if (isRecording)
              Expanded(
                child: _RecordingIndicator(
                  elapsedSeconds: elapsedSeconds,
                  amplitudes: amplitudes,
                ),
              )
            else
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Mikrofonni bosing — boshlash/to\'xtatish',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            // Video record tugmasi — faqat idle holatda ko'rinadi
            // (recording paytida UI'ni soddalashtirib turamiz).
            if (!isRecording) ...[
              const SizedBox(width: 8),
              _VideoRecordButton(
                isUploading: isVideoUploading,
                onPressed: onVideoPressed,
              ),
            ],
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('voice-mic-button'),
              behavior: HitTestBehavior.opaque,
              // Sprint 4.4.5: ikkala UX (tap toggle + long press).
              onTap: isUploading
                  ? null
                  : () {
                      if (isRecording) {
                        onLongPressEnd();
                      } else {
                        onLongPressStart();
                      }
                    },
              onLongPressStart:
                  isUploading ? null : (_) => onLongPressStart(),
              onLongPressEnd: isUploading ? null : (_) => onLongPressEnd(),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: isRecording
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.catRed, AppColors.catRedDark],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isUploading
                              ? [
                                  // ignore: deprecated_member_use
                                  AppColors.primary.withOpacity(0.6),
                                  // ignore: deprecated_member_use
                                  AppColors.primary.withOpacity(0.4),
                                ]
                              : const [
                                  AppColors.catLime,
                                  AppColors.primaryHover,
                                ],
                        ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? AppColors.catRed
                              : AppColors.primary)
                          // ignore: deprecated_member_use
                          .withOpacity(isRecording ? 0.5 : 0.4),
                      blurRadius: isRecording ? 24 : 18,
                      spreadRadius: isRecording ? 4 : 2,
                    ),
                  ],
                ),
                child: isUploading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : Icon(
                        isRecording
                            ? AppIcons.stop
                            : AppIcons.mic,
                        color: isRecording ? Colors.white : Colors.black,
                        size: 40,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsedSeconds,
    required this.amplitudes,
  });

  final int elapsedSeconds;
  final List<double> amplitudes;

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _format(elapsedSeconds),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 28,
              child: _InlineWaveform(amplitudes: amplitudes),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWaveform extends StatelessWidget {
  const _InlineWaveform({required this.amplitudes});

  final List<double> amplitudes;

  @override
  Widget build(BuildContext context) {
    if (amplitudes.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: amplitudes.length,
      itemBuilder: (_, i) {
        final amp = amplitudes[amplitudes.length - 1 - i];
        final h = (amp * 28).clamp(2.0, 28.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Center(
            child: Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Premium yumaloq video xabar yozish tugmasi (mic yonida).
///
/// Parent App'dagi `_VideoRecordButton` bilan vizual mos:
/// surface gradient + double shadow + lime border + ShaderMask icon.
class _VideoRecordButton extends StatelessWidget {
  const _VideoRecordButton({
    required this.isUploading,
    required this.onPressed,
  });

  final bool isUploading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              AppColors.surfaceVariant,
            ],
          ),
          border: Border.all(
            // ignore: deprecated_member_use
            color: AppColors.primary.withOpacity(0.7),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: AppColors.primary.withOpacity(0.22),
              blurRadius: 14,
              spreadRadius: 1,
            ),
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isUploading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              )
            : ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(rect),
                child: const Icon(
                  AppIcons.video,
                  color: Colors.white,
                  size: 28,
                ),
              ),
      ),
    );
  }
}
