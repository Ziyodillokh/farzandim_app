// ─────────────────────────────────────────────────────────────────────
// NotificationTabs — "Barchasi" / "Yangiliklar" segmented pill
// ─────────────────────────────────────────────────────────────────────
//
// Oq sirpanuvchi indikator spring egri (cubic-bezier(.34,1.4,.5,1)) bilan
// suriladi. prefers-reduced-motion'da darhol (animatsiyasiz) ko'chadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/notification_tokens.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Spring egri — reference (cubic-bezier(.34,1.4,.5,1)).
const Cubic kSpring = Cubic(0.34, 1.4, 0.5, 1);

class NotificationTabs extends ConsumerWidget {
  const NotificationTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(notificationTabProvider);
    final isAll = tab == NotificationTab.all;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    void select(NotificationTab t) {
      HapticFeedback.selectionClick();
      ref.read(notificationTabProvider.notifier).state = t;
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          // Sirpanuvchi oq indikator.
          AnimatedAlign(
            alignment: isAll ? Alignment.centerLeft : Alignment.centerRight,
            duration: Duration(milliseconds: reduce ? 0 : 360),
            curve: kSpring,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: NotifTokens.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: NotifTokens.shadowSm,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _TabLabel(
                  label: 'notifications.tabAll'.tr(),
                  active: isAll,
                  onTap: () => select(NotificationTab.all),
                ),
              ),
              Expanded(
                child: _TabLabel(
                  label: 'notifications.tabUnread'.tr(),
                  active: !isAll,
                  onTap: () => select(NotificationTab.unread),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: active ? NotifTokens.ink : NotifTokens.muted,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14.5,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
