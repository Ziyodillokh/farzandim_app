import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:video_compress/video_compress.dart';

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
import 'package:farzandim/features/voice_message/presentation/screens/chat_settings_screen.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/chat_background.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/chat_input_bar.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/round_video_bubble.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/round_video_recorder.dart';
import 'package:farzandim/features/voice_message/presentation/widgets/voice_chat_bubble.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  // PERF-05: amplitude yangilanishi BUTUN ekranni emas, faqat input bar
  // waveform'ini qayta chizadi (ChatInputBar.amplitudeTick).
  final ValueNotifier<int> _ampTick = ValueNotifier<int>(0);
  DateTime? _recordingStartedAt;
  bool _isCanceled = false;

  /// Media (rasm/hujjat) yuklanmoqda — input bar attach tugmasi spinner.
  bool _isMediaUploading = false;

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChatSettingsScreen(),
      ),
    );
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
        // PERF-05: setState EMAS — 10Hz'da butun ekran (xabarlar ListView +
        // header) rebuild bo'lardi. Tick faqat waveform'ni qayta chizadi.
        _amplitudes.add(normalized);
        if (_amplitudes.length > _maxAmplitudes) {
          _amplitudes.removeAt(0);
        }
        _ampTick.value++;
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

  // ─── Telegram-style matn yuborish ────────────────────────────────
  // Backend POST /voice-messages/text → Socket.io receiver'ga emit.
  // Provider invalidate qilib ListView'ga yangi bubble qo'shamiz.
  Future<void> _sendTextMessage(String text) async {
    final receiverId = _resolveReceiverId();
    if (receiverId == null) {
      _showError('voiceChat.sendErrorDefault'.tr());
      return;
    }
    try {
      await ref
          .read(backendVoiceMessageRepositoryProvider)
          .sendText(receiverId: receiverId, text: text);
      ref.invalidate(voiceMessagesProvider(widget.childId));
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      _showError('voiceChat.sendErrorDefault'.tr());
    }
  }

  // ─── Media (rasm / hujjat) tanlash + yuborish ────────────────────
  Future<void> _pickGallery() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (x != null) await _sendMediaFile(File(x.path));
    } catch (_) {
      _showError('voiceChat.mediaSendError'.tr());
    }
  }

  Future<void> _pickCamera() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (x != null) await _sendMediaFile(File(x.path));
    } catch (_) {
      _showError('voiceChat.mediaSendError'.tr());
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path != null) await _sendMediaFile(File(path));
    } catch (_) {
      _showError('voiceChat.mediaSendError'.tr());
    }
  }

  Future<void> _sendMediaFile(File file) async {
    final receiverId = _resolveReceiverId();
    if (receiverId == null) {
      _showError('voiceChat.mediaSendError'.tr());
      return;
    }
    setState(() => _isMediaUploading = true);
    try {
      await ref.read(backendVoiceMessageRepositoryProvider).sendMedia(
            receiverId: receiverId,
            file: file,
          );
      ref.invalidate(voiceMessagesProvider(widget.childId));
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      _showError('voiceChat.mediaSendError'.tr());
    } finally {
      if (mounted) setState(() => _isMediaUploading = false);
    }
  }

  /// Bola Backend user ID (receiverId) — pair qilinmagan bo'lsa `null`.
  String? _resolveReceiverId() {
    final child = ref.read(childByIdProvider(widget.childId));
    final id = child?.linkedDeviceUid;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    _amplitudeSub?.cancel();
    _ampTick.dispose();
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
      body: ChatBackground(
        // bottom: false — pastki inset'ni ChatInputBar o'zining SafeArea'si
        // boshqaradi, shunda wallpaper ekran pastigacha cho'ziladi va
        // transparent input gesture-nav ustida suzib turadi.
        child: SafeArea(
          bottom: false,
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
              ChatInputBar(
                isRecording: _isRecording,
                isVoiceUploading: ref.watch(voiceUploadProvider).status ==
                    UploadStatus.uploading,
                isVideoUploading: ref.watch(videoUploadProvider).status ==
                    VideoUploadStatus.uploading,
                isMediaUploading: _isMediaUploading,
                elapsedSeconds: _elapsedSeconds,
                amplitudes: _amplitudes,
                amplitudeTick: _ampTick,
                onLongPressStart: () => unawaited(_onLongPressStart()),
                onLongPressEnd: () => unawaited(_onLongPressEnd()),
                onCancel: () => unawaited(_abortRecording()),
                onVideoPressed: () => unawaited(_onVideoRecordPressed()),
                onSendText: (t) => unawaited(_sendTextMessage(t)),
                onPickGallery: () => unawaited(_pickGallery()),
                onPickCamera: () => unawaited(_pickCamera()),
                onPickFile: () => unawaited(_pickFile()),
              ),
            ],
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
            icon: Icon(
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
            icon: Icon(
              Icons.more_vert,
              color: AppColors.textPrimary,
            ),
            onPressed: onInfo,
            tooltip: 'chatSettings.title'.tr(),
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
      child: Icon(
        Icons.person,
        color: AppColors.accent,
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
                    child: Icon(
                      Icons.mic_outlined,
                      size: 50,
                      color: AppColors.accent,
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
