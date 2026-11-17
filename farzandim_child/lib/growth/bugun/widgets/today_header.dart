// B01 sarlavhasi (G08): salomlashuv va ism, «Aloqa» ikonlari (Ota-onam,
// Bola ovozi, bildirishnomalar) va SOS.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/bugun/widgets/contact_tiles.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Kun vaqtiga qarab salomlashuv kaliti.
String greetingKey(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 11) return 'g5.today.greeting.morning';
  if (hour >= 11 && hour < 17) return 'g5.today.greeting.day';
  if (hour >= 17 && hour < 23) return 'g5.today.greeting.evening';
  return 'g5.today.greeting.night';
}

/// To'liq ismdan birinchi ism («Aziza Karimova» → «Aziza»).
String firstName(String? fullName) {
  final trimmed = fullName?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

class TodayHeader extends ConsumerWidget {
  const TodayHeader({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = firstName(ref.watch(pairingStateProvider).childName);
    final shownName = name.isEmpty ? 'g5.today.friend'.tr() : name;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greetingKey(now).tr(),
                  style: GText.onest(13, color: GColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '$shownName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GText.display(20),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const _ContactPill(),
        const SizedBox(width: 10),
        SosPill(onTap: () => GrowthLinks.sos(context)),
      ],
    );
  }
}

/// G08: «Aloqa» sarlavhada — «Ota-onam» chati (ota-onaga ulangan bolada),
/// «Bola ovozi» (maktabga ulangan bolada) va bildirishnomalar bitta shisha
/// pilyulada. Yangi xabar bo'lsa ikon burchagida nuqta.
class _ContactPill extends ConsumerWidget {
  const _ContactPill();

  static const _chatDot = Color(0xFFFB7185);
  static const _bellDot = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasParent = ref.watch(
      pairingStateProvider.select((s) => s.childId != null),
    );
    final hasSchool = ref.watch(isSchoolLinkedProvider);
    final chatUnread = hasParent ? ref.watch(parentChatUnreadProvider) : 0;
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final parent = 'g5.today.contact.parent'.tr();
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color(0x0EFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasParent)
            _PillIcon(
              icon: GIcons.chatCircleText,
              color: GHue.rose.icon,
              label: chatUnread > 0
                  ? '$parent, ${'g5.today.contact.parentUnread'.tr(namedArgs: {'n': '$chatUnread'})}'
                  : parent,
              dot: chatUnread > 0 ? _chatDot : null,
              onTap: () => context.push('/voice-chat'),
            ),
          if (hasSchool)
            _PillIcon(
              icon: GIcons.handHeart,
              color: GHue.sky.icon,
              label:
                  '${'g5.today.contact.voice'.tr()}. ${'g5.today.contact.voiceBody'.tr()}',
              onTap: () => GrowthLinks.studentVoice(context),
            ),
          _PillIcon(
            icon: GIcons.bell,
            color: GColors.text,
            label: unread > 0
                ? 'g5.today.notificationsNew'.tr(
                    namedArgs: {'count': '$unread'},
                  )
                : 'g5.today.notifications'.tr(),
            dot: unread > 0 ? _bellDot : null,
            onTap: () => GrowthLinks.notifications(context),
          ),
        ],
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.dot,
  });

  final GIconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  /// Yangi xabar nuqtasining rangi (`null` — nuqta yo'q).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox.square(
        // 44 + pilyula chegarasi — bosish maydoni 48px dan kam emas.
        dimension: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GIcon(icon, size: 21, color: color),
            if (dot != null)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot,
                    border: Border.all(
                      color: const Color(0xFF0B1226),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// SOS tugmasi (B01, B03): pushti chip ko'rinishida, 48px.
class SosPill extends StatelessWidget {
  const SosPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onTap,
      semanticLabel: 'g5.today.sos'.tr(),
      child: Container(
        height: GSpace.minTap,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: GChipKind.sos.fill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GChipKind.sos.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFB7185),
                boxShadow: [BoxShadow(color: Color(0xFFFB7185), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'SOS',
              style: GText.display(
                12,
                weight: FontWeight.w700,
              ).copyWith(color: GChipKind.sos.text, letterSpacing: 12 * .08),
            ),
          ],
        ),
      ),
    );
  }
}
