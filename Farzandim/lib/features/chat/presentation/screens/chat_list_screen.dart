// ─────────────────────────────────────────────────────────────────────
// ChatListScreen — "Chatlar" (Parvoz dizayn, REAL backend)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi chat ikonasidan ochiladi. Chat = ota-ona ↔ bola: har bola
// bitta chat. Real: sortedChildrenForVoiceProvider + latestVoiceMessage +
// unreadVoiceMessages. Bola bosilsa chat detali (ChatDetailScreen) ochiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF12171E);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x8CFFFFFF);
const _online = Color(0xFF34C759);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(fontSize: s, fontWeight: w, color: c, height: 1.25);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.4);

String _timeLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  if (that == today) {
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
  final diff = today.difference(that).inDays;
  if (diff == 1) return 'kecha';
  return '$diff kun';
}

String _preview(VoiceMessage? m) {
  if (m == null) return 'Suhbatni boshlang';
  if (m.isText) return m.text ?? '';
  if (m.isImage) return '📷 Rasm';
  if (m.isFile) return '📎 Fayl';
  return '🎤 Ovozli xabar';
}

/// "Chatlar" ro'yxati ekrani (real).
class ChatListScreen extends ConsumerWidget {
  /// `ChatListScreen` konstruktor.
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(sortedChildrenForVoiceProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              child: Row(
                children: [
                  _BackButton(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.dashboard);
                    }
                  }),
                  Expanded(
                    child: Text('chat.title'.tr(),
                        textAlign: TextAlign.center, style: _unb(22)),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: children.isEmpty
                  ? _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: children.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _ChatTile(child: children[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(SolarIconsBold.chatRoundLine, size: 46, color: _dim),
            const SizedBox(height: 14),
            Text("Hali bola qo'shilmagan",
                textAlign: TextAlign.center, style: _pop(15, c: _dim)),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestVoiceMessageProvider(child.id)).valueOrNull;
    final unread =
        ref.watch(unreadVoiceMessagesProvider(child.id)).valueOrNull ?? 0;
    final online = child.isLiveOnline;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.chatDetailPath(child.id)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _fieldBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                children: [
                  ChildAvatar(child: child, size: 52, showBorder: false),
                  if (online)
                    Positioned(
                      right: 1,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(16)),
                  const SizedBox(height: 3),
                  Text(_preview(latest),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(13, c: _dim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(latest == null ? '' : _timeLabel(latest.createdAt),
                    style: _pop(12, c: _dim)),
                const SizedBox(height: 8),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 22),
                    decoration: const BoxDecoration(
                        color: _blue, shape: BoxShape.circle),
                    child: Text('$unread',
                        textAlign: TextAlign.center,
                        style: _pop(11, w: FontWeight.w700)),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

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
        child: const Icon(SolarIconsOutline.arrowLeft,
            size: 22, color: Colors.white),
      ),
    );
  }
}
