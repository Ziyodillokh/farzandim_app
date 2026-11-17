// F04 · Qo'shimcha vaqt: faol rejim (dars, uyqu, dam), qo'shimcha vaqt
// so'rash (10/15/30 daqiqa, sabab ixtiyoriy) va javob holati. Bola so'raydi —
// ota-ona hal qiladi; cheklovni chetlab o'tish yoki o'chirish tugmasi yo'q.
// Javob kelganda (socket `unlock_request:*`) holat darhol yangilanadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim_child/growth/oila/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ExtraTimeScreen extends ConsumerStatefulWidget {
  const ExtraTimeScreen({super.key});

  @override
  ConsumerState<ExtraTimeScreen> createState() => _ExtraTimeScreenState();
}

class _ExtraTimeScreenState extends ConsumerState<ExtraTimeScreen> {
  final _reason = TextEditingController();
  final _subs = <StreamSubscription<dynamic>>[];
  var _minutes = kExtraTimeOptions.first;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final socket = ref.read(socketClientProvider);
    for (final event in const [
      'unlock_request:created',
      'unlock_request:decided',
      'unlock_request:cancelled',
    ]) {
      _subs.add(
        socket
            .eventStream(event)
            .listen((_) => ref.invalidate(latestExtraTimeProvider)),
      );
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(ExtraTimeRepository repo) body,
  ) async {
    if (_busy) return;
    final repo = ref.read(extraTimeRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body(repo);
      ref.invalidate(latestExtraTimeProvider);
    } on ExtraTimeException catch (e) {
      if (mounted) {
        _error = e.network
            ? 'g5.oila.extra.network'.tr()
            : e.alreadyDecided
            ? 'g5.oila.extra.decided'.tr()
            : 'g5.oila.extra.failed'.tr();
      }
      ref.invalidate(latestExtraTimeProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _hm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(currentScheduleProvider);
    final latest = ref.watch(latestExtraTimeProvider).valueOrNull;
    final parent = ref.watch(parentNameProvider).valueOrNull;
    final who = (parent == null || parent.trim().isEmpty)
        ? 'g5.oila.parent'.tr()
        : parent.trim();
    final pending = latest?.status == ExtraTimeStatus.pending;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.rose,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.oila.screenTime'.tr(),
        ),
        dock: GButton(
          label: 'g5.oila.extra.ask'.tr(),
          icon: GIcons.hourglassMedium,
          loading: _busy && !pending,
          onPressed: pending || _busy
              ? null
              : () => _run(
                  (repo) => repo.ask(minutes: _minutes, reason: _reason.text),
                ),
        ),
        children: [
          GGlass(
            child: Row(
              children: [
                const GTile(icon: GIcons.clock, hue: GHue.gold, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule == null
                            ? 'g5.oila.extra.noMode'.tr()
                            : schedule.title,
                        style: GText.itemTitle,
                      ),
                      if (schedule != null)
                        Text(
                          '${_hm(schedule.startHour, schedule.startMinute)}–'
                          '${_hm(schedule.endHour, schedule.endMinute)}',
                          style: GText.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (pending)
            GGlass(
              glowHue: GHue.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'g5.oila.extra.minutes'.tr(
                      namedArgs: {'n': '${latest!.requestedMinutes ?? 0}'},
                    ),
                    style: GText.h3,
                  ),
                  const SizedBox(height: 4),
                  GChip(
                    label: 'g5.oila.extra.waiting'.tr(namedArgs: {'name': who}),
                    kind: GChipKind.warn,
                    icon: GIcons.hourglassMedium,
                  ),
                  if (latest.reason != null) ...[
                    const SizedBox(height: 8),
                    Text(latest.reason!, style: GText.body),
                  ],
                  const SizedBox(height: 12),
                  GButton(
                    label: 'g5.oila.extra.cancel'.tr(),
                    kind: GButtonKind.ghost,
                    size: GButtonSize.md,
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : () => _run((repo) => repo.cancel(latest.id)),
                  ),
                ],
              ),
            )
          else ...[
            if (latest?.status == ExtraTimeStatus.approved)
              GNote(
                text: 'g5.oila.extra.granted'.tr(
                  namedArgs: {
                    'n':
                        '${latest!.grantedMinutes ?? latest.requestedMinutes ?? 0}',
                  },
                ),
                kind: GNoteKind.ok,
                icon: GIcons.checkCircle,
              ),
            if (latest?.status == ExtraTimeStatus.denied)
              GNote(
                text: 'g5.oila.extra.denied'.tr(),
                kind: GNoteKind.plain,
                icon: GIcons.info,
              ),
            GSection(
              title: 'g5.oila.extra.howMuch'.tr(),
              child: Row(
                children: [
                  for (final m in kExtraTimeOptions) ...[
                    if (m != kExtraTimeOptions.first) const SizedBox(width: 8),
                    Expanded(
                      child: GOption(
                        label: 'g5.oila.extra.minutes'.tr(
                          namedArgs: {'n': '$m'},
                        ),
                        selected: _minutes == m,
                        showRadio: false,
                        onTap: () => setState(() => _minutes = m),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GTextField(
              label: 'g5.oila.extra.reason'.tr(),
              hint: 'g5.oila.extra.reasonHint'.tr(),
              controller: _reason,
              maxLength: 300,
              enabled: !_busy,
            ),
          ],
          if (_error != null)
            GNote(
              text: _error!,
              kind: GNoteKind.warn,
              icon: GIcons.warningCircle,
            ),
          GNote(
            text: PlatformCapabilities.isIOS
                ? 'g5.oila.extra.iosNote'.tr()
                : 'g5.oila.extra.note'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.shieldCheck,
          ),
        ],
      ),
    );
  }
}
