// "Bugungi testlar" — kunlik reja (fanlar × savollar) + "Boshlash".
//
// Reja `dailyPlanProvider`dan. Fan plitkasi — shu fan testi, "Boshlash" —
// navbatdagi yechilmagan fan ("Davom etish"), hammasi bajarilsa — kalendar.
// Bajarilgan fan plitkasida natija (9/10) va yashil belgi. Fan tanlanmagan
// bo'lsa — sozlash kartasi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/daily_plan_text.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/done_badge_icon.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/learning_setup_card.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/subject_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _doneBorder = Color(0x5545E2BE);
const _doneText = Color(0xFF45E2BE);

class TodayTestsCard extends ConsumerWidget {
  const TodayTestsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(dailyPlanProvider);
    if (ref.watch(needsLearningSetupProvider)) return const LearningSetupCard();
    // Yuklanmoqda — bo'sh joy ("0 ta test tayyor" ko'rsatilmaydi).
    if (plan.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeColors.testsBorder),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [HomeColors.testsTop, HomeColors.testsBottom],
          stops: [0, 0.7],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x330A3A7A), blurRadius: 24, spreadRadius: -6),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home.todayTests'.tr(),
                        style: homeDisplay(20.5, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dailyPlanSubtitle(plan),
                        style: homeText(14.2, color: HomeColors.textDim),
                      ),
                    ],
                  ),
                ),
              ),
              const _CalendarButton(),
            ],
          ),
          const SizedBox(height: 11),
          _SubjectTiles(items: plan.items),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _StartButton(
              label: dailyPlanButtonLabel(plan),
              onTap: () => startDailyLearning(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarButton extends StatelessWidget {
  const _CalendarButton();

  @override
  Widget build(BuildContext context) {
    // Testlar kalendari (kunlik tarix).
    return Semantics(
      button: true,
      label: 'learn.calendarTitle'.tr(),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(LearningRoutes.calendar);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HomeColors.calendarButton,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const HomeSvgIcon(
            homeCalendarSvg,
            size: 24,
            color: Color(0xFFB4CAE6),
          ),
        ),
      ),
    );
  }
}

/// Fan plitkalari — kengligi matn uzunligiga mos (maketdagidek), umumiy
/// kenglikka sig'diriladi.
class _SubjectTiles extends StatelessWidget {
  const _SubjectTiles({required this.items});

  final List<DailyPlanItem> items;

  static const _gap = 6.0;
  static const _iconSize = 34.0;

  /// Matndan tashqari kenglik: chap 9 + ikon + oraliq 6 + o'ng 4 + chegara 2.
  static const _chrome = 9.0 + _iconSize + 6 + 4 + 2;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Shrift (google_fonts) yuklanib bo'lgach matn o'lchovlari qayta
    // hisoblansin — aks holda kengliklar zaxira shriftda qolib ketadi.
    listenable: PaintingBinding.instance.systemFonts,
    builder: (context, _) => _layout(context),
  );

  Widget _layout(BuildContext context) {
    final nameStyle = homeText(12, weight: FontWeight.w600, height: 1.25);
    final countStyle = homeText(11, color: HomeColors.textDim, height: 1.25);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labels = [
      for (final item in items)
        (name: item.subject.labelKey.tr(), count: dailyPlanItemCaption(item)),
    ];

    double measure(String text, TextStyle style) => (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout()).width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final natural = [
          for (final l in labels)
            _chrome +
                [
                  measure(l.name, nameStyle),
                  measure(l.count, countStyle),
                ].reduce((a, b) => a > b ? a : b),
        ];
        final available = constraints.maxWidth - _gap * (items.length - 1);
        final total = natural.fold<double>(0, (s, w) => s + w);
        final scale = available / total;
        Widget tile(int i, double width) => SizedBox(
          width: width,
          child: _SubjectTile(
            item: items[i],
            name: labels[i].name,
            count: labels[i].count,
            nameStyle: nameStyle,
            countStyle: countStyle,
          ),
        );
        // Juda siqilib qolsa (4+ fan) — tabiiy kenglikda gorizontal lenta.
        if (scale < 0.85 && items.length > 3) {
          return SizedBox(
            height: _SubjectTile.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (_, i) => tile(i, natural[i]),
            ),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              tile(i, natural[i] * scale),
            ],
          ],
        );
      },
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.item,
    required this.name,
    required this.count,
    required this.nameStyle,
    required this.countStyle,
  });

  final DailyPlanItem item;
  final String name;
  final String count;
  final TextStyle nameStyle;
  final TextStyle countStyle;

  static const height = 62.0;

  @override
  Widget build(BuildContext context) {
    final done = item.isDone;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => openSubjectQuiz(context, item.subject),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: height,
          padding: const EdgeInsets.only(left: 9, right: 4),
          decoration: BoxDecoration(
            color: HomeColors.testsTile,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? _doneBorder : HomeColors.testsTileBorder,
            ),
          ),
          child: Row(
            children: [
              DoneBadgeIcon(
                done: done,
                child: SubjectIcon(
                  subject: item.subject,
                  size: _SubjectTiles._iconSize,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FitText(name, style: nameStyle),
                    const SizedBox(height: 3),
                    FitText(
                      count,
                      style: done
                          ? countStyle.copyWith(
                              color: _doneText,
                              fontWeight: FontWeight.w700,
                            )
                          : countStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.primary,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FitText(
                  label,
                  style: homeText(13.5, weight: FontWeight.w600, height: 1.2),
                ),
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
