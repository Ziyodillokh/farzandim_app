// Bosh sahifa — "Kelajagim" kartasi ("Bugungi testlar"dan keyin): kunlik
// savollar holati va tugma ("Boshlash" / "Davom etish" / "Natijani
// ko'rish"). Yosh kiritilmagan bo'lsa — profilga yo'naltirish. Kelajak
// mavjud bo'lmasa (server bilmaydi, yosh 7–18 dan tashqarida, ulanmagan
// yoki hali yuklanmagan) — karta ham, ustidagi bo'shliq ham yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakTodayCard extends ConsumerWidget {
  const KelajakTodayCard({super.key});

  /// Karta ustidagi bo'shliq (bosh sahifa bo'limlari orasidagidek).
  static const topGap = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(kelajakAvailableProvider)) return const SizedBox.shrink();
    final overview = ref.watch(kelajakOverviewProvider).valueOrNull;
    if (overview == null) return const SizedBox.shrink();
    final isAgeRequired = overview.age.status == KelajakAgeStatus.ageRequired;
    final daily = overview.daily;
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
            decoration: homeCardDecoration(),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  subtitle: _subtitle(daily, state, isAgeRequired),
                  state: isAgeRequired ? null : state,
                ),
                const SizedBox(height: 12),
                if (isAgeRequired)
                  KelajakPillButton(
                    label: 'kelajak.age.requiredAction'.tr(),
                    icon: SolarIconsOutline.arrowRight,
                    onTap: () => openKelajakAgeEdit(context, ref),
                  )
                else
                  // Ikkilamchi uslub — tepadagi "Bugungi testlar" tugmasi
                  // bilan raqobatlashmaydi.
                  KelajakPillButton(
                    label: _actionLabel(daily, state),
                    icon: SolarIconsOutline.arrowRight,
                    isPrimary: false,
                    onTap: daily == null
                        ? () => openKelajakHub(context)
                        : () => openKelajakSession(context, daily.type),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _actionLabel(KelajakTestInfo? daily, KelajakDayState? state) {
    if (daily == null) return 'kelajak.home.openHub'.tr();
    if (state == KelajakDayState.fresh || state == null) {
      return 'kelajak.home.startDaily'.tr();
    }
    return kelajakActionKey(state).tr();
  }

  static String _subtitle(
    KelajakTestInfo? daily,
    KelajakDayState? state,
    bool isAgeRequired,
  ) {
    if (isAgeRequired) return 'kelajak.home.ageHint'.tr();
    if (daily == null) return 'kelajak.home.noDaily'.tr();
    return switch (state) {
      KelajakDayState.unfinished => 'kelajak.home.unfinished'.tr(),
      KelajakDayState.done => 'kelajak.home.done'.tr(),
      KelajakDayState.fresh || null => 'kelajak.home.fresh'.tr(
        namedArgs: {'meta': kelajakTestMeta(daily)},
      ),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle, required this.state});

  final String subtitle;
  final KelajakDayState? state;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    return Row(
      children: [
        const KelajakIconSquare(icon: SolarIconsBold.compass, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'kelajak.title'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeText(15.5, weight: FontWeight.w700, height: 1.25),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: homeText(12.5, color: HomeColors.textDim, height: 1.3),
              ),
            ],
          ),
        ),
        if (state != null) ...[
          const SizedBox(width: 8),
          KelajakStatusChip(state: state),
        ],
      ],
    );
  }
}
