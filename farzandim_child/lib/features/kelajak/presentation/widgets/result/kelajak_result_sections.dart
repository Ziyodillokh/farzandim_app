// "Bugungi natijangiz" bo'limlari — server tavsiyalaridan, sodda tilda:
// ✓ kuchli tomonlar, ✓ qiziqishlar, ✓ yoqqan yo'nalishlar, ✓ rivojlantirish
// mumkin bo'lgan jihatlar, ✓ keyingi tavsiya. Kasb bo'yicha qat'iy hukm
// yo'q; bo'lim bo'sh bo'lsa — mehribon izoh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bo'lim kartasi: ✓ belgisi, sarlavha va mazmun.
class KelajakResultSection extends StatelessWidget {
  const KelajakResultSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: homeCardDecoration(radius: 18),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: HomeColors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: homeText(16, weight: FontWeight.w800, height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Sarlavha + izoh qatori (qiziqish, rivojlanish, tavsiya).
class _Item extends StatelessWidget {
  const _Item({required this.title, this.body, this.extra});

  final String title;
  final String? body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final body = this.body?.trim() ?? '';
    final extra = this.extra;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: homeText(14.5, weight: FontWeight.w700)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            body,
            style: homeText(13, color: HomeColors.textDim, height: 1.45),
          ),
        ],
        if (extra != null) ...[const SizedBox(height: 8), extra],
      ],
    );
  }
}

List<Widget> _spaced(List<Widget> items) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) const SizedBox(height: 12),
    items[i],
  ],
];

/// ✓ Kuchli tomonlaringiz.
class KelajakStrengthsContent extends StatelessWidget {
  const KelajakStrengthsContent({super.key, required this.strengths});

  final List<KelajakStrength> strengths;

  @override
  Widget build(BuildContext context) {
    if (strengths.isEmpty) {
      return KelajakNote('kelajak.result.strengthsEmpty'.tr());
    }
    return KelajakChipWrap(
      labels: [for (final s in strengths) s.title.inLocale(context)],
    );
  }
}

/// ✓ Qiziqishlaringiz: ishonchli yo'nalishlar (sinab ko'rish mumkin bo'lgan
/// sohalar bilan); hali aniq bo'lmasa — dastlabki kuzatuv (faqat nomlar).
class KelajakInterestsContent extends StatelessWidget {
  const KelajakInterestsContent({
    super.key,
    required this.interests,
    this.dimensions,
  });

  final List<KelajakInterestInsight> interests;

  /// Shu sessiya / profil o'lchamlari (yo'nalish tavsiyasi yo'q bo'lsa).
  final KelajakInterests? dimensions;

  @override
  Widget build(BuildContext context) {
    if (interests.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spaced([for (final i in interests) _interest(context, i)]),
      );
    }
    final early = _earlyNames(context);
    if (early.isEmpty) {
      return KelajakNote('kelajak.result.interestsEmpty'.tr());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KelajakChipWrap(labels: early),
        const SizedBox(height: 10),
        KelajakNote('kelajak.result.interestsEarly'.tr()),
      ],
    );
  }

  Widget _interest(BuildContext context, KelajakInterestInsight interest) {
    final suggestions = [
      for (final s in interest.suggestions) s.inLocale(context),
    ];
    return _Item(
      title: interest.title.inLocale(context),
      body: interest.body?.inLocale(context),
      extra: suggestions.isEmpty
          ? null
          : Text(
              'kelajak.result.tryLabel'.tr(
                namedArgs: {'list': suggestions.join(', ')},
              ),
              style: homeText(13, weight: FontWeight.w600, height: 1.45),
            ),
    );
  }

  /// Eng yuqori o'lchamlar nomi (`top` tartibida).
  List<String> _earlyNames(BuildContext context) {
    final source = dimensions;
    if (source == null) return const [];
    return [
      for (final code in source.top)
        for (final d in source.dimensions)
          if (d.code == code) d.name.inLocale(context),
    ];
  }
}

/// ✓ Sizga yoqqan yo'nalishlar (Career Lab).
class KelajakLikedContent extends StatelessWidget {
  const KelajakLikedContent({super.key, required this.directions});

  final List<KelajakDirection> directions;

  @override
  Widget build(BuildContext context) {
    if (directions.isEmpty) {
      return KelajakNote('kelajak.result.likedEmpty'.tr());
    }
    return KelajakChipWrap(
      icon: SolarIconsBold.heart,
      labels: [for (final d in directions) d.activity.inLocale(context)],
    );
  }
}

/// ✓ Rivojlantirish mumkin bo'lgan jihatlar (maslahat bilan).
class KelajakGrowthContent extends StatelessWidget {
  const KelajakGrowthContent({super.key, required this.areas});

  final List<KelajakGrowthArea> areas;

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) return KelajakNote('kelajak.result.growthEmpty'.tr());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        for (final a in areas)
          _Item(
            title: a.title.inLocale(context),
            body: a.tip?.inLocale(context),
          ),
      ]),
    );
  }
}

/// ✓ Keyingi tavsiya — test yoki Career Lab bo'lsa "Boshlash" tugmasi.
class KelajakNextContent extends StatelessWidget {
  const KelajakNextContent({
    super.key,
    required this.next,
    required this.onOpenTest,
    this.currentType,
  });

  final List<KelajakNext> next;
  final ValueChanged<String> onOpenTest;

  /// Hozir yechilgan test (unga tugma ko'rsatilmaydi).
  final String? currentType;

  @override
  Widget build(BuildContext context) {
    if (next.isEmpty) return KelajakNote('kelajak.result.nextEmpty'.tr());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _spaced([
        for (final n in next)
          _Item(
            title: n.title.inLocale(context),
            body: n.body?.inLocale(context),
            extra: _button(n),
          ),
      ]),
    );
  }

  Widget? _button(KelajakNext next) {
    final type = next.testType;
    if (next.kind == KelajakNextKind.comeBack ||
        type == null ||
        type == currentType) {
      return null;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: KelajakPillButton(
        label: 'kelajak.action.start'.tr(),
        icon: SolarIconsOutline.arrowRight,
        height: 40,
        onTap: () => onOpenTest(type),
      ),
    );
  }
}
