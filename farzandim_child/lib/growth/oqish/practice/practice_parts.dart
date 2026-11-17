// U04/U06 qismlari: yuqori panel (yopish + bo'lakli progress), savol kartasi
// va javob varianti (tanlash, tekshirilgandan keyingi holatlar).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/shared/widgets/math_text.dart';
import 'package:flutter/material.dart';

const kOptionLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

String optionLetter(int index) =>
    index < kOptionLetters.length ? kOptionLetters[index] : '${index + 1}';

class PracticeTopBar extends StatelessWidget {
  const PracticeTopBar({
    super.key,
    required this.onClose,
    required this.outcomes,
    required this.current,
  });

  final VoidCallback onClose;

  /// Savol tartibida natija: `true` to'g'ri, `false` xato, `null` javobsiz.
  final List<bool?> outcomes;

  /// Joriy savol (1 dan).
  final int current;

  @override
  Widget build(BuildContext context) {
    final total = outcomes.length;
    return Row(
      children: [
        GTopBar.close(label: 'g5.common.close'.tr(), onPressed: onClose),
        const SizedBox(width: 12),
        Expanded(
          child: GSegments(
            semanticLabel: 'g5.practice.progressA11y'.tr(
              namedArgs: {'current': '$current', 'total': '$total'},
            ),
            states: [
              for (var i = 0; i < total; i++)
                switch (outcomes[i]) {
                  true => GSegmentState.ok,
                  false => GSegmentState.warn,
                  null =>
                    i == current - 1 ? GSegmentState.now : GSegmentState.empty,
                },
            ],
          ),
        ),
        const SizedBox(width: 12),
        ExcludeSemantics(
          child: Text.rich(
            TextSpan(
              text: '$current',
              children: [
                TextSpan(
                  text: '/$total',
                  style: TextStyle(color: GColors.textMuted),
                ),
              ],
            ),
            style: GText.display(13),
          ),
        ),
      ],
    );
  }
}

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.subject,
    required this.topic,
    required this.prompt,
  });

  final Subject subject;
  final String topic;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final context0 = topic.isEmpty
        ? subject.label
        : '${subject.label} · $topic';
    return GGlass(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              subjectTile(subject, size: 28),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context0,
                  style: GText.onest(
                    13,
                    weight: FontWeight.w600,
                    color: GColors.textLabel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: MathText(
              prompt,
              style: GText.onest(
                24,
                weight: FontWeight.w700,
                height: 1.32,
              ).copyWith(letterSpacing: -.24),
            ),
          ),
        ],
      ),
    );
  }
}

/// Variant holati: javob berishda — idle/selected; tekshirilgandan keyin —
/// correct (to'g'ri javob), missed (bolaning xato tanlovi), dim (qolganlari).
enum OptionLook { idle, selected, correct, missed, dim }

class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.index,
    required this.text,
    required this.look,
    this.onTap,
  });

  final int index;
  final String text;
  final OptionLook look;

  /// `null` — tekshirilgan (tanlab bo'lmaydi).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final letter = optionLetter(index);
    final style = _Style.of(look);
    final radius = BorderRadius.circular(GRadius.option);
    final mark = switch (look) {
      OptionLook.correct => (
        'g5.practice.correctAnswer'.tr(),
        GIcons.checkCircle,
      ),
      OptionLook.missed => ('g5.practice.yourAnswer'.tr(), GIcons.xCircle),
      _ => null,
    };
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: style.gradient == null ? style.fill : null,
        gradient: gradientOver(style.gradient, style.fill),
        border: Border.all(color: style.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: style.letterFill,
              gradient: style.letterGradient,
              border: style.letterBorder != null
                  ? Border.all(color: style.letterBorder!)
                  : null,
            ),
            child: Text(
              letter,
              style: GText.display(13).copyWith(color: style.letterText),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: MathText(
              text,
              style: GText.display(20).copyWith(color: style.valueText),
            ),
          ),
          if (mark != null) ...[
            const SizedBox(width: 8),
            Text(
              mark.$1,
              style: GText.onest(
                12.5,
                weight: FontWeight.w600,
                color: style.markText,
              ),
            ),
            const SizedBox(width: 6),
            GIcon(mark.$2, size: 18, color: style.markText),
          ] else if (look == OptionLook.idle ||
              look == OptionLook.selected) ...[
            const SizedBox(width: 8),
            _Tick(on: look == OptionLook.selected),
          ],
        ],
      ),
    );
    final label = 'g5.practice.optionA11y'.tr(
      namedArgs: {'letter': letter, 'value': text},
    );
    final spoken = mark == null ? label : '$label. ${mark.$1}';
    final shadows = switch (look) {
      OptionLook.selected => GOuterShadow.ring(GColors.focusRing),
      OptionLook.correct => GOuterShadow.ring(const Color(0x1A10B981)),
      _ => const <BoxShadow>[],
    };
    return GPressable(
      onTap: onTap,
      selected: onTap != null ? look == OptionLook.selected : null,
      exclusive: onTap != null,
      haptic: true,
      semanticLabel: spoken,
      child: GOuterShadow(borderRadius: radius, shadows: shadows, child: row),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: on
            ? const LinearGradient(
                colors: [Color(0xFF5B8DFF), GColors.primaryMid],
              )
            : null,
        border: on
            ? null
            : Border.all(color: const Color(0x38FFFFFF), width: 2),
      ),
      alignment: Alignment.center,
      child: on
          ? const GIcon(
              GIcons.check,
              size: 14,
              color: GColors.white,
              secondaryOpacity: 0,
            )
          : null,
    );
  }
}

class _Style {
  const _Style({
    required this.border,
    required this.valueText,
    required this.letterText,
    this.fill,
    this.gradient,
    this.letterFill,
    this.letterGradient,
    this.letterBorder,
    this.markText = GColors.text,
  });

  final Color border;
  final Color? fill;
  final Gradient? gradient;
  final Color valueText;
  final Color letterText;
  final Color? letterFill;
  final Gradient? letterGradient;
  final Color? letterBorder;
  final Color markText;

  static const _glass = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0DFFFFFF), Color(0x04FFFFFF)],
  );

  static _Style of(OptionLook look) => switch (look) {
    OptionLook.idle => const _Style(
      border: Color(0x17FFFFFF),
      fill: GColors.glassFill,
      gradient: _glass,
      valueText: GColors.text,
      letterText: GColors.textLabel,
      letterFill: Color(0x0FFFFFFF),
      letterBorder: Color(0x1FFFFFFF),
    ),
    OptionLook.selected => const _Style(
      border: Color(0xB38CB4FF),
      fill: GColors.glassFill,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x424F86FF), Color(0x1F2F5BEA)],
      ),
      valueText: GColors.white,
      letterText: GColors.white,
      letterGradient: LinearGradient(
        colors: [Color(0xFF5B8DFF), GColors.primaryMid],
      ),
    ),
    OptionLook.correct => const _Style(
      border: Color(0xB36EE7B7),
      fill: GColors.glassFill,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x3810B981), Color(0x1410B981)],
      ),
      valueText: GColors.white,
      letterText: GColors.white,
      letterGradient: LinearGradient(
        colors: [Color(0xFF34D399), Color(0xFF0C9A6A)],
      ),
      markText: Color(0xFFBFF3DB),
    ),
    OptionLook.missed => const _Style(
      border: Color(0x99FCD34D),
      fill: GColors.glassFill,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x2EF59E0B), Color(0x12F59E0B)],
      ),
      valueText: GColors.text,
      letterText: Color(0xFFFFE3A3),
      letterFill: Color(0x38F59E0B),
      letterBorder: Color(0x80FCD34D),
      markText: Color(0xFFFFE3A3),
    ),
    OptionLook.dim => const _Style(
      border: Color(0x0FFFFFFF),
      fill: Color(0x800B1022),
      valueText: GColors.textMuted,
      letterText: GColors.textMuted,
      letterFill: Color(0x0AFFFFFF),
      letterBorder: Color(0x14FFFFFF),
    ),
  };
}

/// Variant ko'rinishi: javob berishda tanlov, tekshirilgach to'g'ri/xato/xira.
OptionLook optionLookFor(int index, QuizSession s, AnswerFeedback? feedback) {
  if (feedback == null) {
    return s.selectedIndex == index ? OptionLook.selected : OptionLook.idle;
  }
  if (index == feedback.correctIndex) return OptionLook.correct;
  if (index == feedback.selectedIndex) return OptionLook.missed;
  return OptionLook.dim;
}
