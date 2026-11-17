// ─────────────────────────────────────────────────────────────────────
// KelajakScreen — bolaning qiziqishlari va kelajak yo'nalishlari
// ─────────────────────────────────────────────────────────────────────
//
// Marshrut: `AppRoutes.kelajakPath(childId)` — dashboard kartasi va
// Growth sahifasidagi havoladan. Bo'limlar: bola va testlar soni,
// qiziqishlar (sinab ko'rish mumkin bo'lgan sohalar bilan — hukmsiz),
// kuchli tomonlar, rivojlantirish mumkin bo'lgan jihatlar, Career Lab,
// qo'llab-quvvatlash signali (faqat signal bo'lsa), o'zgarishlar,
// keyingi tavsiya va ogohlantirish. Yosh kiritilmagan — mavjud bola
// tahrirlash sahifasiga yo'naltiriladi. Pull-to-refresh.
// Kelajak backend'da yo'q (404 `code`siz) — "hozircha mavjud emas".

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/presentation/kelajak_view_models.dart';
import 'package:farzandim/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_career_lab_section.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_header.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_notices.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_progress_section.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_sections.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_support_card.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

/// Bo'limlar orasidagi bo'shliq.
const double _sectionGap = 10;

class KelajakScreen extends ConsumerStatefulWidget {
  const KelajakScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<KelajakScreen> createState() => _KelajakScreenState();
}

class _KelajakScreenState extends ConsumerState<KelajakScreen> {
  Future<void> _refresh() async {
    final provider = kelajakSummaryProvider(widget.childId);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future).timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ekran o'zi yangilanadi.
    } on Object catch (e) {
      // Oldingi ma'lumot ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!mounted) return;
      AppToast.error(context, SchoolFailure.fromError(e).messageKey.tr());
    }
  }

  /// Mavjud "Shaxsiy ma'lumotlar" sahifasi (tug'ilgan sana / yosh);
  /// qaytilganda xulosa qayta so'raladi (yosh guruhi o'zgargan bo'lishi
  /// mumkin).
  Future<void> _editAge() async {
    final child = ref.read(childByIdProvider(widget.childId));
    await context.push<void>(
      AppRoutes.editChildPath(widget.childId),
      extra: child,
    );
    if (!mounted) return;
    ref.invalidate(kelajakSummaryProvider(widget.childId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kelajakSummaryProvider(widget.childId));
    final summary = async.valueOrNull;
    final title = 'kelajak.title'.tr();
    // Kelajak backend'da yo'q — xulosa `null` bilan keladi.
    if (async.hasValue && summary == null) {
      return SchoolScaffold(
        title: title,
        body: SchoolMessageView(
          icon: SolarIconsBold.compass,
          title: title,
          message: 'kelajak.unavailable'.tr(),
        ),
      );
    }

    final List<Widget> children;
    if (summary != null) {
      children = _sections(summary);
    } else if (async.hasError) {
      children = [
        SizedBox(
          height: 380,
          child: SchoolErrorView(
            error: async.error,
            onRetry: () =>
                ref.invalidate(kelajakSummaryProvider(widget.childId)),
          ),
        ),
      ];
    } else {
      children = const [SizedBox(height: 260, child: SchoolLoadingView())];
    }

    return SchoolScaffold(
      title: title,
      body: RefreshIndicator(
        color: kelajakBlue,
        backgroundColor: kelajakCard,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
          children: children,
        ),
      ),
    );
  }

  /// Yuklangan xulosa bo'limlari — faqat mazmuni borlari.
  List<Widget> _sections(KelajakSummary summary) {
    final insights = summary.insights;
    final support = summary.support;
    final status = summary.age.status;
    final ageNotice =
        status == KelajakAgeStatus.ageRequired ||
        status == KelajakAgeStatus.ageOutOfRange;
    final empty = kelajakShowsEmptyState(summary);
    final next = kelajakGeneralNextSteps(insights);
    final sections = <Widget>[
      KelajakHeader(childId: widget.childId, summary: summary),
      if (ageNotice) KelajakAgeNotice(status: status, onEditAge: _editAge),
      if (empty && !ageNotice) const KelajakEmptyNotice(),
      if (!empty) ...[
        KelajakInterestsSection(summary: summary),
        if (insights.strengths.isNotEmpty)
          KelajakStrengthsSection(strengths: insights.strengths),
        if (insights.growthAreas.isNotEmpty)
          KelajakGrowthAreasSection(areas: insights.growthAreas),
        if (!KelajakCareerLabView.of(insights).isEmpty)
          KelajakCareerLabSection(summary: summary),
        if (support != null) KelajakSupportCard(support: support),
        if (kelajakHasProgress(summary.progress))
          KelajakProgressSection(progress: summary.progress),
        if (next.isNotEmpty) KelajakNextSection(steps: next),
        KelajakDisclaimer(text: summary.disclaimer),
      ],
    ];
    return [
      for (final (i, section) in sections.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : _sectionGap),
          child: section,
        ),
    ];
  }
}
