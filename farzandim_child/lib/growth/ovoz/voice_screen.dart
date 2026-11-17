// H01 · Bola ovozi: ikkita teng eshik — oylik anonim so'rov (H02) va
// psixologdan shaxsiy yordam (H04) — hamda «Murojaatlarim» (H06). Anonim
// so'rov va shaxsiy murojaat bir-biriga hech qachon aralashmaydi.
// Mutaxassis yuborgan ochiq testlar (sinfga yoki shaxsan) tepada ro'yxat
// bo'lib turadi — «Sizga yangi test yuborildi» push'i shu yerga olib keladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_outbox.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:farzandim_child/growth/ovoz/help_screen.dart';
import 'package:farzandim_child/growth/ovoz/voice_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final survey = ref.watch(voiceSurveyProvider);
    final tests =
        ref.watch(psychAssignmentsProvider).valueOrNull ??
        const <PsychAssignmentSummary>[];
    final requests = ref.watch(voiceRequestsProvider).valueOrNull;
    final pending = ref.watch(voiceOutboxProvider).valueOrNull ?? const [];
    final active =
        pending.length +
        (requests ?? const <VoiceRequestSummary>[])
            .where((r) => r.stage != VoiceStage.closed)
            .length;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.voice.title'.tr(),
        ),
        onRefresh: () async => ref
          ..invalidate(voiceSurveyProvider)
          ..invalidate(psychAssignmentsProvider)
          ..invalidate(voiceRequestsProvider),
        children: [
          if (tests.isNotEmpty) _OpenTests(tests: tests),
          _DoorCard(
            icon: GIcons.listChecks,
            hue: GHue.teal,
            title: 'g5.voice.hub.surveyTitle'.tr(),
            body: _surveyLine(survey),
            onTap: () => GrowthLinks.voiceSurvey(context),
          ),
          _DoorCard(
            icon: GIcons.handHeart,
            hue: GHue.sky,
            title: 'g5.voice.hub.helpTitle'.tr(),
            body: 'g5.voice.hub.helpBody'.tr(),
            onTap: () => GrowthLinks.psychologist(context),
            action: GButton(
              label: 'g5.voice.hub.helpButton'.tr(),
              icon: GIcons.chatCircleText,
              size: GButtonSize.md,
              onPressed: () => GrowthLinks.psychologist(context),
            ),
          ),
          GList(
            children: [
              GListItem(
                leading: const GTile(
                  icon: GIcons.tray,
                  hue: GHue.blue,
                  size: 40,
                ),
                title: 'g5.voice.hub.requests'.tr(),
                trailing: GChip(
                  label: active > 0
                      ? 'g5.voice.hub.requestsActive'.tr(
                          namedArgs: {'count': '$active'},
                        )
                      : 'g5.voice.hub.requestsNone'.tr(),
                  kind: active > 0 ? GChipKind.info : GChipKind.neutral,
                ),
                onTap: () => GrowthLinks.voiceRequests(context),
              ),
            ],
          ),
          GNote(
            text: 'g5.voice.hub.alwaysOpen'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.lockKey,
          ),
        ],
      ),
    );
  }

  String _surveyLine(AsyncValue<VoiceSurveyState> async) {
    final state = async.valueOrNull;
    if (state == null) {
      return async.isLoading
          ? 'g5.common.loading'.tr()
          : 'g5.voice.hub.surveyNone'.tr();
    }
    final survey = state.survey;
    if (survey != null) {
      final month = survey.activatedAt;
      return 'g5.voice.hub.surveyOpen'.tr(
        namedArgs: {
          'month': month == null ? survey.title : voiceMonthName(month),
          'min': '${survey.estimatedMinutes}',
        },
      );
    }
    return state.answered
        ? 'g5.voice.hub.surveyDone'.tr()
        : 'g5.voice.hub.surveyNone'.tr();
  }
}

/// Mutaxassis yuborgan ochiq testlar. Nomi ko'rsatilmaydi (shaxsiy yordam
/// ekranidagidek neytral) — test ichida ochiladi.
class _OpenTests extends StatelessWidget {
  const _OpenTests({required this.tests});

  final List<PsychAssignmentSummary> tests;

  @override
  Widget build(BuildContext context) {
    return GSection(
      title: 'g5.voice.hub.testsTitle'.tr(),
      child: GList(
        children: [
          for (final a in tests)
            GListItem(
              leading: const GTile(
                icon: GIcons.clipboardText,
                hue: GHue.teal,
                size: 40,
              ),
              title:
                  (a.isPersonal
                          ? 'g5.voice.help.personalTitle'
                          : 'g5.voice.hub.classTestTitle')
                      .tr(namedArgs: {'count': '${a.itemCount}'}),
              subtitle: a.assignedByName == null
                  ? null
                  : 'g5.voice.help.personalBy'.tr(
                      namedArgs: {'name': a.assignedByName!},
                    ),
              onTap: () => GrowthLinks.voicePersonal(
                context,
                a.assignmentId,
                legacy: needsLegacyRunner(a),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoorCard extends StatelessWidget {
  const _DoorCard({
    required this.icon,
    required this.hue,
    required this.title,
    required this.body,
    required this.onTap,
    this.action,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final card = GGlass(
      kind: GGlassKind.feat,
      glowHue: hue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GTile(icon: icon, hue: hue, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GText.h3),
                    const SizedBox(height: 4),
                    Text(body, style: GText.caption),
                  ],
                ),
              ),
              if (action == null)
                const GIcon(GIcons.caretRight, size: 20, color: GColors.link),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
    if (action != null) return card;
    return MergeSemantics(
      child: GPressable(onTap: onTap, pressedScale: .98, child: card),
    );
  }
}
