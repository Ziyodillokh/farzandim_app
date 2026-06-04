// ─────────────────────────────────────────────────────────────────────
// ChatInputBar — chat ekran pastida inline ovoz yozish (Telegram/WA)
// ─────────────────────────────────────────────────────────────────────
//
// Idle: o'ngda 64x64 lime green mic tugma (long-press).
// Recording: chap delete + jonli waveform + qizil mic (xuddi shu joyda).
// Upload paytida: tugma alpha 0.5 + spinner.
//
// Eslatma: Mic tugma `GestureDetector` widget tree'da DOIMO bir xil
// pozitsiyada turadi — recording boshlangach faqat atrofidagi UI
// o'zgaradi. Aks holda Flutter eski gesture subscription'ni
// yo'qotib, `onLongPressEnd` hech qachon chaqirilmaydi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    required this.isRecording,
    required this.isUploading,
    required this.elapsedSeconds,
    required this.amplitudes,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onCancel,
    required this.onSendText,
    super.key,
  });

  final bool isRecording;
  final bool isUploading;
  final int elapsedSeconds;
  final List<double> amplitudes;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback onCancel;
  // Telegram-style text yuborish.
  final ValueChanged<String> onSendText;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  String _draft = '';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _textController.addListener(() {
      if (_textController.text != _draft) {
        setState(() => _draft = _textController.text);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendText() {
    final trimmed = _textController.text.trim();
    if (trimmed.isEmpty) return;
    widget.onSendText(trimmed);
    _textController.clear();
    setState(() => _draft = '');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _draft.trim().isNotEmpty;
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.isRecording)
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(
                  AppIcons.delete,
                  color: Colors.red,
                  size: 28,
                ),
              ),
            if (widget.isRecording)
              Expanded(
                child: _RecordingIndicator(
                  elapsedSeconds: widget.elapsedSeconds,
                  amplitudes: widget.amplitudes,
                ),
              )
            else
              // Telegram-style text input — rounded chip ko'rinishida.
              Expanded(
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: 48, maxHeight: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: !widget.isUploading,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: (_) => _sendText(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Xabar yozing…',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Text bo'lmasa — mic, bo'lsa — send. Telegram bilan bir xil UX.
            hasText && !widget.isRecording
                ? _SendButton(onTap: _sendText, isUploading: widget.isUploading)
                : _MicButton(
                    isRecording: widget.isRecording,
                    isUploading: widget.isUploading,
                    onTap: () {
                      if (widget.isRecording) {
                        widget.onLongPressEnd();
                      } else {
                        widget.onLongPressStart();
                      }
                    },
                    onLongPressStart: widget.onLongPressStart,
                    onLongPressEnd: widget.onLongPressEnd,
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── Telegram-style 'Send' tugma ─────────────────────────────────────
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.isUploading});

  final VoidCallback onTap;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isUploading ? null : onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF37AEE2), // Telegram light blue
              Color(0xFF1E96C8), // Telegram dark blue
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x551E96C8),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: isUploading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

// ─── Mic tugma (eski UX saqlandi — long press / tap toggle) ──────────
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isRecording,
    required this.isUploading,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final bool isRecording;
  final bool isUploading;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isUploading ? null : onTap,
      onLongPressStart: isUploading ? null : (_) => onLongPressStart(),
      onLongPressEnd: isUploading ? null : (_) => onLongPressEnd(),
      child: Container(
        width: 56,
        height: 56,
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
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppColors.catRed : AppColors.primary)
                  // ignore: deprecated_member_use
                  .withOpacity(isRecording ? 0.5 : 0.35),
              blurRadius: isRecording ? 20 : 14,
              spreadRadius: isRecording ? 3 : 1,
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
                    color: Colors.black,
                  ),
                ),
              )
            : Icon(
                isRecording ? AppIcons.stop : AppIcons.mic,
                color: isRecording ? Colors.white : Colors.black,
                size: 28,
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
