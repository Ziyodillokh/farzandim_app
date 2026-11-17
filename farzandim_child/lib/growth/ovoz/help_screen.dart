// H04 · Shaxsiy yordam: mas'ul psixolog (ism), haqiqiy ish vaqti, kim
// o'qishi (o'rinbosar bilan) va ish vaqtidan tashqarida qachon ko'rilishi.
// Kecha-kunduz javob va'da qilinmaydi; shoshilinch holatda — yaqin katta
// yoki SOS. Mutaxassis tayinlagan shaxsiy so'rov bo'lsa — kichik karta (H10).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:farzandim_child/growth/ovoz/voice_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Xotira/diqqat testlari (stimul, taymer) mavjud test ekranida yechiladi.
bool needsLegacyRunner(PsychAssignmentSummary a) =>
    a.timeLimitMin != null ||
    a.kind == PsychKind.cognitive ||
    a.kind == PsychKind.attention ||
    a.kind == PsychKind.iq;

class VoiceHelpScreen extends ConsumerWidget {
  const VoiceHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(voiceContactProvider).valueOrNull;
    final personal =
        (ref.watch(psychAssignmentsProvider).valueOrNull ??
                const <PsychAssignmentSummary>[])
            .where((a) => a.isPersonal)
            .toList();
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.voice.help.title'.tr(),
        ),
        onRefresh: () async => ref
          ..invalidate(voiceContactProvider)
          ..invalidate(psychAssignmentsProvider),
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GButton(
              label: 'g5.voice.help.newRequest'.tr(),
              icon: GIcons.chatCircleText,
              onPressed: () => GrowthLinks.voiceCompose(context),
            ),
            const SizedBox(height: 8),
            GButton(
              label: 'g5.voice.help.requests'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              onPressed: () => GrowthLinks.voiceRequests(context),
            ),
          ],
        ),
        children: [
          _PsychologistCard(contact: contact ?? VoiceContact.unknown),
          for (final a in personal)
            GList(
              children: [
                GListItem(
                  leading: const GTile(
                    icon: GIcons.clipboardText,
                    hue: GHue.teal,
                    size: 40,
                  ),
                  title: 'g5.voice.help.personalTitle'.tr(
                    namedArgs: {'count': '${a.itemCount}'},
                  ),
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
          GNote(
            text: 'g5.voice.help.anyTime'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.clock,
          ),
          GNote(
            text: [
              'g5.voice.help.whoReads'.tr(),
              if (contact?.deputyName != null)
                'g5.voice.help.deputy'.tr(
                  namedArgs: {'name': contact!.deputyName!},
                ),
            ].join(' '),
            kind: GNoteKind.info,
            icon: GIcons.lockKey,
          ),
          GNote(
            text: 'g5.voice.help.urgent'.tr(),
            kind: GNoteKind.warn,
            icon: GIcons.warningCircle,
            action: GLink(
              label: 'g5.today.sos'.tr(),
              onPressed: () => GrowthLinks.sos(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PsychologistCard extends StatelessWidget {
  const _PsychologistCard({required this.contact});

  final VoiceContact contact;

  @override
  Widget build(BuildContext context) {
    final name = voicePsychologistName(contact);
    final hours = contact.hours;
    return GGlass(
      kind: GGlassKind.feat,
      glowHue: GHue.sky,
      child: MergeSemantics(
        child: Row(
          children: [
            GAvatar(
              initials: name.characters.first.toUpperCase(),
              hue: GHue.sky,
              size: 56,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GText.h3),
                  const SizedBox(height: 2),
                  Text('g5.voice.help.role'.tr(), style: GText.caption),
                  if (hours != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      voiceHoursLabel(hours),
                      style: GText.onest(
                        14,
                        weight: FontWeight.w600,
                        color: GColors.textLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GChip(
                      label:
                          (contact.openNow
                                  ? 'g5.voice.help.openNow'
                                  : 'g5.voice.help.closedNow')
                              .tr(),
                      kind: contact.openNow ? GChipKind.ok : GChipKind.neutral,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
