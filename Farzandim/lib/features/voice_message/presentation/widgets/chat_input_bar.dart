// ─────────────────────────────────────────────────────────────────────
// ChatInputBar — Telegram uslubidagi chat input (parent)
// ─────────────────────────────────────────────────────────────────────
//
// Layout (idle):
//   [emoji] [ matn maydoni ] [📎 attach]   [mic/video | send]
// Recording:
//   [🗑 delete] [ jonli waveform + timer ] [⏹ stop]
//
// Mic/video tugma (Telegram):
//   • TAP    → rejimni almashtiradi (ovoz ↔ video), icon o'zgaradi.
//   • HOLD   → ovoz rejimida ovoz yozadi (qo'yib yuborsa yuboradi),
//              video rejimida yumaloq video recorder modalini ochadi.
//   • text bo'lsa → send tugma chiqadi (mic o'rniga).
//
// Mic GestureDetector DOIMO oxirgi child + `ValueKey` — recording
// boshlanganda long-press subscription yo'qolmaydi (onLongPressEnd ishlaydi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    super.key,
  });

  final bool isRecording;
  final bool isVoiceUploading;
  final bool isVideoUploading;
  final bool isMediaUploading;
  final int elapsedSeconds;
  final List<double> amplitudes;

  /// Ovoz yozishni boshlash (HOLD start, voice rejimi).
  final VoidCallback onLongPressStart;

  /// Ovoz yozishni tugatish + yuborish (HOLD end, voice rejimi).
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(hint),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openAttachSheet() {
    if (_anyUploading) return;
    FocusScope.of(context).unfocus();
    setState(() => _showEmoji = false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
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
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF7E5BEF),
                label: 'voiceChat.attachGallery'.tr(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onPickGallery();
                },
              ),
              _AttachOption(
                icon: Icons.photo_camera_rounded,
                color: const Color(0xFFEF5DA8),
                label: 'voiceChat.attachCamera'.tr(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onPickCamera();
                },
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_rounded,
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
    // Orqa fon YO'Q — input wallpaper ustida suzib turadi (iPhone/Telegram).
    // Faqat emoji paneli ochilganda ostiga solid fon qo'shiladi.
    return Container(
      color: _showEmoji && !widget.isRecording
          ? AppColors.surface
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
                        Icons.delete_outline,
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
                      ),
                    )
                  else
                    Expanded(child: _buildInputChip()),

                  const SizedBox(width: 8),

                  // [2] Oxirgi child: mic/video toggle yoki send.
                  if (hasText && !widget.isRecording)
                    _SendButton(
                      onTap: _sendText,
                      disabled: _anyUploading,
                    )
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
    // Pill — `AppColors.surface` (light=oq, dark=qora), to'liq oval stadium.
    // Ichida fonsiz TextField → ichki to'rtburchak yo'q (iPhone uslubi).
    return Container(
      constraints: const BoxConstraints(minHeight: 46, maxHeight: 132),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
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
              _showEmoji
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
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
              cursorColor: AppColors.primary,
              onTap: () {
                if (_showEmoji) setState(() => _showEmoji = false);
              },
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
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
                ? SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Transform.rotate(
                    angle: -0.7,
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Mic/video toggle tugma — gesture stabil (ValueKey + oxirgi child).
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
                // TAP → rejim almashadi (Telegram).
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
                          AppColors.primary.withValues(alpha: 0.6),
                          AppColors.primaryDark.withValues(alpha: 0.6),
                        ]
                      : [AppColors.primary, AppColors.primaryDark],
                ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRecording
                      ? const Color(0xFFFF5252)
                      : AppColors.primary)
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
                      ? Icons.stop_rounded
                      : isVideoMode
                          ? Icons.videocam_rounded
                          : Icons.mic_rounded,
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

// ─── Telegram-style yashil send tugma ───────────────────────────────
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.disabled});

  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Icon(
            Icons.send_rounded,
            color: AppColors.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recording indicator (qizil dot + timer + jonli waveform) ────────
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
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
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 26,
              child: amplitudes.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: amplitudes.length,
                      itemBuilder: (_, i) {
                        final amp = amplitudes[amplitudes.length - 1 - i];
                        final h = (amp * 26).clamp(2.0, 26.0);
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 1),
                          child: Center(
                            child: Container(
                              width: 2.5,
                              height: h,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
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

// ─────────────────────────────────────────────────────────────────────
// Emoji panel — kategoriya tablar + grid (zero-dependency)
// ─────────────────────────────────────────────────────────────────────

class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({required this.onEmoji});

  final ValueChanged<String> onEmoji;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  int _category = 0;

  static const List<({IconData icon, List<String> emojis})> _categories = [
    (
      icon: Icons.emoji_emotions_outlined,
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🙂', '🙃',
        '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
        '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
        '🤐', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '😌', '😔',
        '😪', '🤤', '😴', '😷', '🤒', '🤕', '🥵', '🥶', '😵', '🤯',
        '🥳', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😲', '😳',
        '🥺', '😦', '😨', '😰', '😢', '😭', '😱', '😖', '😣', '😞',
        '😤', '😡', '😠', '🤬', '😈', '👿', '💀', '😺', '😸', '😹',
      ],
    ),
    (
      icon: Icons.front_hand_outlined,
      emojis: [
        '👍', '👎', '👌', '🤌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙',
        '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋',
        '🤝', '🙏', '✍️', '💅', '🤳', '💪', '👏', '🙌', '👐', '🤲',
        '🫶', '👊', '✊', '🤛', '🤜', '🫰', '🫵', '🦾', '🖕', '✔️',
      ],
    ),
    (
      icon: Icons.favorite_border_rounded,
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '♥️',
        '💋', '💯', '💢', '💥', '💫', '💦', '💨', '🕳️', '💬', '🗯️',
        '⭐', '🌟', '✨', '⚡', '🔥', '🌈', '☀️', '🌙', '🎉', '🎊',
      ],
    ),
    (
      icon: Icons.pets_outlined,
      emojis: [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
        '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤', '🦆',
        '🦅', '🦉', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌',
        '🐢', '🐍', '🐙', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🌸',
        '🌹', '🌻', '🌼', '🌷', '🌲', '🌳', '🌴', '🌵', '🍀', '🍁',
      ],
    ),
    (
      icon: Icons.restaurant_outlined,
      emojis: [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
        '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
        '🥦', '🥕', '🌽', '🌶️', '🥔', '🍠', '🥐', '🍞', '🥖', '🧀',
        '🥚', '🍳', '🥞', '🧇', '🥓', '🍔', '🍟', '🍕', '🌭', '🥪',
        '🌮', '🌯', '🍜', '🍲', '🍛', '🍣', '🍱', '🍦', '🍩', '🍪',
        '🎂', '🍰', '🧁', '🍫', '🍬', '🍭', '☕', '🍵', '🥤', '🧃',
      ],
    ),
    (
      icon: Icons.sports_soccer_outlined,
      emojis: [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🎱', '🏓',
        '🏸', '🥅', '🏒', '🏑', '🥍', '🏏', '⛳', '🏹', '🎣', '🥊',
        '🥋', '🎽', '⛸️', '🥌', '🛷', '🎿', '⛷️', '🏂', '🏋️', '🤸',
        '🤼', '🤽', '🤾', '🚴', '🚵', '🏆', '🥇', '🥈', '🥉', '🎮',
        '🎯', '🎲', '🎸', '🎹', '🎺', '🎻', '🥁', '🎤', '🎧', '🎬',
      ],
    ),
    (
      icon: Icons.lightbulb_outline_rounded,
      emojis: [
        '⌚', '📱', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '💽', '💾', '📷',
        '📸', '📹', '🎥', '📞', '☎️', '📟', '📠', '📺', '📻', '🔋',
        '🔌', '💡', '🔦', '🕯️', '🧯', '🛢️', '💸', '💵', '💴', '💶',
        '💷', '💰', '💳', '💎', '⚖️', '🔧', '🔨', '⚙️', '🔑', '🔒',
        '📚', '📖', '📝', '✏️', '🖊️', '📌', '📎', '✂️', '📅', '⏰',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final emojis = _categories[_category].emojis;
    return Container(
      height: 256,
      color: AppColors.surface,
      child: Column(
        children: [
          // Kategoriya tablari.
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_categories.length, (i) {
                final selected = i == _category;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _category = i),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Icon(
                        _categories[i].icon,
                        size: 22,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) {
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => widget.onEmoji(emojis[i]),
                  child: Center(
                    child: Text(
                      emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
