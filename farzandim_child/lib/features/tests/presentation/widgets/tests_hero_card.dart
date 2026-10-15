// "Bugungi testlar" hero kartasi (Testlar sahifasi) — kunlik reja fanlari,
// "Boshlash" va o'ngda illyustratsiya.
//
// Kunlik test oqimi (Daily Learning) backend bilan quriladi. Hozircha fan
// plitkasi / "Boshlash" o'sha fanning HAQIQIY testlarini ochadi
// (`/tests/subject`); fan bo'yicha test bo'lmasa — xabar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:farzandim_child/features/tests/presentation/open_subject_tests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

const _heroTop = Color(0xFF00336E);
const _heroBottom = Color(0xFF001D3D);
const _heroBorder = Color(0xFF0B3F80);
const _tileBg = Color(0xFF012242);
const _tileBorder = Color(0xFF02376D);
const _iconSquare = Color(0xFF0A57CC);
const _button = Color(0xFF1274FC);
const _buttonBorder = Color(0xFF4A93FF);

/// Illyustratsiya (maketdan) — 240×424 px, kartaning o'ng chetida.
const _illustration = 'assets/illustrations/tests_hero.png';
const _illustrationAspect = 240 / 424;

/// O'ng tomonda illyustratsiyaga qoldiriladigan kenglik (plitkalar tugashi).
const _illustrationReserve = 116.0;

class TestsHeroCard extends ConsumerWidget {
  const TestsHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(dailyPlanProvider);
    if (plan.isEmpty) return const SizedBox.shrink();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _heroBorder),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_heroTop, _heroBottom],
          stops: [0, 0.65],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, c) =>
                  _Illustration(width: c.maxHeight * _illustrationAspect),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12.5),
            child: LayoutBuilder(
              builder: (context, c) {
                final left = c.maxWidth - _illustrationReserve + 10;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Matn illyustratsiyaga chiqmasin (uzun til / katta shrift
                    // bo'lsa qatorga o'tadi).
                    Container(
                      padding: const EdgeInsets.only(left: 5),
                      constraints: BoxConstraints(maxWidth: left + 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'home.todayTests'.tr(),
                            style: homeDisplay(21, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'home.todayTestsReady'.tr(
                              namedArgs: {'count': '${plan.items.length}'},
                            ),
                            style: homeText(13.8, color: HomeColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.only(left: 3.8),
                      child: SizedBox(
                        width: left - 3.8,
                        child: _PlanTiles(items: plan.items),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: left + 1.5,
                      child: _StartButton(
                        onTap: () => openSubjectTests(
                          context,
                          ref,
                          plan.items.map((i) => i.subject),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    // Chap cheti karta foniga silliq qo'shiladi.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        colors: [Color(0x00000000), Color(0xFF000000)],
        stops: [0, 0.22],
      ).createShader(rect),
      child: Image.asset(
        _illustration,
        width: width,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        errorBuilder: (_, __, ___) => SizedBox(width: width),
      ),
    );
  }
}

class _PlanTiles extends ConsumerWidget {
  const _PlanTiles({required this.items});

  final List<DailyPlanItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Maket — 3 ta plitka; ko'proq fan bo'lsa birinchi 3 tasi (qolgani
    // "Boshlash" orqali ochiladi).
    final shown = items.take(3).toList();
    return Row(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: 7.5),
          Expanded(
            child: _PlanTile(
              item: shown[i],
              onTap: () => openSubjectTests(context, ref, [shown[i].subject]),
            ),
          ),
        ],
        // 3 tadan kam bo'lsa plitkalar maketdagi kenglikda qoladi.
        for (var i = shown.length; i < 3; i++) ...[
          const SizedBox(width: 7.5),
          const Spacer(),
        ],
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.item, required this.onTap});

  final DailyPlanItem item;
  final VoidCallback onTap;

  /// Maketdagi balandlik va matn bloki (nom + oraliq + savollar soni) —
  /// katta shrift masshtabida plitka shu farqqa o'sadi.
  static const _baseHeight = 82.0;
  static const _textBlock = 11.5 * 1.2 + 3 + 11 * 1.2;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(_textBlock);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _baseHeight + (scaled - _textBlock).clamp(0, 40),
        padding: const EdgeInsets.fromLTRB(8.5, 9.5, 4, 0),
        decoration: BoxDecoration(
          color: _tileBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _tileBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SubjectIcon(
              subject: item.subject,
              size: 27.5,
              background: _iconSquare,
            ),
            const Spacer(),
            FitText(
              item.subject.labelKey.tr(),
              style: homeText(11.5, weight: FontWeight.w600, height: 1.2),
            ),
            const SizedBox(height: 3),
            FitText(
              'home.questions'.plural(item.questionCount),
              style: homeText(11, color: HomeColors.textDim, height: 1.2),
            ),
            const SizedBox(height: 5.5),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _button,
      shape: const StadiumBorder(side: BorderSide(color: _buttonBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'home.start'.tr(),
                style: homeText(13.5, weight: FontWeight.w600, height: 1.2),
              ),
              const SizedBox(width: 10),
              const Icon(
                SolarIconsOutline.arrowRight,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
