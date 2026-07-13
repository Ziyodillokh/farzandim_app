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
import 'package:farzandim_child/shared/widgets/app_snackbar.dart';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/video_message/presentation/providers/video_message_provider.dart';
import 'package:farzandim_child/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim_child/features/voice_message/data/services/audio_player_manager.dart';
import 'package:farzandim_child/features/voice_message/data/services/audio_recorder_service.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/voice_message_provider.dart';
import 'package:farzandim_child/features/voice_message/presentation/screens/chat_settings_screen.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/chat_bubble.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/chat_input_bar.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/chat_top_toast.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/round_video_bubble.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/round_video_recorder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';

// Parvoz tokenlar — ota-ona ilovasidagi chat detali bilan BIR XIL.
const _pBg = Color(0xFF00060A);
const _pBlue = Color(0xFF216BFF);
const _pChipBg = Color(0xFF1B2128);
const _pFieldBorder = Color(0x1FFFFFFF);
const _pDim = Color(0x8CFFFFFF);

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

  /// Media (rasm/hujjat) yuklanmoqda — attach tugmasi spinner.
  bool _isMediaUploading = false;

  // oxirgi pastki xabar id — auto-scroll faqat yangi xabar kelganda
  String? _lastBottomItemId;

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
    // reverse:true ro'yxatda "past" = offset 0 (Telegram kabi).
    _scrollController.animateTo(
      0,
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
      AppSnackBar.info(context, 'voiceChat.micPermission'.tr());
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
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0).toDouble();
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
      AppSnackBar.warning(context, 'voiceChat.tooShort'.tr());
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return;
    }

    final ok = await ref
        .read(voiceMessageUploadProvider.notifier)
        .send(
          audioFile: File(filePath),
          durationSeconds: (elapsed / 1000).round(),
          waveform: waveformSnapshot,
        );

    if (!mounted) return;
    if (ok) {
      ref.read(voiceMessageUploadProvider.notifier).reset();
      ChatTopToast.flash(
        context,
        'Ovozli xabar yuborildi',
        icon: Icons.check_rounded,
      );
      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      // Auto-scroll bottom (yangi xabar pastda).
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      final err = ref.read(voiceMessageUploadProvider).errorMessage;
      AppSnackBar.error(
        context,
        'voiceChat.errorPrefix'.tr(
          namedArgs: {'error': err ?? 'voiceChat.sendErrorFallback'.tr()},
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

  // ─── Telegram-style text xabar yuborish ──────────────────────────
  // Backend POST /api/voice-messages/text → Socket.io receiver'ga emit.
  // Provider invalidate qilib ListView'ga yangi bubble qo'shamiz.
  Future<void> _sendTextMessage(String text) async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    if (parentUid == null || parentUid.isEmpty) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Ota-ona aniqlanmadi');
      return;
    }
    try {
      await ref
          .read(backendVoiceMessageRepositoryProvider)
          .sendText(receiverId: parentUid, text: text);
      // Yangi xabar UI'ga chiqishi uchun list provider'ni yangilash.
      ref.invalidate(voiceMessagesProvider);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Xabar yuborilmadi: $e');
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
      _showError('Faylni yuborishda xato');
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
      _showError('Faylni yuborishda xato');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path != null) await _sendMediaFile(File(path));
    } catch (_) {
      _showError('Faylni yuborishda xato');
    }
  }

  Future<void> _sendMediaFile(File file) async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    if (parentUid == null || parentUid.isEmpty) {
      _showError('Ota-ona aniqlanmadi');
      return;
    }
    setState(() => _isMediaUploading = true);
    try {
      await ref
          .read(backendVoiceMessageRepositoryProvider)
          .sendMedia(receiverId: parentUid, file: file);
      ref.invalidate(voiceMessagesProvider);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      _showError('Faylni yuborishda xato');
    } finally {
      if (mounted) setState(() => _isMediaUploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    AppSnackBar.error(context, msg);
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

    // Telegram uslubidagi yuqori "pill" toast (spinner bilan) — plain
    // SnackBar o'rniga. Ish tugagach `videoToast.dismiss()`.
    final videoToast = ChatTopToast.show(
      context,
      'Video tayyorlanmoqda…',
      spinner: true,
    );

    bool ok;
    // ─── Web preview ─────────────────────────────────────────────────
    // dart:io File va video_compress paketlari web'da ishlamaydi
    // (UnsupportedError). XFile baytlarini to'g'ridan-to'g'ri yuboramiz.
    if (kIsWeb) {
      try {
        final bytes = await xfile.readAsBytes();
        if (!mounted) return;
        videoToast.dismiss();
        // Brauzer kamera Chrome'da WebM beradi. XFile.name ba'zan
        // kengaytmasiz keladi, shu sababli majburiy .webm qo'yamiz.
        final rawName = xfile.name;
        final hasExt = RegExp(r'\.[a-zA-Z0-9]{2,5}$').hasMatch(rawName);
        final filename = hasExt ? rawName : '$rawName.webm';
        ok = await ref
            .read(videoMessageUploadProvider.notifier)
            .sendBytes(bytes: bytes, durationSeconds: 0, filename: filename);
      } catch (e) {
        if (!mounted) return;
        videoToast.dismiss();
        AppSnackBar.error(context, 'Video yuborilmadi: $e');
        return;
      }
    } else {
      // ─── Mobile (Android/iOS) ──────────────────────────────────────
      final original = File(xfile.path);
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
      videoToast.dismiss();

      ok = await ref
          .read(videoMessageUploadProvider.notifier)
          .send(videoFile: fileToUpload, durationSeconds: durationSeconds ?? 0);
    }

    if (!mounted) return;

    if (ok) {
      // Mobile'da vaqtinchalik fayllarni tozalaymiz (web'da fayl yo'q).
      // (Yuqoridagi mobile branch ichida `original` va `fileToUpload`
      // lokal aniqlangan — bu yerga kelmagan.)
      ref.read(videoMessageUploadProvider.notifier).reset();
      ChatTopToast.flash(context, 'Video yuborildi', icon: Icons.check_rounded);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      final state = ref.read(videoMessageUploadProvider);
      AppSnackBar.error(
        context,
        'voiceChat.errorPrefix'.tr(
          namedArgs: {
            'error': state.errorMessage ?? 'voiceChat.sendErrorFallback'.tr(),
          },
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
      backgroundColor: _pBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatHeader(
              onSettings: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChatSettingsScreen(),
                  ),
                );
              },
            ),
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) return const _EmptyState();

                  // auto-scroll faqat ro'yxat oxiriga yangi xabar
                  // qo'shilganda — har rebuild'da pastga tortmaymiz
                  final bottomId = messages.last.id;
                  if (bottomId != _lastBottomItemId) {
                    _lastBottomItemId = bottomId;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    // Telegram kabi: ro'yxat PASTDAN boshlanadi — kam xabar
                    // bo'lsa ham tepaga yopishmaydi, eng yangisi pastda.
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final item = messages[messages.length - 1 - i];
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
                  child: CircularProgressIndicator(color: _pBlue),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'voiceChat.errorPrefix'.tr(namedArgs: {'error': '$e'}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFE74C4C)),
                    ),
                  ),
                ),
              ),
            ),
            ChatInputBar(
              isRecording: _isRecording,
              isVoiceUploading: isVoiceUploading,
              isVideoUploading: isVideoUploading,
              isMediaUploading: _isMediaUploading,
              elapsedSeconds: _elapsedSeconds,
              amplitudes: _amplitudes,
              onLongPressStart: () => unawaited(_onLongPressStart()),
              onLongPressEnd: _onLongPressEnd,
              onCancel: () => unawaited(_abortRecording()),
              onVideoPressed: isVoiceUploading || isVideoUploading
                  ? null
                  : () => unawaited(_onVideoRecordPressed()),
              onSendText: (text) => unawaited(_sendTextMessage(text)),
              onPickGallery: () => unawaited(_pickGallery()),
              onPickCamera: () => unawaited(_pickCamera()),
              onPickFile: () => unawaited(_pickFile()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Chat header — ota-ona ilovasidagi chat detali bilan BIR XIL (Parvoz):
// ← kvadrat tugma + markazda ism/holat + o'ngda avatar (bosilsa sozlamalar)
// ─────────────────────────────────────────────────────────────────────

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bog'langan ota-onaning PROFILDAGI ismi (backend'dan, bo'lmasa fallback).
    final parentName = ref.watch(parentNameProvider).valueOrNull;
    return Padding(
      // Boshqa sahifalar bilan bir xil: header tepaga yopishmasin.
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _pChipBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _pFieldBorder),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(
                  (parentName != null && parentName.trim().isNotEmpty)
                      ? parentName.trim()
                      : 'voiceChat.headerParent'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.unbounded(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'voiceChat.headerSubtitle'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _pDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar — bosilsa chat sozlamalari ochiladi.
          GestureDetector(
            onTap: onSettings,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _pBlue.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: _pFieldBorder),
              ),
              child: const Icon(AppIcons.profile, color: _pBlue, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Empty state — ota-ona ilovasidagi kabi minimal matn
// ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Suhbatni boshlang',
        style: GoogleFonts.poppins(fontSize: 14, color: _pDim),
      ),
    );
  }
}
