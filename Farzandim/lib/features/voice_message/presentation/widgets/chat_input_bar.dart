// ─────────────────────────────────────────────────────────────────────
// ChatInputBar — bola ilovasidagi chat input bilan BIR XIL (Parvoz)
// ─────────────────────────────────────────────────────────────────────
//
// Layout (bola ilovasidagi input bilan aynan bir xil — screenshot 1:1):
//   idle (matn yo'q):  [ Xabar... maydoni ]  (mic ⭕)  (kamera ⭕)
//   matn bor:          [ Xabar... maydoni ]  (ko'k send ⭕)
//   yozilmoqda:        (X ⭕) [ 🔴 0:07  Yozilmoqda... ]  (ko'k send ⭕)
//
//   • mic bosilsa — ovoz yozish BOSHLANADI (tap bilan), ko'k send bosilsa
//     yuboriladi, X — bekor qiladi.
//   • kamera bosilsa — yumaloq video recorder; UZOQ bosilsa media
//     biriktirish (galereya/kamera/fayl) paneli ochiladi.
//
// Avval bu input emoji tugmasi + qog'oz qisqich (attach) + mic/video toggle
// tugmasidan iborat edi — bola chatidan farqli, betartibroq ko'rinardi.
// Endi bola chati bilan aynan bir xil: toza pill + alohida mic + kamera.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// Parvoz tokenlar — bola ilovasidagi chat input bilan BIR XIL.
const _pBlue = Color(0xFF216BFF);
const _pChipBg = Color(0xFF1B2128);
const _pFieldBorder = Color(0x1FFFFFFF);
const _pDim = Color(0x8CFFFFFF);
const _pSheetBg = Color(0xFF15181E);
const _pRec = Color(0xFFFF4D4F);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

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

  /// Jonli amplituda (send paytida xabarga saqlanadi — recording row live
  /// waveform ko'rsatmaydi, bola chati bilan bir xil).
  final List<double> amplitudes;

  /// Ovoz yozishni boshlash (mic bosilganda).
  final VoidCallback onLongPressStart;

  /// Ovoz yozishni tugatish + yuborish (send bosilganda).
  final VoidCallback onLongPressEnd;

  /// Recording'ni bekor qilish (X tugma).
  final VoidCallback onCancel;

  /// Yumaloq video recorder modalini ochish (kamera tugma).
  final VoidCallback? onVideoPressed;

  /// Matn yuborish.
  final ValueChanged<String> onSendText;

  /// Media tanlash callbacks (kamera tugmani uzoq bosish paneli).
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onPickFile;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _controller;
  String _draft = '';

  bool get _anyUploading =>
      widget.isVoiceUploading ||
      widget.isVideoUploading ||
      widget.isMediaUploading;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      if (_controller.text != _draft) {
        setState(() => _draft = _controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendText() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    widget.onSendText(trimmed);
    _controller.clear();
    setState(() => _draft = '');
  }

  String get _elapsedLabel {
    final m = widget.elapsedSeconds ~/ 60;
    final s = (widget.elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openAttachSheet() {
    if (_anyUploading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _pSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottom),
      child: widget.isRecording ? _recordingRow() : _idleRow(),
    );
  }

  // ── Idle: maydon + mic/kamera yoki send (bola ilovasidagidek) ──
  Widget _idleRow() {
    final hasText = _draft.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
            decoration: BoxDecoration(
              color: _pChipBg,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: _pFieldBorder),
            ),
            child: TextSelectionTheme(
              data: const TextSelectionThemeData(
                cursorColor: _pBlue,
                selectionHandleColor: _pBlue,
                selectionColor: Color(0x5C216BFF),
              ),
              child: TextField(
                controller: _controller,
                enabled: !widget.isMediaUploading,
                style: _pop(15),
                cursorColor: _pBlue,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => _sendText(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  filled: false,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: 'voiceChat.inputHint'.tr(),
                  hintStyle: _pop(15, c: _pDim),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (widget.isMediaUploading)
          const _CircleSpinner()
        else if (hasText)
          _CircleAction(icon: Icons.send_rounded, blue: true, onTap: _sendText)
        else ...[
          _CircleAction(
            icon: SolarIconsBold.microphone,
            busy: widget.isVoiceUploading,
            onTap: _anyUploading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onLongPressStart();
                  },
          ),
          const SizedBox(width: 10),
          _CircleAction(
            icon: SolarIconsBold.camera,
            busy: widget.isVideoUploading,
            onTap: _anyUploading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onVideoPressed?.call();
                  },
            onLongPress: _openAttachSheet,
          ),
        ],
      ],
    );
  }

  // ── Recording: X + (🔴 timer Yozilmoqda...) + ko'k send ──
  Widget _recordingRow() {
    return Row(
      children: [
        _CircleAction(
          icon: Icons.close_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onCancel();
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: _pChipBg,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: _pFieldBorder),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text(_elapsedLabel, style: _pop(15, w: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Yozilmoqda...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(13, c: _pDim),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircleAction(
          icon: Icons.send_rounded,
          blue: true,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onLongPressEnd();
          },
        ),
      ],
    );
  }
}

// ── Pulsatsiyalanuvchi qizil nuqta (bola ilovasidagidek) ──
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 11,
        height: 11,
        decoration: const BoxDecoration(color: _pRec, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Doira tugma (bola ilovasidagi `_CircleAction` bilan bir xil) ──
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.blue = false,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool blue;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: blue ? _pBlue : _pChipBg,
          shape: BoxShape.circle,
          border: blue ? null : Border.all(color: _pFieldBorder),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _CircleSpinner extends StatelessWidget {
  const _CircleSpinner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _pChipBg,
        shape: BoxShape.circle,
        border: Border.all(color: _pFieldBorder),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _pBlue),
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
          Text(label, style: _pop(13)),
        ],
      ),
    );
  }
}
