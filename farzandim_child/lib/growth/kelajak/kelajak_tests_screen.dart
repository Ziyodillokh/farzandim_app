// K02 · Kelajagim — testlar: bugungi holat (halqa), har bir test katta
// rasm-ikonli kartada (holat, savollar soni, vaqt, aniq tugma), «Kelajak
// profilim» va savollar mavzulari. Yosh kiritilmagan / oraliqdan tashqari /
// xato holatlari ham shu dizaynda. Pastga tortib yangilanadi.

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class KelajakTestsScreen extends ConsumerWidget {
  const KelajakTestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kelajakOverviewProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum holat ko'rinadi.
    final overview = state.valueOrNull;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        onRefresh: () => refreshKelajak(ref),
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'kelajak.title'.tr(),
          subtitle: overview == null ? null : kelajakAgeLine(overview.age),
        ),
        children: overview != null
            ? _body(context, ref, overview)
            : [_StatusView(state: state)],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    KelajakOverview overview,
  ) {
    switch (overview.age.status) {
      case KelajakAgeStatus.ageRequired:
        return [
          _MessageCard(
            icon: GIcons.userCircle,
            hue: GHue.blue,
            title: 'kelajak.age.requiredTitle'.tr(),
            body: 'kelajak.age.requiredBody'.tr(),
            action: GButton(
              label: 'kelajak.age.requiredAction'.tr(),
              size: GButtonSize.md,
              onPressed: () => openKelajakAgeEdit(context, ref),
            ),
          ),
        ];
      case KelajakAgeStatus.ageOutOfRange || KelajakAgeStatus.unknown:
        return [
          _MessageCard(
            icon: GIcons.compass,
            hue: GHue.sky,
            title: 'kelajak.age.outOfRangeTitle'.tr(),
            body: 'kelajak.age.outOfRangeBody'.tr(),
          ),
        ];
      case KelajakAgeStatus.ok:
        break;
    }
    final tests = _ordered(overview.tests);
    final categories = [
      for (final c in overview.categories) c.name.inLocale(context),
    ];
    return [
      _TodayHero(tests: overview.tests),
      if (tests.isEmpty)
        GNote(
          kind: GNoteKind.plain,
          icon: GIcons.clock,
          text: 'kelajak.hub.empty'.tr(),
        )
      else
        GSection(
          title: 'kelajak.hub.tests'.tr(),
          child: Column(
            children: [
              for (final test in tests) ...[
                _TestCard(
                  test: test,
                  onOpen: () => openKelajakSession(context, test.type),
                ),
                if (test != tests.last) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      _ProfileCard(overview: overview),
      if (categories.isNotEmpty)
        GSection(
          title: 'kelajak.hub.topics'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('kelajak.hub.topicsHint'.tr(), style: GText.caption),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final c in categories) GChip(label: c)],
              ),
            ],
          ),
        ),
      GNote(
        kind: GNoteKind.plain,
        icon: GIcons.sparkle,
        text: 'kelajak.hub.intro'.tr(),
      ),
    ];
  }

  /// Davom etayotganlar birinchi, keyin yangilari, bajarilganlar oxirida.
  static List<KelajakTestInfo> _ordered(List<KelajakTestInfo> tests) {
    int rank(KelajakTestInfo t) => switch (kelajakDayStateOf(t.today)) {
      KelajakDayState.unfinished => 0,
      KelajakDayState.fresh || null => 1,
      KelajakDayState.done => 2,
    };
    return [...tests]..sort((a, b) => rank(a).compareTo(rank(b)));
  }
}

/// Test turining «rasmi»: ikon va rang.
({GIconData icon, GHue hue}) _lookOf(String type) =>
    switch (KelajakTestType.fromWire(type)) {
      KelajakTestType.daily => (icon: GIcons.sunHorizon, hue: GHue.gold),
      KelajakTestType.career => (icon: GIcons.briefcase, hue: GHue.blue),
      KelajakTestType.wellbeing => (icon: GIcons.heart, hue: GHue.rose),
      KelajakTestType.learning => (icon: GIcons.student, hue: GHue.green),
      KelajakTestType.self => (icon: GIcons.usersThree, hue: GHue.sky),
      KelajakTestType.careerLab => (icon: GIcons.flask, hue: GHue.teal),
      KelajakTestType.voice => (icon: GIcons.megaphoneSimple, hue: GHue.orange),
      KelajakTestType.unknown => (icon: GIcons.sparkle, hue: GHue.slate),
    };

/// Bugungi holat: nechta test bajarildi (halqa) va keyingi qadam.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.tests});

  final List<KelajakTestInfo> tests;

  @override
  Widget build(BuildContext context) {
    final total = tests.length;
    final done = tests
        .where((t) => kelajakDayStateOf(t.today) == KelajakDayState.done)
        .length;
    final allDone = total > 0 && done == total;
    final title = allDone
        ? 'g5.kelajakHub.allDone'.tr()
        : 'g5.kelajakHub.left'.tr(namedArgs: {'n': '${total - done}'});
    final body = allDone
        ? 'g5.kelajakHub.allDoneBody'.tr()
        : 'g5.kelajakHub.leftBody'.tr();
    return GGlass(
      glowHue: GHue.gold,
      padding: const EdgeInsets.all(18),
      child: Semantics(
        container: true,
        label: 'g5.kelajakHub.progressA11y'.tr(
          namedArgs: {'done': '$done', 'total': '$total'},
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 92,
                child: CustomPaint(
                  painter: GProgressRingPainter(
                    total == 0 ? 0 : done / total,
                    stroke: 9,
                    colors: const [Color(0xFFFFD27A), Color(0xFFF59E0B)],
                  ),
                  child: Center(
                    child: allDone
                        ? const GIcon(
                            GIcons.rocketLaunch,
                            size: 36,
                            color: Color(0xFFFFD27A),
                          )
                        : Text('$done/$total', style: GText.display(22)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'g5.kelajakHub.today'.tr().toUpperCase(),
                      style: GText.onest(
                        12,
                        weight: FontWeight.w700,
                        color: const Color(0xFFFFD27A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: GText.display(19)),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: GText.onest(
                        14,
                        color: GColors.textMuted,
                        height: 1.4,
                      ),
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

/// Bitta test: katta rasm-ikon, sarlavha, tavsif, savollar / vaqt, tugma.
class _TestCard extends StatelessWidget {
  const _TestCard({required this.test, required this.onOpen});

  final KelajakTestInfo test;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final state = kelajakDayStateOf(test.today);
    final look = _lookOf(test.type);
    final done = state == KelajakDayState.done;
    final description = test.description?.inLocale(context);
    // Kartaning istalgan joyi testni ochadi; ekran o'quvchi uchun amal —
    // pastdagi tugma.
    return GPressable(
      onTap: onOpen,
      isButton: false,
      pressedScale: .985,
      child: GGlass(
        glowHue: done ? null : look.hue,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Illustration(icon: look.icon, hue: look.hue, dimmed: done),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state != null) ...[
                        _StatusChip(state: state),
                        const SizedBox(height: 8),
                      ],
                      Semantics(
                        header: true,
                        child: Text(
                          test.title.inLocale(context),
                          style: GText.onest(
                            18,
                            weight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: GText.onest(15, color: GColors.textMuted, height: 1.45),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (test.questionCount > 0)
                  _MetaPill(
                    icon: GIcons.listChecks,
                    text: 'kelajak.questions'.tr(
                      namedArgs: {'count': '${test.questionCount}'},
                    ),
                  ),
                if (test.estimatedMinutes > 0)
                  _MetaPill(
                    icon: GIcons.clock,
                    text: 'kelajak.minutes'.tr(
                      namedArgs: {'count': '${test.estimatedMinutes}'},
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GButton(
              label: kelajakActionKey(state).tr(),
              kind: done ? GButtonKind.ghost : GButtonKind.primary,
              size: GButtonSize.md,
              trailingIcon: done ? null : GIcons.arrowRight,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

/// Test «rasmi»: rangli shisha plitada katta ikki rangli ikon va nur.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.icon,
    required this.hue,
    this.dimmed = false,
  });

  final GIconData icon;
  final GHue hue;
  final bool dimmed;

  static const _size = 68.0;

  @override
  Widget build(BuildContext context) {
    final base = hue.base;
    return Opacity(
      opacity: dimmed ? .55 : 1,
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [base.withValues(alpha: .38), base.withValues(alpha: .12)],
          ),
          border: Border.all(color: hue.icon.withValues(alpha: .35)),
          boxShadow: [
            BoxShadow(
              color: base.withValues(alpha: dimmed ? 0 : .35),
              blurRadius: 22,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Burchakdagi kichik «uchqun» — rasmga jon beradi.
            Positioned(
              right: 8,
              top: 7,
              child: Transform.rotate(
                angle: math.pi / 12,
                child: GIcon(
                  GIcons.sparkle,
                  size: 13,
                  color: hue.icon.withValues(alpha: .8),
                ),
              ),
            ),
            Center(child: GIcon(icon, size: 34, color: hue.icon)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final KelajakDayState state;

  @override
  Widget build(BuildContext context) => GChip(
    label: kelajakStatusKey(state).tr(),
    icon: state == KelajakDayState.done ? GIcons.check : null,
    kind: switch (state) {
      KelajakDayState.done => GChipKind.ok,
      KelajakDayState.unfinished => GChipKind.warn,
      KelajakDayState.fresh => GChipKind.info,
    },
  );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});

  final GIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GIcon(icon, size: 16, color: GColors.textMuted),
          const SizedBox(width: 6),
          Text(text, style: GText.onest(13.5, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// «Kelajak profilim»: javob berilgan savollar ulushi va havola.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.overview});

  final KelajakOverview overview;

  @override
  Widget build(BuildContext context) {
    final profile = overview.profile;
    final total = profile?.availableQuestions ?? 0;
    final answered = profile?.answeredQuestions ?? 0;
    final subtitle = total == 0
        ? 'kelajak.hub.profileBody'.tr()
        : 'kelajak.hub.profileAnswered'.tr(
            namedArgs: {'answered': '$answered', 'total': '$total'},
          );
    return GPressable(
      onTap: () => openKelajakProgress(context),
      semanticLabel: 'kelajak.progress.title'.tr(),
      pressedScale: .98,
      child: GGlass(
        glowHue: GHue.teal,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _Illustration(icon: GIcons.chartLineUp, hue: GHue.teal),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'kelajak.progress.title'.tr(),
                        style: GText.onest(18, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GText.onest(
                          14,
                          color: GColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const GIcon(
                  GIcons.caretRight,
                  size: 20,
                  color: GColors.chevron,
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 14),
              GProgressBar(value: (answered / total).clamp(0, 1)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yosh kiritilmagan / boshqa yosh — katta ikon, matn va (bo'lsa) tugma.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.hue,
    required this.title,
    required this.body,
    this.action,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GGlass(
      glowHue: hue,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          _Illustration(icon: icon, hue: hue),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: GText.display(19)),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GText.onest(15, color: GColors.textMuted, height: 1.45),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Ma'lumot hali yo'q: yuklanmoqda, xato yoki bo'lim serverda yo'q.
class _StatusView extends ConsumerWidget {
  const _StatusView({required this.state});

  final AsyncValue<KelajakOverview?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = state.error;
    final code = error == null
        ? KelajakErrorCode.unavailable
        : kelajakCodeOf(error);
    return _MessageCard(
      icon: GIcons.wifiSlash,
      hue: GHue.slate,
      title: 'g5.kelajakHub.errorTitle'.tr(),
      body: kelajakErrorKey(code).tr(),
      action: GButton(
        label: 'g5.kelajakHub.retry'.tr(),
        kind: GButtonKind.ghost,
        size: GButtonSize.md,
        onPressed: () => ref.invalidate(kelajakOverviewByAccountProvider),
      ),
    );
  }
}
