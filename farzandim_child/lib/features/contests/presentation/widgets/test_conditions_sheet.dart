// ─────────────────────────────────────────────────────────────────────
// test_conditions_sheet — "Konkurs shartlari" bottom sheet (Figma)
// ─────────────────────────────────────────────────────────────────────
//
// Testni bosganda ochiladi. Qiyinlik tanlovi (Oson/O'rta/Qiyin) —
// tanlashda "vaqt" qatori DINAMIK yangilanadi (per-savol soniya). Savollar
// soni va sovrin testning haqiqiy qiymatlari. "Boshlash" → quiz (tanlangan
// qiyinlik selectedTestDifficultyProvider orqali quiz timeriga o'tadi).

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/test_difficulty.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Konkurs shartlari" sheet'ni ko'rsatadi. "Boshlash" bosilsa quiz'ga o'tadi.
Future<void> showTestConditionsSheet(
  BuildContext context,
  ContestModel contest,
  void Function(ContestModel) onStart,
) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConditionsSheet(contest: contest),
  );
  if (started == true && context.mounted) onStart(contest);
}

class _ConditionsSheet extends ConsumerStatefulWidget {
  const _ConditionsSheet({required this.contest});

  final ContestModel contest;

  @override
  ConsumerState<_ConditionsSheet> createState() => _ConditionsSheetState();
}

class _ConditionsSheetState extends ConsumerState<_ConditionsSheet> {
  late TestDifficulty _difficulty = inherentDifficulty(
    widget.contest.savollarSoni,
  );

  void _select(TestDifficulty d) {
    HapticFeedback.selectionClick();
    setState(() => _difficulty = d);
  }

  void _start() {
    HapticFeedback.mediumImpact();
    ref.read(selectedTestDifficultyProvider.notifier).state = _difficulty;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contest;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1119),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: tGlassBorder)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: tGlassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Konkurs shartlari',
                style: tUnb(19, w: FontWeight.w700, ls: -0.4),
              ),
            ),
            const SizedBox(height: 22),
            // ── Qiyinlik darajasi ──
            Text('Qiyinlik darajasi', style: tPop(13, c: tMuted)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final d in TestDifficulty.values) ...[
                  Expanded(
                    child: _DiffPill(
                      difficulty: d,
                      selected: _difficulty == d,
                      onTap: () => _select(d),
                    ),
                  ),
                  if (d != TestDifficulty.values.last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
            const _SheetDivider(),
            _InfoBlock(
              label: 'Savollar soni',
              value: Text(
                '${c.savollarSoni} ta',
                style: tUnb(18, w: FontWeight.w700, ls: -0.4),
              ),
            ),
            const _SheetDivider(),
            _InfoBlock(
              label: 'Har bir savol uchun beriladigan vaqt',
              // DINAMIK — tanlangan qiyinlikka qarab.
              value: Text(
                '${_difficulty.secondsPerQuestion} soniyadan',
                style: tUnb(18, w: FontWeight.w700, ls: -0.4),
              ),
            ),
            const _SheetDivider(),
            // Sovrin — bu MAKSIMAL fond, hammasini to'g'ri topgandagina to'liq
            // beriladi. Har to'g'ri javob shu fonddan teng ulush oladi, 30% dan
            // past natijada esa umuman berilmaydi (backend `rewardFor`).
            // Avval shunchaki "20 DON" deb turardi — bola hammasini oladi deb
            // o'ylardi.
            _InfoBlock(
              label: 'Sovrin',
              value: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.bonus}',
                    style: tUnb(18, w: FontWeight.w700, ls: -0.4),
                  ),
                  const SizedBox(width: 6),
                  const DonBadge(),
                  const SizedBox(width: 6),
                  Text(
                    'gacha',
                    style: tUnb(13, w: FontWeight.w500, ls: -0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Har bir to\'g\'ri javob uchun ulush beriladi. '
              'Natija 30% dan past bo\'lsa sovrin berilmaydi.',
              style: tPop(12, c: tMuted),
            ),
            const SizedBox(height: 26),
            _StartButton(onTap: _start),
          ],
        ),
      ),
    );
  }
}

class _DiffPill extends StatelessWidget {
  const _DiffPill({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final TestDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? tBlue : tGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? tBlue : tGlassBorder),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            difficulty.label,
            style: tPop(
              14.5,
              w: FontWeight.w600,
              c: selected ? Colors.white : tDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tPop(13, c: tMuted)),
        const SizedBox(height: 7),
        value,
      ],
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Divider(color: tGlassBorder, height: 1, thickness: 1),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tBlue,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: tBlue.withValues(alpha: 0.4),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Boshlash', style: tPop(16, w: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
