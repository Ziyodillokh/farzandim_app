// ─────────────────────────────────────────────────────────────────────
// ChatsListScreen — "Chatlar" (Figma 1:1, Parvoz night)
// ─────────────────────────────────────────────────────────────────────
//
// Bola ilovasida chat tugmasi bosilganda ochiladi. Tuzilishi (Figma):
//   • Header: ← kvadrat tugma + markazda "Chatlar"
//   • Qatorlar: avatar (+yashil onlayn nuqta) + ism + oxirgi xabar +
//     vaqt + ko'k o'qilmaganlar soni. Qator bosilsa → /voice-chat.
//   • Pastda "SOS xabar" tugmasi → tasdiqlash oynasi (qizil SOS +
//     surib yuborish) → sosStateProvider.send() (REAL: backend'ga
//     joylashuv bilan SOS, ota-onaga push).
//
// Real: pairing bo'lsa "Ota-ona" qatori voiceMessagesProvider'dan oxirgi
// xabar/o'qilmaganlar bilan. Pairing yo'q bo'lsa PREVIEW (Figma qatorlar).

import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/sos/presentation/providers/sos_provider.dart';
import 'package:farzandim_child/features/video_message/data/models/video_message.dart';
import 'package:farzandim_child/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/voice_message_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Figma tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF181C22);
const _glass = Color(0x14FFFFFF);
const _glassBorder = Color(0x24FFFFFF);
const _dim = Color(0x99FFFFFF);
const _online = Color(0xFF34C759);
const _sosRed = Color(0xFFD32F2F);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

const _months = [
  'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
  'iyl', 'avg', 'sen', 'okt', 'noy', 'dek', //
];

String _timeLabel(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  if (DateUtils.isSameDay(d, now)) {
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day} ${_months[d.month - 1]}';
}

/// "Chatlar" sahifasi.
class ChatsListScreen extends ConsumerWidget {
  /// `ChatsListScreen` konstruktor.
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingStateProvider);
    // VOICE + VIDEO birlashtirilgan lenta — video xabar ham "yangi xabar"
    // (unread/preview) sifatida ko'rinsin (avval faqat voice hisobga olinardi).
    final items =
        ref.watch(chatMessagesProvider).valueOrNull ?? const <ChatItem>[];
    // Bog'langan ota-onaning PROFILDAGI ismi (backend'dan).
    final parentName = ref.watch(parentNameProvider).valueOrNull;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/dashboard');
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _glass,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _glassBorder),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Chatlar',
                      textAlign: TextAlign.center,
                      style: _unb(20),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: pairing.isPaired
                    ? _realRows(context, items, parentName)
                    : _previewRows(context),
              ),
            ),
            // ── SOS xabar (Figma) ──
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 14 + bottomInset),
              child: GestureDetector(
                onTap: () => _showSosDialog(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _glass,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _glassBorder),
                  ),
                  child: Text('SOS xabar', style: _pop(15, w: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── REAL: ota-ona qatori (profildagi ism + oxirgi xabar + o'qilmaganlar) ──
  List<Widget> _realRows(
    BuildContext context,
    List<ChatItem> items,
    String? parentName,
  ) {
    final last = items.isNotEmpty ? items.last : null;
    // O'qilmagan (ota-onadan kelgan, hali seen bo'lmagan) VOICE + VIDEO soni.
    var unread = 0;
    for (final item in items) {
      switch (item) {
        case VoiceItem(:final message):
          if (message.sender == 'parent' &&
              message.status != VoiceMessageStatus.seen) {
            unread++;
          }
        case VideoItem(:final message):
          if (message.sender == 'parent' &&
              message.status != VideoMessageStatus.seen) {
            unread++;
          }
      }
    }
    final String preview;
    switch (last) {
      case null:
        // Default neytral — "yozmoqda" degan taassurot bermasin.
        preview = 'Suhbatni boshlang';
      case VideoItem():
        preview = '📹 Video xabar';
      case VoiceItem(:final message):
        preview = message.isText ? (message.text ?? '') : 'Ovozli xabar';
    }
    final name = (parentName != null && parentName.trim().isNotEmpty)
        ? parentName.trim()
        : 'Ota-ona';
    return [
      _ChatRow(
        name: name,
        letter: name[0].toUpperCase(),
        color: _blue,
        lastMessage: preview,
        time: _timeLabel(last?.createdAt),
        unread: unread,
        online: true,
        onTap: () => context.push('/voice-chat'),
      ),
    ];
  }

  // ── PREVIEW: Figma'dagi qatorlar (pairing yo'q bo'lsa) ──
  List<Widget> _previewRows(BuildContext context) {
    return [
      _ChatRow(
        name: 'Nodira',
        letter: 'N',
        color: const Color(0xFFEF7DA0),
        lastMessage: 'Uyga kirib obed qilib ket',
        time: '11:41',
        unread: 2,
        online: true,
        onTap: () => context.push('/voice-chat'),
      ),
      _ChatRow(
        name: 'Akmal',
        letter: 'A',
        color: const Color(0xFF41DD7A),
        lastMessage: 'Matemmatikaga kech qolma',
        time: '12 sen',
        unread: 0,
        online: false,
        onTap: () => context.push('/voice-chat'),
      ),
    ];
  }
}

// ════════════ Chat qatori (Figma) ════════════

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.name,
    required this.letter,
    required this.color,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.online,
    required this.onTap,
  });

  final String name;
  final String letter;
  final Color color;
  final String lastMessage;
  final String time;
  final int unread;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x12FFFFFF)),
        ),
        child: Row(
          children: [
            // Avatar + onlayn nuqta.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Text(letter, style: _unb(18, w: FontWeight.w800)),
                ),
                if (online)
                  Positioned(
                    left: 1,
                    bottom: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: _online,
                        shape: BoxShape.circle,
                        border: Border.all(color: _card, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(16, w: FontWeight.w600, ls: -0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(13, c: _dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(time, style: _pop(12, c: _dim)),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: _pop(11.5, w: FontWeight.w600),
                    ),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ SOS tasdiqlash oynasi (Figma) ════════════

void _showSosDialog(BuildContext context) {
  HapticFeedback.mediumImpact();
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1C2026),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: const _SosDialogContent(),
    ),
  );
}

class _SosDialogContent extends ConsumerStatefulWidget {
  const _SosDialogContent();

  @override
  ConsumerState<_SosDialogContent> createState() => _SosDialogContentState();
}

class _SosDialogContentState extends ConsumerState<_SosDialogContent> {
  bool _sending = false;
  bool _sent = false;
  String? _error;

  Future<void> _confirm() async {
    if (_sending || _sent) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    HapticFeedback.heavyImpact();
    await ref.read(sosStateProvider.notifier).send();
    if (!mounted) return;
    final s = ref.read(sosStateProvider);
    if (s.status == SosStatus.sent) {
      setState(() {
        _sending = false;
        _sent = true;
      });
      // Bir lahza "yuborildi" ko'rsatib, o'zi yopiladi.
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.of(context).pop();
      ref.read(sosStateProvider.notifier).reset();
    } else {
      setState(() {
        _sending = false;
        _error = s.errorMessage ?? 'SOS yuborilmadi';
      });
      ref.read(sosStateProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Qizil SOS doira (Figma).
          Container(
            width: 106,
            height: 106,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0, -0.3),
                colors: [Color(0xFFEF5350), Color(0xFF8E1B1B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _sosRed.withValues(alpha: 0.55),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Text('SOS', style: _unb(27, w: FontWeight.w800, ls: 0)),
          ),
          const SizedBox(height: 20),
          Text(
            'DIQQAT! Siz SOS xabar!',
            textAlign: TextAlign.center,
            style: _unb(21, w: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _sent
                ? 'SOS xabar yuborildi — ota-onangizga darhol '
                      'bildirishnoma boradi.'
                : 'Siz haqiqatdan SOS xabar yubormoqchimisiz?',
            textAlign: TextAlign.center,
            style: _pop(13, c: _sent ? _online : _dim),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: _pop(12.5, c: const Color(0xFFFF6B6B)),
            ),
          ],
          const SizedBox(height: 22),
          if (_sent)
            Container(
              width: double.infinity,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _online.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _online),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, color: _online),
                  const SizedBox(width: 8),
                  Text(
                    'Yuborildi!',
                    style: _pop(15, w: FontWeight.w600, c: _online),
                  ),
                ],
              ),
            )
          else
            _SlideToSend(sending: _sending, onConfirmed: _confirm),
        ],
      ),
    );
  }
}

/// Uchta qizil chevron guruhi — Figma'dagi "⟩⟩⟩" belgisi.
class _Chevrons extends StatelessWidget {
  const _Chevrons();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Align(
            widthFactor: 0.45,
            child: Icon(
              Icons.chevron_right_rounded,
              color: _sosRed.withValues(alpha: 0.55 + i * 0.22),
              size: 22,
            ),
          ),
      ],
    );
  }
}

/// "Surib yuborish" nazorati — knob'ni oxirigacha surganda SOS ketadi
/// (tasodifiy bosilishdan himoya, Figma dizayni).
class _SlideToSend extends StatefulWidget {
  const _SlideToSend({required this.sending, required this.onConfirmed});

  final bool sending;
  final VoidCallback onConfirmed;

  @override
  State<_SlideToSend> createState() => _SlideToSendState();
}

class _SlideToSendState extends State<_SlideToSend> {
  double _drag = 0;
  static const double _knob = 52;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final maxDrag = cons.maxWidth - _knob - 8;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              _sosRed.withValues(alpha: 0.14),
              const Color(0xFF14161B),
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _sosRed.withValues(alpha: 0.35)),
          ),
          child: Stack(
            children: [
              // Markazdagi yozuv + qizil chevron guruhlari (Figma).
              Center(
                child: widget.sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Chevrons(),
                          const SizedBox(width: 10),
                          Text(
                            'SOS xabar yuborish',
                            style: _unb(13, w: FontWeight.w600, ls: 0),
                          ),
                          const SizedBox(width: 10),
                          const _Chevrons(),
                        ],
                      ),
              ),
              // Suriladigan SOS knob.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                left: 4 + _drag,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.sending
                      ? null
                      : (d) => setState(
                          () => _drag = (_drag + d.delta.dx).clamp(0, maxDrag),
                        ),
                  onHorizontalDragEnd: widget.sending
                      ? null
                      : (_) {
                          if (_drag >= maxDrag * 0.7) {
                            setState(() => _drag = maxDrag);
                            widget.onConfirmed();
                          } else {
                            setState(() => _drag = 0);
                          }
                        },
                  child: Container(
                    width: _knob,
                    height: _knob,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFE53935), Color(0xFF9E1C1C)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _sosRed.withValues(alpha: 0.5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Text(
                      'SOS',
                      style: _unb(13, w: FontWeight.w800, ls: 0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
