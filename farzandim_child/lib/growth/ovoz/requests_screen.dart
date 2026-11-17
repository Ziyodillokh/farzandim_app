// H06 · Murojaatlarim: shaxsiy murojaatlar qutisi — neytral sarlavha
// («Murojaat · sana»), holat va o'qilmagan javoblar. Avval qurilmada
// yuborilmay qolganlari, so'ng serverdagilar (yangisi birinchi). Anonim
// so'rov javoblari bu yerda hech qachon ko'rinmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_outbox.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:farzandim_child/growth/ovoz/voice_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VoiceRequestsScreen extends ConsumerWidget {
  const VoiceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voiceRequestsProvider);
    final pending = ref.watch(voiceOutboxProvider).valueOrNull ?? const [];
    final items = [...?async.valueOrNull]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final isEmpty = pending.isEmpty && items.isEmpty;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.voice.list.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(voiceRequestsProvider),
        dock: GButton(
          label: 'g5.voice.list.newRequest'.tr(),
          icon: GIcons.chatCircleText,
          onPressed: () => GrowthLinks.voiceCompose(context),
        ),
        children: [
          if (async.isLoading && !async.hasValue && pending.isEmpty)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (async.hasError && !async.hasValue)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(voiceRequestsProvider),
              ),
            )
          else if (isEmpty)
            GNote(
              text: 'g5.voice.list.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.tray,
            ),
          if (!isEmpty)
            GList(
              children: [
                for (final p in pending.reversed)
                  _RequestRow(
                    id: p.id,
                    createdAt: p.createdAt,
                    urgent: p.urgent,
                    stage: null,
                  ),
                for (final r in items)
                  _RequestRow(
                    id: r.id,
                    createdAt: r.createdAt,
                    urgent: r.urgent,
                    stage: r.stage,
                    unread: r.unread,
                  ),
              ],
            ),
          GNote(
            text: 'g5.voice.list.note'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.eyeSlash,
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.id,
    required this.createdAt,
    required this.urgent,
    required this.stage,
    this.unread = 0,
  });

  final String id;
  final DateTime createdAt;
  final bool urgent;

  /// `null` — hali yuborilmagan (qurilmada).
  final VoiceStage? stage;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final chip = voiceStageChip(stage);
    final meta = [
      chip.label,
      if (urgent) 'g5.voice.list.urgent'.tr(),
      if (unread > 0)
        'g5.voice.list.unread'.tr(namedArgs: {'count': '$unread'}),
    ].join(' · ');
    return GListItem(
      leading: GTile(
        icon: stage == null ? GIcons.wifiSlash : GIcons.chatCircleText,
        hue: switch (stage) {
          null => GHue.gold,
          VoiceStage.replied => GHue.green,
          VoiceStage.closed => GHue.slate,
          _ => GHue.sky,
        },
        size: 40,
      ),
      title: voiceRequestTitle(createdAt),
      // Holat sarlavha ostida — uzun belgi sarlavhani sindirmasin; rang plitada.
      subtitle: meta,
      onTap: () => GrowthLinks.voiceRequest(context, id),
    );
  }
}
