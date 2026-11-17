// Test yakunlangach shu sahifada: "Bugungi natijangiz" — qo'llab-quvvatlash
// xabari (faqat server bergan bo'lsa; raqam ham, tashxis ham yo'q), besh ✓
// bo'lim, ogohlantirish va pastda "Kelajagim" / "Bosh sahifa" tugmalari.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/result/kelajak_result_sections.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

const _sectionGap = 12.0;

class KelajakResultView extends StatelessWidget {
  const KelajakResultView({
    super.key,
    required this.result,
    required this.testType,
    required this.onOpenTest,
    required this.onHub,
    required this.onHome,
  });

  final KelajakResult result;
  final String testType;

  /// Keyingi tavsiyadagi testni ochish (tur).
  final ValueChanged<String> onOpenTest;
  final VoidCallback onHub;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final insights = result.insights;
    final support = insights.support;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('kelajak-result'),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            children: [
              _Header(result: result),
              if (support != null) ...[
                const SizedBox(height: 16),
                _SupportCard(message: support.message.inLocale(context)),
              ],
              const SizedBox(height: 16),
              ..._sections(context, insights),
              const SizedBox(height: 16),
              KelajakNote(
                result.disclaimer?.inLocale(context) ??
                    'kelajak.result.disclaimer'.tr(),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 14),
          decoration: const BoxDecoration(
            color: HomeColors.bg,
            border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: KelajakPillButton(
                  label: 'kelajak.result.toHome'.tr(),
                  isPrimary: false,
                  height: 52,
                  onTap: onHome,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: SetupButton(
                  label: 'kelajak.result.toHub'.tr(),
                  onTap: onHub,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context, KelajakInsights insights) {
    final sections = [
      KelajakResultSection(
        title: 'kelajak.result.strengths'.tr(),
        child: KelajakStrengthsContent(strengths: insights.strengths),
      ),
      KelajakResultSection(
        title: 'kelajak.result.interests'.tr(),
        child: KelajakInterestsContent(
          interests: insights.interests,
          dimensions: result.interests,
        ),
      ),
      KelajakResultSection(
        title: 'kelajak.result.liked'.tr(),
        child: KelajakLikedContent(directions: insights.likedDirections),
      ),
      KelajakResultSection(
        title: 'kelajak.result.growth'.tr(),
        child: KelajakGrowthContent(areas: insights.growthAreas),
      ),
      KelajakResultSection(
        title: 'kelajak.result.next'.tr(),
        child: KelajakNextContent(
          next: insights.next,
          currentType: testType,
          onOpenTest: onOpenTest,
        ),
      ),
    ];
    return [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: _sectionGap),
        sections[i],
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.result});

  final KelajakResult result;

  @override
  Widget build(BuildContext context) {
    final answered = result.total > 0
        ? 'kelajak.result.answered'.tr(
            namedArgs: {
              'answered': '${result.answered}',
              'total': '${result.total}',
            },
          )
        : null;
    return Row(
      children: [
        const KelajakIconSquare(
          icon: SolarIconsBold.cupStar,
          color: HomeColors.green,
          size: 48,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'kelajak.result.title'.tr(),
                style: homeDisplay(22, letterSpacing: -0.3, height: 1.2),
              ),
              if (answered != null) ...[
                const SizedBox(height: 3),
                Text(
                  answered,
                  style: homeText(13, color: HomeColors.textDim, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Mehribon qo'llab-quvvatlash xabari (darajasi va raqami ko'rsatilmaydi).
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: HomeColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            SolarIconsBold.handHeart,
            size: 22,
            color: HomeColors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: homeText(14, weight: FontWeight.w500, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
