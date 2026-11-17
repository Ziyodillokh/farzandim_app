// ─────────────────────────────────────────────────────────────────────
// kelajak_sections — qiziqishlar, kuchli tomonlar, rivojlantirish va
// keyingi tavsiya bo'limlari
// ─────────────────────────────────────────────────────────────────────
//
// Qiziqishlar: backend matni ("...qiziqish yuqori. Quyidagi
// yo'nalishlarni sinab ko'rish mumkin.") va soha pill'lari — hukm emas,
// sinab ko'rish uchun g'oyalar. Profil hali ishonchli bo'lmasa —
// "javoblar hali yetarli emas" izohi. Bo'sh ro'yxatli bo'lim chizilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_insights.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Qiziqish yuqori bo'lgan yo'nalishlar va sinab ko'rish mumkin bo'lgan
/// sohalar.
class KelajakInterestsSection extends StatelessWidget {
  const KelajakInterestsSection({required this.summary, super.key});

  final KelajakSummary summary;

  @override
  Widget build(BuildContext context) {
    final interests = summary.insights.interests;
    return KelajakSection(
      icon: SolarIconsBold.lightbulb,
      iconColor: kelajakAmber,
      title: 'kelajak.interests.title'.tr(),
      hint: interests.isEmpty ? null : 'kelajak.interests.hint'.tr(),
      child: interests.isEmpty
          ? Text(
              'kelajak.interests.forming'.tr(),
              style: kelajakPop(13, c: kelajakDim),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: kelajakSpaced(
                interests.map((i) => _InterestTile(insight: i)),
                gap: 16,
              ),
            ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.insight});

  final KelajakInterestInsight insight;

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      for (final s in insight.suggestions) kelajakText(context, s),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KelajakTextTile(
          title: kelajakText(context, insight.title),
          body: kelajakText(context, insight.body),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'kelajak.interests.try'.tr(),
            style: kelajakPop(12, w: FontWeight.w500, c: kelajakDim),
          ),
          const SizedBox(height: 6),
          KelajakChipWrap(labels: suggestions),
        ],
      ],
    );
  }
}

/// Kuchli tomonlar (bo'sh bo'lsa chizilmaydi).
class KelajakStrengthsSection extends StatelessWidget {
  const KelajakStrengthsSection({required this.strengths, super.key});

  final List<KelajakStrength> strengths;

  @override
  Widget build(BuildContext context) {
    if (strengths.isEmpty) return const SizedBox.shrink();
    return KelajakSection(
      icon: SolarIconsBold.cupStar,
      iconColor: kelajakGreen,
      title: 'kelajak.strengths.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kelajakSpaced(
          strengths.map((s) => _CheckRow(text: kelajakText(context, s.title))),
          gap: 8,
        ),
      ),
    );
  }
}

/// Rivojlantirish mumkin bo'lgan jihatlar va maslahatlar.
class KelajakGrowthAreasSection extends StatelessWidget {
  const KelajakGrowthAreasSection({required this.areas, super.key});

  final List<KelajakGrowthArea> areas;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) return const SizedBox.shrink();
    return KelajakSection(
      icon: SolarIconsBold.target,
      iconColor: kelajakBlue,
      title: 'kelajak.growthAreas.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kelajakSpaced(
          areas.map(
            (a) => KelajakTextTile(
              title: kelajakText(context, a.title),
              body: kelajakText(context, a.tip),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyingi tavsiya (test yechish, ertaga qaytish).
class KelajakNextSection extends StatelessWidget {
  const KelajakNextSection({required this.steps, super.key});

  final List<KelajakNextStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return KelajakSection(
      icon: SolarIconsBold.arrowRightUp,
      iconColor: kelajakBlue,
      title: 'kelajak.next.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kelajakSpaced(
          steps.map(
            (s) => KelajakTextTile(
              title: kelajakText(context, s.title),
              body: kelajakText(context, s.body),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✓ belgili qator.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            SolarIconsBold.checkCircle,
            size: 18,
            color: kelajakGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: kelajakPop(14, w: FontWeight.w500)),
        ),
      ],
    );
  }
}
