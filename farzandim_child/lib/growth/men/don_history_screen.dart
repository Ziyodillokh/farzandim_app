// I03 · DON tarixi: shaxsiy mukofot daftari — tasdiqlangan balans va
// kutilayotgan DON alohida, har bir o'quv hodisasi sana va miqdor bilan.
// Mashq yozuvi o'sha natijaga (U08) olib boradi. Qadamlar kuniga bitta qator.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:farzandim_child/growth/men/data/men_repository.dart';
import 'package:farzandim_child/growth/men/men_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MeDonHistoryScreen extends ConsumerStatefulWidget {
  const MeDonHistoryScreen({super.key});

  @override
  ConsumerState<MeDonHistoryScreen> createState() => _MeDonHistoryState();
}

class _MeDonHistoryState extends ConsumerState<MeDonHistoryScreen> {
  /// Birinchi sahifadan keyingi yuklangan sahifalar.
  var _more = <DonEntry>[];
  String? _cursor;
  var _loadingMore = false;

  Future<void> _loadMore(String cursor) async {
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(menRepositoryProvider)
          .loadLedger(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _more = [..._more, ...page.items];
        _cursor = page.nextCursor ?? '';
      });
    } on Object {
      // Tarmoq xatosi — tugma qoladi, qayta bosish mumkin.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(donLedgerProvider);
    final first = async.valueOrNull;
    final items = [...?first?.items, ..._more];
    final next = _cursor ?? first?.nextCursor;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.don.title'.tr(),
        ),
        onRefresh: () async {
          setState(() {
            _more = [];
            _cursor = null;
          });
          ref.invalidate(donLedgerProvider);
        },
        children: [
          Row(
            children: [
              Expanded(
                child: _Total(
                  label: 'g5.men.don.confirmed'.tr(),
                  value: first?.balance ?? 0,
                  hue: GHue.gold,
                  icon: GIcons.sealCheck,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Total(
                  label: 'g5.men.don.pending'.tr(),
                  value: first?.pending ?? 0,
                  hue: GHue.slate,
                  icon: GIcons.hourglassMedium,
                ),
              ),
            ],
          ),
          if (async.isLoading && first == null)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (async.hasError && first == null)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(donLedgerProvider),
              ),
            )
          else if (items.isEmpty)
            GNote(
              text: 'g5.men.don.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.coins,
            )
          else
            GList(children: [for (final e in items) _EntryRow(entry: e)]),
          if (next != null && next.isNotEmpty)
            GButton(
              label: 'g5.men.don.more'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              loading: _loadingMore,
              onPressed: _loadingMore ? null : () => _loadMore(next),
            ),
          GNote(
            text: '${'g5.men.don.once'.tr()} ${'g5.men.don.noDonFor'.tr()}',
            kind: GNoteKind.plain,
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.hue,
    required this.icon,
  });

  final String label;
  final int value;
  final GHue hue;
  final GIconData icon;

  @override
  Widget build(BuildContext context) => GGlass(
    kind: GGlassKind.feat,
    glowHue: hue,
    padding: const EdgeInsets.all(14),
    child: MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GTile(icon: icon, hue: hue, size: 36),
          const SizedBox(height: 10),
          Text(label, style: GText.caption),
          Text('$value DON', style: GText.display(20)),
        ],
      ),
    ),
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final DonEntry entry;

  @override
  Widget build(BuildContext context) {
    final look = donEntryLook(entry);
    final at = entry.at;
    final when =
        '${localizedDayMonth(at)}, ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final related = entry.relatedId;
    final amount = entry.amount > 0 ? '+${entry.amount}' : '${entry.amount}';
    return GListItem(
      leading: GTile(icon: look.icon, hue: look.hue, size: 40),
      title: donEntryTitle(entry),
      subtitle: entry.pending ? '$when · ${'g5.men.don.pending'.tr()}' : when,
      trailing: Text(
        amount,
        style: GText.display(16).copyWith(
          color: entry.amount > 0 ? GColors.success : GColors.textMuted,
        ),
      ),
      onTap: entry.kind == DonKind.learning && related != null
          ? () => GrowthLinks.result(context, related)
          : null,
    );
  }
}
