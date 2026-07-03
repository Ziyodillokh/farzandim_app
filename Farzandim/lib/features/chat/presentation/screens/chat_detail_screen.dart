// ─────────────────────────────────────────────────────────────────────
// ChatDetailScreen — chat detali (preview, Parvoz dizayn, Telegram-style)
// ─────────────────────────────────────────────────────────────────────
//
// "Chatlar" ro'yxatidagi kontakt bosilganda ochiladi. Header (avatar + ism +
// "Yozmoqda..."), xabarlar (matn / dumaloq video / ovoz + kun ajratgichi),
// pastda kirish paneli.
//
// OVOZ — HAQIQIY: `record` (mikrofon → blob/fayl URL) + `just_audio` bilan
// eshitiladi (web/localhost'da ishlaydi). VIDEO — brauzerda Flutter video
// yozishni qo'llamaydi (camera paketi cheklovi); UI demo, haqiqiy yozuv
// telefonda (`voice_message` feature).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/chat/data/chat_mock.dart';
import 'package:farzandim/features/chat/presentation/screens/round_video_record_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _chipBg = Color(0xFF1B2128);
const _recvBubble = Color(0xFF1C232B); // qabul qilingan pufakcha
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);
const _rec = Color(0xFFFF4D4F); // yozish indikatori

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w, color: c, height: 1.2);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

// To'lqin uchun deterministik balandliklar (0..1).
const _waveHeights = <double>[
  0.3, 0.6, 0.9, 0.5, 0.75, 1, 0.45, 0.65, 0.35, 0.85,
  0.5, 0.7, 0.4, 0.95, 0.55, 0.8, 0.35, 0.6, 0.9, 0.45,
  0.7, 0.5, 0.8, 0.4,
];

/// Chat detali ekrani (preview, interaktiv, haqiqiy ovoz).
class ChatDetailScreen extends StatefulWidget {
  /// `ChatDetailScreen` konstruktor.
  const ChatDetailScreen({required this.contactId, super.key});

  /// Kontakt identifikatori (route parametri).
  final String contactId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final ChatContact _contact = mockContactById(widget.contactId);
  late final List<ChatMsg> _messages = [...mockMessages(widget.contactId)];
  final _scroll = ScrollController();
  final _player = AudioPlayer();
  String? _playingUrl;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  void initState() {
    super.initState();
    // Ovoz tugagach play holatini tozalaymiz.
    _playerSub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingUrl = null);
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _nowLabel() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}';
  }

  void _append(ChatMsg m) {
    setState(() => _messages.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendVideo() async {
    final secs = await showRoundVideoRecord(context);
    if (secs == null || !mounted) return;
    _append(
      ChatMsg(
        kind: ChatMsgKind.roundVideo,
        mine: true,
        time: _nowLabel(),
        durationSec: secs < 1 ? 1 : secs,
      ),
    );
  }

  void _sendVoice(String? url, int secs) {
    _append(
      ChatMsg(
        kind: ChatMsgKind.voice,
        mine: true,
        time: _nowLabel(),
        durationSec: secs < 1 ? 1 : secs,
        mediaUrl: url,
      ),
    );
  }

  /// Ovozli xabarni eshittiradi / to'xtatadi.
  Future<void> _togglePlay(ChatMsg m) async {
    final url = m.mediaUrl;
    if (url == null) {
      AppToast.info(context, 'chat.voiceUnavailable'.tr());
      return;
    }
    // Shu xabar o'ynayotgan bo'lsa — to'xtatamiz.
    if (_playingUrl == url) {
      await _player.stop();
      if (mounted) setState(() => _playingUrl = null);
      return;
    }
    try {
      if (url.startsWith('blob:') || url.startsWith('http')) {
        await _player.setUrl(url);
      } else {
        await _player.setFilePath(url);
      }
      if (!mounted) return;
      setState(() => _playingUrl = url);
      await _player.play();
    } catch (_) {
      if (mounted) AppToast.error(context, 'chat.playError'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(contact: _contact),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m.dayLabel != null) _DayDivider(label: m.dayLabel!),
                      switch (m.kind) {
                        ChatMsgKind.roundVideo => _RoundVideoMessage(
                          msg: m,
                          color: _contact.color,
                        ),
                        ChatMsgKind.voice => _VoiceBubble(
                          msg: m,
                          playing: _playingUrl != null &&
                              _playingUrl == m.mediaUrl,
                          onTap: () => _togglePlay(m),
                        ),
                        ChatMsgKind.text => _TextBubble(msg: m),
                      },
                    ],
                  );
                },
              ),
            ),
            _InputBar(onCamera: _sendVideo, onSendVoice: _sendVoice),
          ],
        ),
      ),
    );
  }
}

// ════════════ Header ════════════

class _Header extends StatelessWidget {
  const _Header({required this.contact});

  final ChatContact contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          _RoundIconButton(
            icon: SolarIconsOutline.altArrowLeft,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.chatList);
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Text(contact.name, style: _unb(18)),
                const SizedBox(height: 2),
                Text(
                  'chat.typing'.tr(),
                  style: _pop(13, w: FontWeight.w500, c: _blue),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _MiniAvatar(contact: contact),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.contact});

  final ChatContact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: contact.color, shape: BoxShape.circle),
      child: Text(contact.initial, style: _unb(18, w: FontWeight.w700)),
    );
  }
}

// ════════════ Kun ajratgichi ════════════

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0x14FFFFFF))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: _pop(12, c: _dim)),
          ),
          const Expanded(child: Divider(color: Color(0x14FFFFFF))),
        ],
      ),
    );
  }
}

// ════════════ Matn pufakchasi ════════════

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.msg});

  final ChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final mine = msg.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
        decoration: BoxDecoration(
          color: mine ? _blue : _recvBubble,
          borderRadius: _bubbleRadius(mine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text ?? '', style: _pop(15)),
            const SizedBox(height: 3),
            _MetaRow(msg: msg, onLight: mine),
          ],
        ),
      ),
    );
  }
}

BorderRadius _bubbleRadius(bool mine) => BorderRadius.only(
  topLeft: const Radius.circular(18),
  topRight: const Radius.circular(18),
  bottomLeft: Radius.circular(mine ? 18 : 4),
  bottomRight: Radius.circular(mine ? 4 : 18),
);

/// Vaqt + o'qilgan belgisi (o'ng pastda).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.msg, this.onLight = false});

  final ChatMsg msg;
  final bool onLight; // ochiq (ko'k) fon ustidami

  @override
  Widget build(BuildContext context) {
    final sub = onLight ? Colors.white70 : _dim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(msg.time, style: _pop(11, c: sub)),
        if (msg.mine) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all_rounded,
            size: 15,
            color: onLight ? Colors.white : _blue,
          ),
        ],
      ],
    );
  }
}

// ════════════ Ovozli xabar pufakchasi ════════════

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({
    required this.msg,
    required this.playing,
    required this.onTap,
  });

  final ChatMsg msg;
  final bool playing;
  final VoidCallback onTap;

  String get _dur {
    final m = msg.durationSec ~/ 60;
    final s = (msg.durationSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final mine = msg.mine;
    final barColor = mine ? Colors.white : _blue;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: mine ? _blue : _recvBubble,
          borderRadius: _bubbleRadius(mine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.22)
                          : _blue.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 22,
                      color: mine ? Colors.white : _blue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _Waveform(color: barColor),
                const SizedBox(width: 10),
                Text(_dur, style: _pop(12, c: mine ? Colors.white70 : _dim)),
              ],
            ),
            const SizedBox(height: 4),
            _MetaRow(msg: msg, onLight: mine),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in _waveHeights)
            Container(
              width: 2.5,
              height: 6 + h * 18,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════ Dumaloq video xabar ════════════

class _RoundVideoMessage extends StatelessWidget {
  const _RoundVideoMessage({required this.msg, required this.color});

  final ChatMsg msg;
  final Color color;

  static const double _d = 190;

  @override
  Widget build(BuildContext context) {
    final mine = msg.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: _d,
              height: _d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: 0.85), _chipBg],
                ),
                border: Border.all(color: const Color(0x22FFFFFF), width: 2),
              ),
              child: const Center(
                child: Icon(
                  SolarIconsBold.videocameraRecord,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(msg.time, style: _pop(11, c: _dim)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 15,
                      color: _blue,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Kirish paneli (matn / ovoz / video) ════════════

class _InputBar extends StatefulWidget {
  const _InputBar({required this.onCamera, required this.onSendVoice});

  final VoidCallback onCamera;
  final void Function(String? url, int secs) onSendVoice;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _starting = false;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startVoice() async {
    if (_starting || _recording) return;
    setState(() => _starting = true);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) AppToast.error(context, 'chat.micDenied'.tr());
        return;
      }
      // Web'da path e'tiborsiz (stop() blob URL qaytaradi); qurilmada tmp fayl.
      var path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _elapsed = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed++);
      });
    } catch (_) {
      if (mounted) AppToast.error(context, 'chat.micError'.tr());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _cancelVoice() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _sendVoice() async {
    _timer?.cancel();
    final secs = _elapsed;
    String? url;
    try {
      url = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    widget.onSendVoice(url, secs < 1 ? 1 : secs);
  }

  String get _elapsedLabel {
    final m = _elapsed ~/ 60;
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottom),
      child: _recording ? _buildRecording() : _buildIdle(),
    );
  }

  Widget _buildIdle() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _fieldBorder),
            ),
            child: Text('chat.inputHint'.tr(), style: _pop(15, c: _dim)),
          ),
        ),
        const SizedBox(width: 10),
        _CircleAction(icon: SolarIconsBold.microphone, onTap: _startVoice),
        const SizedBox(width: 10),
        _CircleAction(icon: SolarIconsBold.camera, onTap: widget.onCamera),
      ],
    );
  }

  Widget _buildRecording() {
    return Row(
      children: [
        _CircleAction(icon: Icons.close_rounded, onTap: _cancelVoice),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: _chipBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text(_elapsedLabel, style: _pop(15, w: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'chat.recording'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(13, c: _dim),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CircleAction(icon: Icons.send_rounded, blue: true, onTap: _sendVoice),
      ],
    );
  }
}

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
        decoration: const BoxDecoration(color: _rec, shape: BoxShape.circle),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.blue = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: blue ? _blue : _chipBg,
          shape: BoxShape.circle,
          border: blue ? null : Border.all(color: _fieldBorder),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _fieldBorder),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}
