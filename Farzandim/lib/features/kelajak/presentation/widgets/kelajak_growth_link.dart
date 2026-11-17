// ─────────────────────────────────────────────────────────────────────
// KelajakGrowthLink — Growth sahifasidan Kelajak'ka kichik havola
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard kartasi bilan bir xil qoida: Kelajak mavjud emas, yuklanmoqda,
// xato yoki yosh 7–18 dan tashqari (javobsiz) bo'lsa ko'rinmaydi.
// Ko'rinsa tepasida 10px oraliq. Uslub Growth kartalari bilan bir xil.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakGrowthLink extends ConsumerWidget {
  const KelajakGrowthLink({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(kelajakSummaryProvider(childId)).valueOrNull;
    if (KelajakCardMode.of(summary) is KelajakCardHidden) {
      return const SizedBox.shrink();
    }
    final br = BorderRadius.circular(24);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: kelajakCard,
        shape: RoundedRectangleBorder(
          borderRadius: br,
          side: const BorderSide(color: kelajakCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.kelajakPath(childId)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const KelajakIconBadge(icon: SolarIconsBold.compass, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'kelajak.link.title'.tr(),
                        style: kelajakPop(15, w: FontWeight.w600),
                      ),
                      Text(
                        'kelajak.link.body'.tr(),
                        style: kelajakPop(12.5, c: kelajakDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  SolarIconsBold.altArrowRight,
                  size: 22,
                  color: kelajakDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
