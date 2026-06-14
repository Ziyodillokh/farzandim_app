// ─────────────────────────────────────────────────────────────────────
// NotificationTabs — "Barchasi" / "Yangiliklar" segmented control
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationTabs extends ConsumerWidget {
  const NotificationTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(notificationTabProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // Dark pill — bildirishnoma ekrani dark (mockup'ga mos).
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'notifications.tabAll'.tr(),
              active: activeTab == NotificationTab.all,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(notificationTabProvider.notifier).state =
                    NotificationTab.all;
              },
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'notifications.tabUnread'.tr(),
              active: activeTab == NotificationTab.unread,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(notificationTabProvider.notifier).state =
                    NotificationTab.unread;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : const Color(0xFF8E8EA3),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
