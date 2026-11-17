// ─────────────────────────────────────────────────────────────────────
// KelajakHeader — Kelajak sahifasi tepasi
// ─────────────────────────────────────────────────────────────────────
//
// Bola (avatar, ism, yosh guruhi), yechilgan testlar soni va oxirgi
// faollik sanasi. Raqam faqat testlar soni — ball yoki foiz yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakHeader extends ConsumerWidget {
  const KelajakHeader({
    required this.childId,
    required this.summary,
    super.key,
  });

  final String childId;
  final KelajakSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final group = summary.age.ageGroup;
    final last = summary.lastCompletedAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kelajakCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kelajakCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (child != null)
                ChildAvatar(child: child, size: 44, showBorder: false)
              else
                const KelajakIconBadge(icon: SolarIconsBold.compass, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      child?.name ?? 'kelajak.title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kelajakPop(16, w: FontWeight.w600),
                    ),
                    if (group != null)
                      Text(
                        'kelajak.header.ageGroup'.tr(
                          namedArgs: {'group': kelajakAgeGroupLabel(group)},
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kelajakPop(12.5, c: kelajakDim),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: SolarIconsBold.checklist,
                  value: '${summary.sessionsCompleted}',
                  label: 'kelajak.header.sessions'.tr(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: SolarIconsBold.calendarMark,
                  value: last == null
                      ? 'kelajak.header.noActivity'.tr()
                      : formatSchoolDate(last),
                  label: 'kelajak.header.lastActivity'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kichik ko'rsatkich: ikon, qiymat, yorliq.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: kelajakChipBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: kelajakBlue),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kelajakUnb(15),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kelajakPop(11.5, c: kelajakDim),
            ),
          ],
        ),
      ),
    );
  }
}
