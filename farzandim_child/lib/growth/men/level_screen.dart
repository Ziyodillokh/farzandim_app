// I06 · Daraja va nishonlar: DON sarflanmaydi — har 150 DON yangi daraja.
// DON qanday yig'ilishi (amaldagi manbalar) va nishonlar katalogi: olingan
// va hali qulflangan. Sezgir so'rov va murojaatlar uchun DON yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:farzandim_child/growth/men/data/men_repository.dart';
import 'package:farzandim_child/growth/men/men_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:go_router/go_router.dart';

class MeLevelScreen extends ConsumerWidget {
  const MeLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final don = ref.watch(backendGamificationProvider).valueOrNull?.don ?? 0;
    final earned = {
      for (final b in ref.watch(badgesProvider).valueOrNull ?? <BadgeState>[])
        if (b.earned) b.id,
    };
    final level = donLevel(don);
    final badges = kVisibleBadges;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.level.title'.tr(),
        ),
        onRefresh: () async => ref
          ..invalidate(backendGamificationProvider)
          ..invalidate(badgesProvider),
        dock: GButton(
          label: 'g5.men.level.donHistory'.tr(),
          kind: GButtonKind.ghost,
          icon: GIcons.coins,
          onPressed: () => GrowthLinks.meDon(context),
        ),
        children: [
          GGlass(
            kind: GGlassKind.feat,
            glowHue: GHue.gold,
            child: MergeSemantics(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CustomPaint(
                            painter: GProgressRingPainter(
                              donLevelProgress(don),
                              colors: const [
                                Color(0xFFFFD27A),
                                Color(0xFFF59E0B),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$level', style: GText.display(28)),
                            Text('$don DON', style: GText.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'g5.men.level.level'.tr(namedArgs: {'n': '$level'}),
                          style: GText.h2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'g5.men.level.toNext'.tr(
                            namedArgs: {
                              'next': '${level + 1}',
                              'don': '${donToNextLevel(don)}',
                            },
                          ),
                          style: GText.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          GSection(
            title: 'g5.men.level.how'.tr(),
            child: GList(
              children: [
                _How(GIcons.sparkle, GHue.blue, 'g5.men.level.howLearning'),
                _How(GIcons.footprints, GHue.green, 'g5.men.level.howSteps'),
                _How(GIcons.trophy, GHue.gold, 'g5.men.level.howOlympiad'),
                if (kShowAudioVideo)
                  _How(GIcons.bookOpen, GHue.teal, 'g5.men.level.howBooks'),
              ],
            ),
          ),
          GNote(
            text:
                '${'g5.men.level.notSpent'.tr(namedArgs: {'per': '$kDonPerLevel'})} ${'g5.men.don.noDonFor'.tr()}',
            kind: GNoteKind.plain,
          ),
          GSection(
            title: 'g5.men.level.badges'.tr(),
            // Qatorlar balandligi matnga moslashadi (ru/en va katta shriftda
            // qat'iy nisbatli grid toshib ketardi).
            child: Column(
              children: [
                for (var i = 0; i < badges.length; i += _badgesPerRow)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = i; j < i + _badgesPerRow; j++) ...[
                            if (j > i) const SizedBox(width: 10),
                            Expanded(
                              child: j < badges.length
                                  ? _Badge(
                                      id: badges[j],
                                      earned: earned.contains(badges[j]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _badgesPerRow = 3;

class _How extends StatelessWidget {
  const _How(this.icon, this.hue, this.labelKey);

  final GIconData icon;
  final GHue hue;
  final String labelKey;

  @override
  Widget build(BuildContext context) => GListItem(
    leading: GTile(icon: icon, hue: hue, size: 40),
    title: labelKey.tr(),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.id, required this.earned});

  final String id;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final look = badgeLook(id);
    return Semantics(
      container: true,
      label:
          '${badgeTitle(id)}: ${(earned ? 'g5.men.level.earned' : 'g5.men.level.locked').tr()}',
      child: ExcludeSemantics(
        child: GGlass(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          child: Opacity(
            opacity: earned ? 1 : .45,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GTile(
                      icon: look.icon,
                      hue: earned ? look.hue : GHue.slate,
                      size: 48,
                    ),
                    if (!earned)
                      const Positioned(
                        right: -4,
                        bottom: -4,
                        child: GIcon(
                          GIcons.lock,
                          size: 16,
                          color: GColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  badgeTitle(id),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GText.onest(12, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  earned ? 'g5.men.level.earned'.tr() : badgeHint(id),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GText.onest(11, color: GColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
