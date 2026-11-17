// B01 ko'rsatkichlari: seriya · DON · daraja (daraja bosilsa I06).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsStrip extends ConsumerWidget {
  const StatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Haqiqiy manba — backend (Firestore profili faqat zaxira), bosh sahifadagidek.
    final backend = ref.watch(backendGamificationProvider).valueOrNull;
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    final streak = backend?.streak ?? profile?.streak ?? 0;
    final don = backend?.don ?? profile?.don ?? 0;
    final level = backend?.level ?? 1;
    return Semantics(
      label: 'g5.today.stats.label'.tr(),
      container: true,
      child: GGlass(
        radius: 20,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  icon: GIcons.fire,
                  hue: GHue.orange,
                  value: '$streak',
                  label: 'g5.today.stats.streak'.tr(),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0x12FFFFFF),
              ),
              Expanded(
                child: _Stat(
                  icon: GIcons.coin,
                  hue: GHue.gold,
                  value: '$don',
                  label: 'g5.today.stats.don'.tr(),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0x12FFFFFF),
              ),
              Expanded(
                child: GPressable(
                  onTap: () => GrowthLinks.level(context),
                  semanticLabel: 'g5.today.stats.levelA11y'.tr(
                    namedArgs: {'level': '$level'},
                  ),
                  child: _Stat(
                    icon: GIcons.medal,
                    hue: GHue.sky,
                    value: '$level',
                    label: 'g5.today.stats.level'.tr(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.hue,
    required this.value,
    required this.label,
  });

  final GIconData icon;
  final GHue hue;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GSpace.minTap),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GTile(icon: icon, hue: hue, size: 34),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: GText.display(16).copyWith(height: 1.2),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GText.onest(11.5, color: GColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
