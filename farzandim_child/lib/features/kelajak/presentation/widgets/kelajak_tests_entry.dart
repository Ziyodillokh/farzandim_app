// Testlar sahifasi — "Bugungi testlar" ostida "Kelajagim" qatori (hub'ga).
// Kunlik savollar holati belgisi bilan. Kelajak mavjud bo'lmasa — qator ham,
// ustidagi bo'shliq ham yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakTestsEntry extends ConsumerWidget {
  const KelajakTestsEntry({super.key});

  /// Qator ustidagi bo'shliq.
  static const topGap = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(kelajakAvailableProvider)) return const SizedBox.shrink();
    final daily = ref.watch(kelajakOverviewProvider).valueOrNull?.daily;
    final state = daily == null ? null : kelajakDayStateOf(daily.today);
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: Semantics(
        button: true,
        label: 'kelajak.title'.tr(),
        child: GestureDetector(
          onTap: () => openKelajakHub(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: homeCardDecoration(radius: 20),
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                const KelajakIconSquare(icon: SolarIconsBold.compass),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'kelajak.title'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(16, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'kelajak.tests.entryBody'.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          12.5,
                          color: HomeColors.textDim,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state != null) ...[
                  const SizedBox(width: 8),
                  KelajakStatusChip(state: state),
                ],
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: HomeColors.chevron,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
