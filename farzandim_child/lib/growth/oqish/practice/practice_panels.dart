// U06 tushuntirish paneli (pastdan) va U07 «Mashqni to'xtatasanmi?» varag'i.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/shared/widgets/math_text.dart';
import 'package:flutter/material.dart';

/// Javob tekshirilgandan keyin ekran pastida chiqadigan panel: qo'llab-
/// quvvatlovchi sarlavha, to'g'ri javob, izoh va bitta keyingi harakat.
class ExplanationPanel extends StatelessWidget {
  const ExplanationPanel({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
    required this.actionLabel,
    required this.onAction,
  });

  final bool isCorrect;
  final String correctAnswer;
  final String explanation;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 28 + bottom),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(GRadius.sheet),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF7141C36), Color(0xFC090D1D)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xCC000000),
              offset: Offset(0, -24),
              blurRadius: 60,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GTile(
                  icon: isCorrect ? GIcons.sealCheck : GIcons.lightbulb,
                  hue: isCorrect ? GHue.green : GHue.gold,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (isCorrect
                                ? 'g5.practice.correctTitle'
                                : 'g5.practice.wrongTitle')
                            .tr(),
                        style: GText.h2,
                      ),
                      const SizedBox(height: 3),
                      MathText(
                        'g5.practice.answerLine'.tr(
                          namedArgs: {'answer': correctAnswer},
                        ),
                        style: GText.onest(
                          14,
                          weight: FontWeight.w600,
                          color: isCorrect
                              ? const Color(0xFFBFF3DB)
                              : GColors.textLabel,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                // Uzun izoh panelni ekrandan chiqarib yubormasin.
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .3,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0x0AFFFFFF),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: SingleChildScrollView(
                    child: MathText(explanation, style: GText.body),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            GButton(
              label: actionLabel,
              trailingIcon: GIcons.arrowRight,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// U07: mashqdan chiqishdan oldin tasdiq. `true` — chiqish, `false`/`null` — qolish.
Future<bool> confirmPracticeExit(
  BuildContext context, {
  required int savedAnswers,
  required String context0,
}) async {
  final leave = await showGSheet<bool>(
    context,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('g5.practice.exit.title'.tr(), style: GText.h2),
        ),
        const SizedBox(height: 6),
        Text('g5.practice.exit.body'.tr(), style: GText.body),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0x0AFFFFFF),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: MergeSemantics(
            child: Row(
              children: [
                const GTile(icon: GIcons.cloudCheck, hue: GHue.green, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'g5.practice.exit.saved'.tr(
                          namedArgs: {'count': '$savedAnswers'},
                        ),
                        style: GText.itemTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(context0, style: GText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GButton(
          label: 'g5.practice.exit.continue'.tr(),
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
        const SizedBox(height: 10),
        GButton(
          label: 'g5.practice.exit.leave'.tr(),
          kind: GButtonKind.ghost,
          size: GButtonSize.second,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
      ],
    ),
  );
  return leave ?? false;
}
