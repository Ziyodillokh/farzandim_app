// ─────────────────────────────────────────────────────────────────────
// GrowthScreen — bolaning kunlik testlar natijalari (ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Marshrut: `AppRoutes.growthPath(childId)` — "Hisobotlar" kartasi va
// `learning_weekly` push'idan. 7/30 kunlik davr: o'rtacha natija va
// o'zgarish, testlar / faol kunlar / ketma-ket kunlar, fanlar bo'yicha
// chiziqlar, eng yaxshi va mashq qilishga arziydigan fan. Pastda oxirgi
// natijalar (`nextBefore` bilan sahifalanadi). Sinf va fanlar
// `LearningProfileSheet`da o'zgartiriladi. Pull-to-refresh.
// Growth backend'da yo'q (404 `code`siz) — "hozircha mavjud emas".

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/growth/data/models/learning_profile.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/growth/presentation/widgets/growth_header.dart';
import 'package:farzandim/features/growth/presentation/widgets/growth_results_section.dart';
import 'package:farzandim/features/growth/presentation/widgets/growth_summary_cards.dart';
import 'package:farzandim/features/growth/presentation/widgets/learning_profile_sheet.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _blue = Color(0xFF216BFF);

/// Ro'yxat oxiriga shuncha piksel qolganda keyingi natijalar so'raladi.
const double _loadMoreExtent = 480;

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  int _days = kGrowthPeriods.first;

  GrowthSummaryArgs get _args => (childId: widget.childId, days: _days);

  Future<void> _refresh() async {
    final args = _args;
    ref.invalidate(growthSummaryProvider(args));
    final results = ref.read(growthResultsProvider(widget.childId).notifier);
    try {
      await Future.wait([
        ref.read(growthSummaryProvider(args).future),
        results.refresh(),
      ]).timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ekran o'zi yangilanadi.
    } on Object catch (e) {
      // Oldingi ma'lumot ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!mounted) return;
      AppToast.error(context, SchoolFailure.fromError(e).messageKey.tr());
    }
  }

  /// Sinf va fanlar varag'i; saqlansa xulosa va profil o'zi yangilanadi.
  void _editProfile(LearningProfile? initial) {
    unawaited(
      showLearningProfileSheet(
        context,
        childId: widget.childId,
        initial: initial,
      ),
    );
  }

  /// Ro'yxat oxiriga yaqinlashganda keyingi natijalar (xatodan keyin —
  /// faqat "Qayta urinish" bilan). Natijalar bo'limi faqat xulosa bilan
  /// ko'rinadi — xulosa yuklanayotganda / xatoda sahifa so'ralmaydi.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter >= _loadMoreExtent) return false;
    if (ref.read(growthSummaryProvider(_args)).valueOrNull == null) {
      return false;
    }
    final provider = growthResultsProvider(widget.childId);
    if (ref.read(provider).failure == null) {
      unawaited(ref.read(provider.notifier).loadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Natijalar davrga bog'liq emas va sahifa ochiq turganda tirik qoladi:
    // xulosa yuklanayotganda / xatoda aylantirish yoki tortib yangilash yangi
    // (darhol tashlanadigan) ro'yxat va so'rov yaratmaydi, 7 ↔ 30
    // almashtirilganda yuklangan sahifalar yo'qolmaydi.
    ref.listen(growthResultsProvider(widget.childId), (_, _) {});
    final async = ref.watch(growthSummaryProvider(_args));
    final summary = async.valueOrNull;
    // Growth backend'da yo'q — xulosa `null` bilan keladi.
    if (async.hasValue && summary == null) {
      return SchoolScaffold(
        title: 'growth.title'.tr(),
        body: SchoolMessageView(
          icon: SolarIconsBold.graphUp,
          title: 'growth.title'.tr(),
          message: 'growth.unavailable'.tr(),
        ),
      );
    }

    final Widget content;
    if (summary != null) {
      content = _SummaryContent(
        summary: summary,
        onPickProfile: () => _editProfile(null),
      );
    } else if (async.hasError) {
      content = SizedBox(
        height: 380,
        child: SchoolErrorView(
          error: async.error,
          onRetry: () => ref.invalidate(growthSummaryProvider(_args)),
        ),
      );
    } else {
      content = const SizedBox(height: 260, child: SchoolLoadingView());
    }

    return SchoolScaffold(
      title: 'growth.title'.tr(),
      body: RefreshIndicator(
        color: _blue,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
            children: [
              GrowthChildHeader(
                childId: widget.childId,
                profile: summary?.profile,
                onEdit: summary == null
                    ? null
                    : () => _editProfile(summary.profile),
              ),
              const SizedBox(height: 10),
              GrowthPeriodToggle(
                days: _days,
                onChanged: (days) => setState(() => _days = days),
              ),
              const SizedBox(height: 10),
              content,
              if (summary != null) ...[
                const SizedBox(height: 18),
                GrowthResultsSection(childId: widget.childId),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Yuklangan davr: sinf tanlanmagan bo'lsa taklif, keyin natijalar yoki
/// "test yechilmagan".
class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary, required this.onPickProfile});

  final LearningSummary summary;
  final VoidCallback onPickProfile;

  @override
  Widget build(BuildContext context) {
    final hasHighlights =
        summary.strongSubject != null || summary.focusSubject != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.profile == null) ...[
          GrowthNoticeCard(
            icon: SolarIconsBold.squareAcademicCap,
            title: 'growth.noProfile.title'.tr(),
            body: 'growth.noProfile.body'.tr(),
            actionLabel: 'growth.noProfile.action'.tr(),
            onAction: onPickProfile,
          ),
          const SizedBox(height: 10),
        ],
        if (!summary.hasTests)
          GrowthNoticeCard(
            icon: SolarIconsBold.notebookMinimalistic,
            title: 'growth.noTests.title'.tr(),
            body: 'growth.noTests.body'.tr(),
          )
        else ...[
          GrowthOverviewCard(summary: summary),
          if (summary.subjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            GrowthSubjectsCard(subjects: summary.subjects),
          ],
          if (hasHighlights) ...[
            const SizedBox(height: 10),
            GrowthHighlights(summary: summary),
          ],
        ],
      ],
    );
  }
}
