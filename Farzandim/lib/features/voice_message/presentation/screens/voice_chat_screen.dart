import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:video_compress/video_compress.dart';

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim/features/voice_message/data/services/audio_player_manager.dart';
import 'package:farzandim/features/voice_message/data/services/audio_recorder_service.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_upload_provider.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/round_video_bubble.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/round_video_recorder.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/voice_chat_bubble.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Bola bilan ovozli xabar chati (Telegram/WhatsApp uslubida).
///
/// Ekran ochilganda bola yuborgan barcha sent xabarlar avtomatik
/// `seen` ga o'tadi (`markAllAsSeenByParent`). Stream xabarlar real-time
/// keladi, yangi xabar kelganda auto-scroll pastga.
///
/// **Inline recording** (Bosqich 12'da soddalashtirilgan):
/// pastdagi mic tugmani **bosib turing** — yozish darhol boshlanadi
/// (alohida ekran yo'q). Qo'yib yuborsangiz darhol upload bo'ladi.
/// Bekor qilish uchun chap tomondagi delete tugma (recording paytida
/// faqat ko'rinadi).
class VoiceChatScreen extends ConsumerStatefulWidget {
  /// `VoiceChatScreen` konstruktor.
  const VoiceChatScreen({required this.childId, super.key});

  /// Qaysi bola bilan chat.
  final String childId;

  @override
  ConsumerState<VoiceChatScreen> createState() =>
      _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  // ─── Inline recording state ──────────────────────────────────────
  final AudioRecorderService _recorderService = AudioRecorderService();
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _amplitudes = [];
  DateTime? _recordingStartedAt;
  bool _isCanceled = false;

  /// Min davomiylik (1.5 sek) — bundan kam yozilgan bo'lsa upload
  /// qilinmaydi (snackbar ogohlantirish).
  static const int _minDurationMs = 1500;

  /// Live waveform max bar count (sliding window).
  static const int _maxAmplitudes = 80;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Sprint 4.4.5: voice chat ekrani ochilganda Parent App bola
    // pair'lashganini Backend'dan refresh qiladi (child.linkedDeviceUid
    // yangilanadi). Bu siz voice yuborganda receiverId mavjud bo'lishi
    // uchun kerak.
    //
    // Sprint 4.4.31: shu paytda bola yuborgan barcha unread voice'larni
    // bulk Backend'ga mark qilamiz — UI'da darhol ✓✓ bo'ladi.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.invalidate(childrenProvider);

      // Bola Backend user ID (childUserId) — list'dan widget.childId bo'yicha.
      final children =
          ref.read(childrenProvider).valueOrNull ?? const [];
      String? childUserId;
      for (final c in children) {
        if (c.id == widget.childId) {
          childUserId = c.linkedDeviceUid;
          break;
        }
      }

      try {
        final ok = await ref
            .read(backendVoiceMessageRepositoryProvider)
            .markAllRead(fromUserId: childUserId);
        if (ok) {
          ref.invalidate(voiceMessagesProvider(widget.childId));
        }
      } catch (_) {
        // Silent — bir xabar tap orqali markAsRead fallback bor.
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioPlayerManager.instance.stop();
      if (_isRecording) {
        unawaited(_abortRecording());
      }
    }
    // Foreground'ga qaytganda read receipt yangilanishi uchun refetch.
    if (state == AppLifecycleState.resumed) {
      ref
        ..invalidate(voiceMessagesProvider(widget.childId))
        ..invalidate(videoMessagesProvider(widget.childId));
    }
  }

  Future<void> _onRefresh() async {
    ref
      ..invalidate(voiceMessagesProvider(widget.childId))
      ..invalidate(latestVoiceMessageProvider(widget.childId))
      ..invalidate(unreadVoiceMessagesProvider(widget.childId))
      ..invalidate(videoMessagesProvider(widget.childId));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  void _onInfoPressed() {
    context.push(AppRoutes.qaDevicePath(widget.childId));
  }

  // ─── Recording handlers ──────────────────────────────────────────

  Future<void> _onLongPressStart() async {
    if (_isRecording) return;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('voiceChat.micPermissionSnack'.tr())),
      );
      return;
    }

    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      _amplitudes.clear();
      _isCanceled = false;
      _recordingStartedAt = DateTime.now();

      await _recorderService.startRecording(
        onMaxDurationReached: _onLongPressEnd,
      );

      _amplitudeSub = _recorderService.amplitudeStream.listen((amp) {
        // dB qiymati -60..0 → 0..1 normallashtirish.
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        if (!mounted) return;
        setState(() {
          _amplitudes.add(normalized);
          if (_amplitudes.length > _maxAmplitudes) {
            _amplitudes.removeAt(0);
          }
        });
      });

      _elapsedSeconds = 0;
      _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!mounted) return;
          setState(() => _elapsedSeconds++);
        },
      );

      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _onLongPressEnd() async {
    if (!_isRecording) return;

    _elapsedTimer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final elapsed = _recordingStartedAt != null
        ? DateTime.now()
            .difference(_recordingStartedAt!)
            .inMilliseconds
        : 0;

    final filePath = await _recorderService.stopRecording();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _elapsedSeconds = 0;
    });

    // Bekor qilingan — fayl o'chirib qaytamiz.
    if (_isCanceled) {
      if (filePath != null) {
        try {
          await File(filePath).delete();
        } catch (_) {}
      }
      return;
    }

    if (filePath == null) return;

    // Min davomiylikdan kam — fayl o'chirib snackbar.
    if (elapsed < _minDurationMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('voiceChat.tooShortSnack'.tr()),
          duration: const Duration(seconds: 2),
        ),
      );
      try {
        await File(filePath).delete();
      } catch (_) {}
      return;
    }

    // ─── DARHOL UPLOAD ───
    final waveform = List<double>.from(_amplitudes);
    final durationSeconds = (elapsed / 1000).round();

    // childName build paytida o'qilgan — recording paytida bola
    // o'zgarmasligi kerak (chat bir bola uchun).
    final child = ref.read(childByIdProvider(widget.childId));
    final childName = child?.name ?? 'voiceChat.fallbackChildName'.tr();

    final messageId =
        await ref.read(voiceUploadProvider.notifier).send(
              childId: widget.childId,
              childName: childName,
              localFilePath: filePath,
              durationSeconds: durationSeconds,
              waveform: waveform,
            );

    if (!mounted) return;

    if (messageId != null) {
      // Muvaffaqiyatli — fayl o'chirib state reset.
      try {
        await File(filePath).delete();
      } catch (_) {}
      ref.read(voiceUploadProvider.notifier).reset();

      // Auto-scroll bottom (yangi xabar pastda).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else {
      final state = ref.read(voiceUploadProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ?? 'voiceChat.sendErrorDefault'.tr(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Foydalanuvchi delete tugmani bossa: cancel bayrog'i + stop.
  /// `_onLongPressEnd` `_isCanceled` ni tekshiradi va upload qilmaydi.
  Future<void> _abortRecording() async {
    _isCanceled = true;
    await _onLongPressEnd();
  }

  // ─── Round video recorder (Telegram uslubidagi) ──────────────────

  /// Yumaloq video modalini ochadi, tugagach client-side compress qilib
  /// upload qiladi (Backend 413 oldini olish — Sprint 4.4.34).
  Future<void> _onVideoRecordPressed() async {
    // Voice recording davom etayotgan bo'lsa avval to'xtatamiz.
    if (_isRecording) {
      _isCanceled = true;
      await _onLongPressEnd();
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
    try {
      final info = await VideoCompress.compressVideo(
        original.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info != null && info.path != null) {
        fileToUpload = File(info.path!);
        debugPrint(
          'VideoCompress: ${original.lengthSync()} → ${fileToUpload.lengthSync()} bytes',
        );
      }
    } catch (e) {
      debugPrint('VideoCompress xato — original yuborilmoqda: $e');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final ok = await ref.read(videoUploadProvider.notifier).send(
          childId: widget.childId,
          videoFile: fileToUpload,
        );

    if (!mounted) return;

    if (ok) {
      // Fayllarni o'chiramiz (compress + original — kerak emas).
      try {
        await original.delete();
      } catch (_) {}
      if (fileToUpload.path != original.path) {
        try {
          await fileToUpload.delete();
        } catch (_) {}
      }
      ref.read(videoUploadProvider.notifier).reset();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      final state = ref.read(videoUploadProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ?? 'voiceChat.sendErrorDefault'.tr(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorderService.dispose();
    AudioPlayerManager.instance.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childByIdProvider(widget.childId));
    final childName = child?.name ?? 'voiceChat.fallbackChildName'.tr();
    // Voice + video birlashtirilgan lenta (ASC).
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _ChatHeader(
                childName: childName,
                avatar: child != null
                    ? ChildAvatar(
                        child: child,
                        size: 40,
                        showBorder: false,
                      )
                    : const _FallbackAvatar(),
                onBack: () => context.pop(),
                onInfo: _onInfoPressed,
              ),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return _EmptyChat(
                        childName: childName,
                        onRefresh: _onRefresh,
                      );
                    }

                    // Yangi xabar kelganda auto-scroll bottom.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    return RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final item = messages[i];
                          // Sealed switch — yangi tip qo'shilsa
                          // exhaustive xato beradi.
                          return switch (item) {
                            VoiceItem(:final message) => VoiceChatBubble(
                                key: ValueKey(item.id),
                                message: message,
                                isOwn: message.sender == 'parent',
                              ),
                            VideoItem(:final message) => RoundVideoBubble(
                                key: ValueKey(item.id),
                                message: message,
                                isOwn: message.sender == 'parent',
                              ),
                          };
                        },
                      ),
                    );
                  },
                  loading: () => const _ChatLoadingSkeleton(),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        'voiceChat.errorPrefix'.tr(
                          namedArgs: {'error': '$e'},
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Input bar ───────────────────────────────────────────────────
  //
  // **Bug fix:** ilgari idle/recording uchun 2 ta alohida widget bor
  // edi. `setState`'da idle GestureDetector destroy bo'lib mid-gesture
  // long-press subscription yo'qolardi → `onLongPressEnd` chaqirilmas
  // edi. Endi bitta `Row` — mic GestureDetector stable pozitsiyada
  // (har doim oxirgi child) + `ValueKey` element preservation uchun.
  // Recording paytida atrofidagi UI o'zgaradi (delete + indicator
  // paydo bo'ladi), lekin gesture saqlanadi.

  Widget _buildInputBar() {
    final isUploading =
        ref.watch(voiceUploadProvider).status == UploadStatus.uploading;
    final isVideoUploading = ref.watch(videoUploadProvider).status ==
        VideoUploadStatus.uploading;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm + 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // [0] Delete tugma (recording) yoki bo'sh — pozitsiya stable.
          // `if-else` collection element: ro'yxat uzunligi har holatda
          // bir xil (1 element), ternary o'rniga lint-friendly.
          if (_isRecording)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 28,
              ),
              onPressed: _abortRecording,
              tooltip: 'voiceChat.cancelTooltip'.tr(),
            )
          else
            const SizedBox.shrink(),

          // [1] Markaziy joy: indicator (recording) yoki bo'sh filler.
          Expanded(
            child: _isRecording
                ? _RecordingIndicator(
                    elapsedSeconds: _elapsedSeconds,
                    amplitudes: _amplitudes,
                  )
                : const SizedBox.shrink(),
          ),

          // [2] Recording paytida 12px gap, idle holatda 0.
          SizedBox(width: _isRecording ? 12 : 0),

          // [2.5] Video record tugmasi — faqat idle holatda ko'rinadi
          // (recording paytida UI'ni soddalashtirib turamiz).
          if (!_isRecording) ...[
            _VideoRecordButton(
              isUploading: isVideoUploading,
              onPressed: isUploading || isVideoUploading
                  ? null
                  : _onVideoRecordPressed,
            ),
            const SizedBox(width: 12),
          ],

          // [3] Mic GestureDetector — har doim shu pozitsiyada.
          // ValueKey element matching kafolatlaydi: state o'zgarsa ham
          // Flutter eski elementni qaytadan ishlatadi → long-press
          // subscription saqlanadi va `onLongPressEnd` chaqiriladi.
          GestureDetector(
            key: const ValueKey('voice-mic-button'),
            behavior: HitTestBehavior.opaque,
            // Sprint 4.4.5: ikki UX qo'llab-quvvatlanadi:
            // - Tap (qisqa bosish): toggle (start yoki stop+send)
            // - Long press (bosib turish): bosgan paytda recording,
            //   qo'yib yuborganda send (klassik WhatsApp/Telegram UX)
            // Flutter GestureRecognizer ikkalasini parallel sezadi.
            onTap: isUploading
                ? null
                : () {
                    if (_isRecording) {
                      _onLongPressEnd();
                    } else {
                      _onLongPressStart();
                    }
                  },
            onLongPressStart:
                isUploading ? null : (_) => _onLongPressStart(),
            onLongPressEnd:
                isUploading ? null : (_) => _onLongPressEnd(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: _isRecording
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isUploading
                            ? [
                                AppColors.primary.withValues(alpha: 0.6),
                                AppColors.primaryDark.withValues(alpha: 0.6),
                              ]
                            : const [
                                Color(0xFFD0FF6E),
                                Color(0xFFA3CE4F),
                              ],
                      ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? const Color(0xFFFF5252)
                            : AppColors.primary)
                        .withValues(alpha: _isRecording ? 0.5 : 0.4),
                    blurRadius: _isRecording ? 24 : 18,
                    spreadRadius: _isRecording ? 4 : 2,
                  ),
                ],
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      ),
                    )
                  : Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color:
                          _isRecording ? Colors.white : Colors.black,
                      size: 40,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recording paytidagi waveform + timer + qizil dot bo'lim.
///
/// Faqat ko'rinish — gesture'lar tashqi `GestureDetector`'da. Shu
/// widget atrofidagi UI rebuild bo'lganda mic gesture'iga ta'sir
/// qilmaydi.
class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsedSeconds,
    required this.amplitudes,
  });

  final int elapsedSeconds;
  final List<double> amplitudes;

  @override
  Widget build(BuildContext context) {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
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
            '$m:$s',
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 24,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                reverse: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: amplitudes.length,
                itemBuilder: (_, i) {
                  final amp = amplitudes[amplitudes.length - 1 - i];
                  final h = (amp * 24).clamp(2.0, 24.0);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 1),
                    child: Center(
                      child: Container(
                        width: 2.5,
                        height: h,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yumaloq video xabar yozish tugmasi (mic yonida).
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surface,
              AppColors.surfaceVariant,
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.7),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 14,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
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
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.childName,
    required this.avatar,
    required this.onBack,
    required this.onInfo,
  });

  final String childName;
  final Widget avatar;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
            ),
            onPressed: onBack,
          ),
          avatar,
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  childName,
                  style: AppTextStyles.bodyM.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'voiceChat.headerSubtitle'.tr(),
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: AppColors.textPrimary,
            ),
            onPressed: onInfo,
          ),
        ],
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.childName, required this.onRefresh});

  final String childName;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator ListView yoki scrollable child kutadi —
    // empty holatda ham swipe ishlashi uchun SingleChildScrollView'ga
    // o'rab qo'yamiz (always-scrollable physics bilan).
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_outlined,
                      size: 50,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  Text(
                    'voiceChat.emptyTitle'.tr(),
                    style: AppTextStyles.headlineL.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'voiceChat.emptySubtitle'.tr(
                      namedArgs: {'name': childName},
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatLoadingSkeleton extends StatelessWidget {
  const _ChatLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    // Aralash o'ng/chap bubble shaklidagi 3 ta placeholder. Stream
    // tez yuklanadi, shuning uchun bu kamdan-kam ko'rinadi (sekin
    // internetda foydali).
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 3,
      itemBuilder: (_, i) {
        final isOwn = i.isEven;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: Row(
            mainAxisAlignment:
                isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isOwn) const Spacer(),
              Flexible(
                flex: 4,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (!isOwn) const Spacer(),
            ],
          ),
        );
      },
    );
  }
}
