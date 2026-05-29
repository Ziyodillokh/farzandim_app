// ─────────────────────────────────────────────────────────────────────
// StatusBadge — "Boshlovchi" / "Izlanuvchi" pill badge
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final GamificationStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 16),
          const SizedBox(width: 6),
          Text(
            status.translationKey.tr(),
            style: TextStyle(
              color: status.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'gamification.levelRange'
                .tr(namedArgs: {'range': status.levelRange}),
            style: TextStyle(
              // ignore: deprecated_member_use
              color: status.color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
