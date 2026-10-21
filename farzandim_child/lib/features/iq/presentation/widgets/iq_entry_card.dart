// "IQ test" kirish kartasi — bosh sahifada ("Kelajagim"dan keyin) va Testlar
// sahifasida. Holat qatori: davom ettirish / oxirgi natija darajasi /
// keyingi sana. IQ mavjud bo'lmasa — karta ham, bo'shliq ham yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:farzandim_child/features/iq/presentation/providers/iq_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class IqEntryCard extends ConsumerWidget {
  const IqEntryCard({super.key, this.topGap = 10});

  final double topGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(iqAvailableProvider)) return const SizedBox.shrink();
    final overview = ref.watch(iqOverviewProvider).valueOrNull;
    if (overview == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Semantics(
        button: true,
        label: 'iq.title'.tr(),
        child: GestureDetector(
          onTap: () => openIqHub(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: homeCardDecoration(radius: 20),
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                const KelajakIconSquare(icon: SolarIconsBold.lightbulb),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'iq.title'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(16, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(context, overview),
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

  static String _subtitle(BuildContext context, IqOverview o) {
    if (o.age.status == IqAgeStatus.ageRequired) {
      return 'iq.hub.ageRequired'.tr();
    }
    final active = o.active;
    if (active != null) {
      return 'iq.entry.continue'.tr(
        namedArgs: {'n': '${active.answered}', 'total': '${active.total}'},
      );
    }
    final last = o.last;
    if (last != null) {
      return 'iq.entry.last'.tr(namedArgs: {'band': iqBandLabel(last.band)});
    }
    return 'iq.entry.body'.tr();
  }
}
