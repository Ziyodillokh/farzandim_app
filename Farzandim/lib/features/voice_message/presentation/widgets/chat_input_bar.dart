// Telegram uslubidagi chat input: matn, emoji, attach va mic/video tugma.
// Mic tugmada tap rejimni almashtiradi (ovoz/video), hold yozishni
// boshlaydi; matn terilganda mic o'rniga send tugma chiqadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';

part 'chat_input_bar_widgets.dart';

// Parvoz chat tokenlari — bola chati bilan bir xil (eski yashil AppColors
// o'rniga ko'k aksent + to'q kulrang panel). Faqat KO'RINISH — imkoniyatlar
// (emoji, attach, video) saqlanadi.
const _pBlue = Color(0xFF216BFF); // aksent: send, emoji, cursor
const _pChipBg = Color(0xFF1B2128); // matn maydoni foni
const _pSheetBg = Color(0xFF15181E); // attach/emoji varaq foni

/// Mic/video tugma rejimi.
enum ChatRecordMode { voice, video }

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    required this.isRecording,
    required this.isVoiceUploading,
    required this.isVideoUploading,
    required this.isMediaUploading,
    required this.elapsedSeconds,
    required this.amplitudes,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onCancel,
    required this.onVideoPressed,
    required this.onSendText,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onPickFile,
    this.amplitudeTick,
    super.key,
  });

  final bool isRecording;
  final bool isVoiceUploading;
  final bool isVideoUploading;
  final bool isMediaUploading;
  final int elapsedSeconds;
  final List<double> amplitudes;

  /// Amplitude yangilanish signali: berilsa jonli waveform faqat shu
  /// Listenable orqali qayta chiziladi — ota-ekran setState qilmaydi,
  /// 10Hz'da butun ekran o'rniga faqat waveform subtree rebuild bo'ladi.
  final Listenable? amplitudeTick;

  /// Ovoz yozishni boshlash (hold start, voice rejimi).
  final VoidCallback onLongPressStart;

  /// Ovoz yozishni tugatish + yuborish (hold end, voice rejimi).
  final VoidCallback onLongPressEnd;

  /// Recording'ni bekor qilish (delete tugma).
  final VoidCallback onCancel;

  /// Yumaloq video recorder modalini ochish (video rejimi).
  final VoidCallback? onVideoPressed;

  /// Matn yuborish.
  final ValueChanged<String> onSendText;

  /// Media tanlash callbacks.
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onPickFile;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _draft = '';
  bool _showEmoji = false;
  ChatRecordMode _mode = ChatRecordMode.voice;

  bool get _anyUploading =>
      widget.isVoiceUploading ||
      widget.isVideoUploading ||
      widget.isMediaUploading;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(() {
      if (_controller.text != _draft) {
        setState(() => _draft = _controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendText() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    widget.onSendText(trimmed);
    _controller.clear();
    setState(() => _draft = '');
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmoji = true);
    }
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = _mode == ChatRecordMode.voice
          ? ChatRecordMode.video
          : ChatRecordMode.voice;
    });
    final hint = _mode == ChatRecordMode.video
        ? 'voiceChat.videoMode'.tr()
        : 'voiceChat.voiceMode'.tr();
    AppToast.info(context, hint);
  }

  void _openAttachSheet() {
    if (_anyUploading) return;
    FocusScope.of(context).unfocus();
    setState(() => _showEmoji = false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _pSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachOption(
                icon: SolarIconsBold.gallery,
                color: const Color(0xFF7E5BEF),
                label: 'voiceChat.attachGallery'.tr(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onPickGallery();
                },
              ),
              _AttachOption(
                icon: SolarIconsBold.camera,
                color: const Color(0xFFEF5DA8),
                label: 'voiceChat.attachCamera'.tr(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onPickCamera();
                },
              ),
              _AttachOption(
                icon: SolarIconsBold.file,
                color: const Color(0xFF2D9CDB),
                label: 'voiceChat.attachFile'.tr(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onPickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _draft.trim().isNotEmpty;
    // Orqa fon yo'q — input wallpaper ustida suzib turadi (iPhone/Telegram).
    // Faqat emoji paneli ochilganda ostiga solid fon qo'shiladi.
    return ColoredBox(
      color: _showEmoji && !widget.isRecording
          ? _pSheetBg
          : Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // [0] Recording paytida delete, aks holda bo'sh.
                  if (widget.isRecording)
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(
                        SolarIconsBold.trashBinMinimalistic,
                        color: Colors.red,
                        size: 28,
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // [1] Markaz: recording indicator yoki input chip.
                  if (widget.isRecording)
                    Expanded(
                      child: _RecordingIndicator(
                        elapsedSeconds: widget.elapsedSeconds,
                        amplitudes: widget.amplitudes,
                        amplitudeTick: widget.amplitudeTick,
                      ),
                    )
                  else
                    Expanded(child: _buildInputChip()),

                  const SizedBox(width: 8),

                  // [2] Oxirgi child: mic/video toggle yoki send.
                  if (hasText && !widget.isRecording)
                    _SendButton(onTap: _sendText, disabled: _anyUploading)
                  else
                    _buildActionButton(),
                ],
              ),
            ),
            if (_showEmoji && !widget.isRecording)
              _EmojiPanel(onEmoji: _insertEmoji),
          ],
        ),
      ),
    );
  }

  Widget _buildInputChip() {
    // Pill — bola chatidek to'q kulrang (`_pChipBg`), to'liq oval stadium.
    // Ichida fonsiz TextField → ichki to'rtburchak yo'q (iPhone uslubi).
    return Container(
      constraints: const BoxConstraints(minHeight: 46, maxHeight: 132),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _pChipBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji tugma (chap).
          IconButton(
            onPressed: widget.isMediaUploading ? null : _toggleEmoji,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: Icon(
              _showEmoji ? SolarIconsBold.keyboard : SolarIconsBold.smileCircle,
              color: AppColors.textSecondary,
              size: 23,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !widget.isMediaUploading,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              cursorColor: _pBlue,
              onTap: () {
                if (_showEmoji) setState(() => _showEmoji = false);
              },
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'voiceChat.messageHint'.tr(),
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                isCollapsed: true,
              ),
            ),
          ),
          // Attach (media) tugma (o'ng).
          IconButton(
            onPressed: widget.isMediaUploading ? null : _openAttachSheet,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: widget.isMediaUploading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _pBlue,
                    ),
                  )
                : Transform.rotate(
                    angle: -0.7,
                    child: Icon(
                      SolarIconsBold.paperclip,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Mic/video toggle tugma. ValueKey bilan doim oxirgi child bo'lib
  /// turishi kerak — aks holda recording boshlanganda long-press
  /// subscription yo'qolib, onLongPressEnd kelmay qoladi.
  Widget _buildActionButton() {
    final isRecording = widget.isRecording;
    final isVideoMode = _mode == ChatRecordMode.video;
    final disabled = _anyUploading && !isRecording;

    return GestureDetector(
      key: const ValueKey('voice-mic-button'),
      behavior: HitTestBehavior.opaque,
      onTap: disabled
          ? null
          : () {
              if (isRecording) {
                widget.onLongPressEnd();
              } else {
                // Tap rejimni almashtiradi (Telegram'dagidek).
                _toggleMode();
              }
            },
      onLongPressStart: disabled
          ? null
          : (_) {
              if (isVideoMode) {
                widget.onVideoPressed?.call();
              } else {
                widget.onLongPressStart();
              }
            },
      onLongPressEnd: disabled
          ? null
          : (_) {
              if (!isVideoMode) {
                widget.onLongPressEnd();
              }
            },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: isRecording
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: disabled
                      ? [
                          _pBlue.withValues(alpha: 0.6),
                          _pBlue.withValues(alpha: 0.6),
                        ]
                      : [_pBlue, _pBlue],
                ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? const Color(0xFFFF5252) : _pBlue)
                  .withValues(alpha: isRecording ? 0.4 : 0.28),
              blurRadius: isRecording ? 18 : 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: disabled
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isRecording
                      ? SolarIconsBold.stop
                      : isVideoMode
                      ? SolarIconsBold.videocamera
                      : SolarIconsBold.microphone,
                  key: ValueKey(
                    isRecording
                        ? 'stop'
                        : isVideoMode
                        ? 'video'
                        : 'mic',
                  ),
                  color: AppColors.onPrimary,
                  size: 24,
                ),
              ),
      ),
    );
  }
}
