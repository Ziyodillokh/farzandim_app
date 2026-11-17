// H02 · So'rovga taklif: ixtiyoriy anonim so'rov maqsadi, kim nimani
// ko'rishi va davomiyligi. Ism, avatar, seriya va DON yo'q; ishtirok uchun
// mukofot berilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VoiceSurveyIntroScreen extends ConsumerWidget {
  const VoiceSurveyIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voiceSurveyProvider);
    final state = async.valueOrNull;
    final survey = state?.survey;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.voice.intro.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(voiceSurveyProvider),
        dock: survey == null
            ? null
            : GDockRow(
                children: [
                  GButton(
                    label: 'g5.voice.intro.later'.tr(),
                    kind: GButtonKind.ghost,
                    onPressed: () => context.pop(),
                  ),
                  GButton(
                    label: 'g5.voice.intro.start'.tr(),
                    trailingIcon: GIcons.arrowRight,
                    onPressed: () => GrowthLinks.voiceSurveyRun(context),
                  ),
                ],
              ),
        children: [
          if (state == null && async.isLoading)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (state == null)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(voiceSurveyProvider),
              ),
            )
          else if (survey == null)
            GGlass(
              child: Row(
                children: [
                  GTile(
                    icon: state.answered ? GIcons.checkCircle : GIcons.clock,
                    hue: state.answered ? GHue.green : GHue.slate,
                    size: 48,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      (state.answered
                              ? 'g5.voice.intro.doneBody'
                              : 'g5.voice.intro.noneBody')
                          .tr(),
                      style: GText.body,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            GGlass(
              kind: GGlassKind.feat,
              glowHue: GHue.teal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GTile(
                    icon: GIcons.listChecks,
                    hue: GHue.teal,
                    size: 48,
                  ),
                  const SizedBox(height: 14),
                  Text('g5.voice.intro.purpose'.tr(), style: GText.h3),
                ],
              ),
            ),
            GList(
              children: [
                _Rule(
                  icon: GIcons.timer,
                  hue: GHue.blue,
                  text: 'g5.voice.intro.minutes'.tr(
                    namedArgs: {'min': '${survey.estimatedMinutes}'},
                  ),
                ),
                _Rule(
                  icon: GIcons.eyeSlash,
                  hue: GHue.teal,
                  text: 'g5.voice.intro.anonymous'.tr(),
                ),
                _Rule(
                  icon: GIcons.users,
                  hue: GHue.sky,
                  text: 'g5.voice.intro.whoSees'.tr(),
                ),
              ],
            ),
            GNote(text: 'g5.voice.intro.skip'.tr(), kind: GNoteKind.plain),
          ],
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.hue, required this.text});

  final GIconData icon;
  final GHue hue;
  final String text;

  @override
  Widget build(BuildContext context) => GListItem(
    leading: GTile(icon: icon, hue: hue, size: 40),
    title: text,
  );
}
