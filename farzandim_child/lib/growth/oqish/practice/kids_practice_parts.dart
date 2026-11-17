// U05 (1–4-sinf savoli) va U20 (kichiklar natijasi) qismlari: katta savol,
// katta variant plitalari, javob shu ekranning o'zida tekshiriladi va
// uyaltirmaydigan izoh; natijada katta yulduzlar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_parts.dart';
import 'package:farzandim_child/shared/widgets/math_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Savol kartasi: fan · mavzu, katta savol va (tekshirilgach) izoh.
class KidsQuestionCard extends StatelessWidget {
  const KidsQuestionCard({
    super.key,
    required this.subject,
    required this.topic,
    required this.prompt,
    this.feedback,
  });

  final Subject subject;
  final String topic;
  final String prompt;
  final Widget? feedback;

  @override
  Widget build(BuildContext context) {
    return GGlass(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.isEmpty ? subject.label : '${subject.label} · $topic',
            style: GText.onest(
              13,
              weight: FontWeight.w600,
              color: GColors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: MathText(prompt, style: GText.display(26)),
          ),
          if (feedback != null) ...[const SizedBox(height: 14), feedback!],
        ],
      ),
    );
  }
}

/// Javobdan keyingi izoh: to'g'ri — yashil «Barakalla!», xato — ko'k
/// «Keling, birga o'ylaymiz» (uyaltirmaydi, to'g'ri javobni ko'rsatadi).
class KidsFeedback extends StatelessWidget {
  const KidsFeedback({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
  });

  final bool isCorrect;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final hue = isCorrect ? GHue.green : GHue.blue;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: hue.base.withValues(alpha: .12),
          border: Border.all(
            color:
                (isCorrect ? const Color(0xFF6EE7B7) : const Color(0xFF96B9FF))
                    .withValues(alpha: .3),
          ),
        ),
        child: Row(
          children: [
            GTile(
              icon: isCorrect ? GIcons.checkCircle : GIcons.handPointing,
              hue: hue,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (isCorrect ? 'g5.kids.right' : 'g5.kids.tryTitle').tr(),
                    style: GText.onest(
                      16,
                      weight: FontWeight.w700,
                      color: isCorrect
                          ? const Color(0xFFBFF3DB)
                          : const Color(0xFFD3E1FF),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 1),
                  MathText(
                    'g5.kids.answerLine'.tr(
                      namedArgs: {'answer': correctAnswer},
                    ),
                    style: GText.onest(
                      14,
                      color: GColors.textBody,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Katta variant plitasi (2 ustunli katak uchun): harf va katta qiymat.
class KidsOption extends StatelessWidget {
  const KidsOption({
    super.key,
    required this.index,
    required this.text,
    required this.look,
    this.onTap,
  });

  final int index;
  final String text;
  final OptionLook look;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, valueColor) = switch (look) {
      OptionLook.selected => (
        const Color(0xFFA9C4FF),
        const Color(0x384F86FF),
        GColors.white,
      ),
      OptionLook.correct => (
        const Color(0xB36EE7B7),
        const Color(0x3310B981),
        GColors.white,
      ),
      OptionLook.missed => (
        const Color(0x99FCD34D),
        const Color(0x24F59E0B),
        GColors.text,
      ),
      OptionLook.dim => (
        const Color(0x0FFFFFFF),
        const Color(0x800B1022),
        GColors.textMuted,
      ),
      OptionLook.idle => (
        const Color(0x1FFFFFFF),
        GColors.glassFill,
        GColors.text,
      ),
    };
    final radius = BorderRadius.circular(24);
    return GPressable(
      onTap: onTap,
      selected: onTap != null ? look == OptionLook.selected : null,
      exclusive: onTap != null,
      haptic: true,
      semanticLabel: 'g5.practice.optionA11y'.tr(
        namedArgs: {'letter': optionLetter(index), 'value': text},
      ),
      child: GOuterShadow(
        borderRadius: radius,
        shadows: look == OptionLook.selected
            ? GOuterShadow.ring(GColors.focusRing)
            : const [],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: fill,
            border: Border.all(
              color: border,
              width: look == OptionLook.selected ? 2.5 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: MathText(
            text,
            textAlign: TextAlign.center,
            style: GText.display(30).copyWith(color: valueColor),
          ),
        ),
      ),
    );
  }
}

/// U20: katta yulduzlar, maqtov, ball va DON; «Bosh sahifaga».
class KidsResultView extends StatelessWidget {
  const KidsResultView({
    super.key,
    required this.result,
    required this.name,
    required this.topic,
    required this.onHome,
  });

  final TestResult result;
  final String name;
  final String topic;
  final VoidCallback onHome;

  /// 5 yulduzli shkala (kichiklar uchun aniqroq).
  int get stars => result.total <= 0
      ? 0
      : (result.correct * 5 / result.total).round().clamp(0, 5);

  @override
  Widget build(BuildContext context) {
    return GScreen(
      theme: GBgTheme.gold,
      dock: GButton(
        label: 'g5.kids.home'.tr(),
        icon: GIcons.house,
        size: GButtonSize.xl,
        onPressed: onHome,
      ),
      children: [
        const SizedBox(height: 40),
        Semantics(
          label: 'g5.kids.starsA11y'.tr(namedArgs: {'count': '$stars'}),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == 2 ? 14 : (i == 1 || i == 3 ? 6 : 0),
                    ),
                    child: SvgPicture.string(
                      i < stars ? kidsStarOn : kidsStarOff,
                      width: i == 2 ? 64 : (i == 1 || i == 3 ? 52 : 42),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          topic.isEmpty
              ? result.subject.label
              : '${result.subject.label} · $topic',
          textAlign: TextAlign.center,
          style: GText.onest(
            15,
            weight: FontWeight.w600,
            color: GColors.textMuted,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            name.isEmpty
                ? 'g5.kids.resultTitleAnon'.tr()
                : 'g5.kids.resultTitle'.tr(namedArgs: {'name': name}),
            textAlign: TextAlign.center,
            style: GText.display(30),
          ),
        ),
        Text(
          'g5.kids.resultScore'.tr(
            namedArgs: {
              'correct': '${result.correct}',
              'total': '${result.total}',
            },
          ),
          textAlign: TextAlign.center,
          style: GText.onest(
            18,
            weight: FontWeight.w600,
            color: GColors.textLabel,
          ),
        ),
        if (result.donEarned > 0)
          Center(
            child: GChip(
              label: 'g5.kids.don'.tr(
                namedArgs: {'count': '${result.donEarned}'},
              ),
              kind: GChipKind.warn,
              icon: GIcons.coin,
            ),
          ),
      ],
    );
  }
}

const _kidsStarPath =
    'M12 2.4l2.47 6.6 7.04.31-5.52 4.39 1.89 6.79L12 16.6l-5.88 3.89 1.89-6.79-5.52-4.39 7.04-.31z';

const kidsStarOn =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><defs>'
    '<linearGradient id="s" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFEFB0"/>'
    '<stop offset=".5" stop-color="#FFC547"/><stop offset="1" stop-color="#D98208"/></linearGradient></defs>'
    '<path d="$_kidsStarPath" fill="url(#s)" stroke="url(#s)" stroke-width="1.6" stroke-linejoin="round"/></svg>';

const kidsStarOff =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<path d="$_kidsStarPath" fill="#FFFFFF" fill-opacity=".07" stroke="#FFFFFF" stroke-opacity=".22" '
    'stroke-width="1.4" stroke-linejoin="round"/></svg>';
