// B03 · Aloqa (1–4-sinf): «Ota-onam» (ovozli / video / matnli chat) va
// «Bola ovozi» (maktab psixologiga maxfiy yozish) — ikki katta karta. Faqat
// mavjudi ko'rsatiladi: chat — ota-onaga ulangan bolada, «Bola ovozi» —
// maktabga ulangan bolada; bittasi bo'lsa to'liq kenglikda. B01 da (G08) ular
// sarlavhadagi ikonlar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/voice_message_provider.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ota-onadan kelgan, hali ko'rilmagan xabarlar soni (xato / yo'q — 0).
final parentChatUnreadProvider = Provider.autoDispose<int>((ref) {
  final childId = ref.watch(pairingStateProvider.select((s) => s.childId));
  if (childId == null) return 0;
  return ref.watch(unreadVoiceMessagesCountProvider(childId)).valueOrNull ?? 0;
});

class ContactTiles extends ConsumerWidget {
  const ContactTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasParent = ref.watch(
      pairingStateProvider.select((s) => s.childId != null),
    );
    final hasSchool = ref.watch(isSchoolLinkedProvider);
    final tiles = [
      if (hasParent) const _ParentChatTile(),
      if (hasSchool) const _StudentVoiceTile(),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return GSection(
      title: 'g5.today.contact.title'.tr(),
      // Balandlik kontentga teng (ikki karta bir xil bo'yda).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tile in tiles) ...[
              if (tile != tiles.first) const SizedBox(width: 12),
              Expanded(child: tile),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParentChatTile extends ConsumerWidget {
  const _ParentChatTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(parentNameProvider).valueOrNull?.trim();
    final unread = ref.watch(parentChatUnreadProvider);
    return _ContactCard(
      icon: GIcons.chatCircleText,
      hue: GHue.rose,
      title: name == null || name.isEmpty
          ? 'g5.today.contact.parent'.tr()
          : name,
      body: unread > 0
          ? 'g5.today.contact.parentUnread'.tr(namedArgs: {'n': '$unread'})
          : 'g5.today.contact.parentBody'.tr(),
      badge: unread,
      action: 'g5.today.contact.parentAction'.tr(),
      onTap: () => context.push('/voice-chat'),
    );
  }
}

class _StudentVoiceTile extends StatelessWidget {
  const _StudentVoiceTile();

  @override
  Widget build(BuildContext context) => _ContactCard(
    icon: GIcons.handHeart,
    hue: GHue.sky,
    title: 'g5.today.contact.voice'.tr(),
    body: 'g5.today.contact.voiceBody'.tr(),
    action: 'g5.today.contact.voiceAction'.tr(),
    onTap: () => GrowthLinks.studentVoice(context),
  );
}

/// Katta aloqa kartasi: plita (ixtiyoriy yangi xabar belgisi), sarlavha,
/// izoh va pastda harakat qatori.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.hue,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
    this.badge = 0,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GPressable(
        onTap: onTap,
        pressedScale: .98,
        child: GGlass(
          glowHue: hue,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GTile(icon: icon, hue: hue, size: 48),
                  if (badge > 0)
                    Positioned(right: -6, top: -6, child: _Badge(count: badge)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GText.onest(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: GText.onest(13, color: GColors.textMuted, height: 1.35),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      action,
                      style: GText.onest(
                        13.5,
                        weight: FontWeight.w700,
                        color: hue.icon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GIcon(GIcons.arrowRight, size: 16, color: hue.icon),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GColors.danger,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: GColors.bg, width: 2),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: GText.onest(11, weight: FontWeight.w700),
      ),
    );
  }
}
