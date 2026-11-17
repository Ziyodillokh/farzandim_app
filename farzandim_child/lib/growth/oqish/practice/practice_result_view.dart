// U08 · Mashq natijasi: medal, yulduzlar, o'z oldingi natijasi bilan
// solishtirish, mavzular va DON kvitansiyasi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_outcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PracticeResultView extends StatelessWidget {
  const PracticeResultView({
    super.key,
    required this.result,
    required this.outcome,
    required this.previous,
    required this.topic,
    required this.onClose,
    required this.onNextPractice,
    required this.onKnowledgeMap,
    required this.onDonHistory,
  });

  final TestResult result;
  final PracticeOutcome outcome;
  final TestResult? previous;
  final String topic;
  final VoidCallback onClose;
  final VoidCallback onNextPractice;
  final VoidCallback onKnowledgeMap;
  final VoidCallback onDonHistory;

  String get _title => switch (outcome.tone) {
    OutcomeTone.great => 'g5.practice.result.titleGreat',
    OutcomeTone.good => 'g5.practice.result.titleGood',
    OutcomeTone.start => 'g5.practice.result.titleStart',
  }.tr();

  String get _trend => switch (outcome.trend) {
    OutcomeTrend.first => 'g5.practice.result.first'.tr(),
    OutcomeTrend.better => 'g5.practice.result.better'.tr(
      namedArgs: {'count': '${outcome.difference}'},
    ),
    OutcomeTrend.same => 'g5.practice.result.same'.tr(),
    OutcomeTrend.lower => 'g5.practice.result.lower'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final label = topic.isEmpty
        ? result.subject.label
        : '${result.subject.label} · $topic';
    return GScreen(
      theme: GBgTheme.gold,
      top: Align(
        alignment: Alignment.centerLeft,
        child: GTopBar.close(label: 'g5.common.close'.tr(), onPressed: onClose),
      ),
      dock: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GButton(
            label: 'g5.practice.result.nextPractice'.tr(),
            trailingIcon: GIcons.arrowRight,
            onPressed: onNextPractice,
          ),
          const SizedBox(height: 10),
          GButton(
            label: 'g5.practice.result.knowledgeMap'.tr(),
            kind: GButtonKind.ghost,
            size: GButtonSize.second,
            onPressed: onKnowledgeMap,
          ),
        ],
      ),
      children: [
        _Hero(title: _title, subtitle: _trend, stars: outcome.stars),
        _ScoreCard(label: label, result: result, previous: previous),
        if (outcome.strongTopic != null || outcome.reviewTopic != null)
          Semantics(
            label: 'g5.practice.result.skillsLabel'.tr(),
            container: true,
            child: GList(
              children: [
                if (outcome.strongTopic != null)
                  GListItem(
                    leading: const GTile(
                      icon: GIcons.sealCheck,
                      hue: GHue.green,
                      size: 40,
                    ),
                    title: outcome.strongTopic!,
                    subtitle: 'g5.practice.result.strong'.tr(),
                  ),
                if (outcome.reviewTopic != null)
                  GListItem(
                    leading: const GTile(
                      icon: GIcons.arrowsCounterClockwise,
                      hue: GHue.blue,
                      size: 40,
                    ),
                    title: outcome.reviewTopic!,
                    subtitle: 'g5.practice.result.review'.tr(),
                  ),
              ],
            ),
          ),
        if (result.donEarned > 0)
          _DonReceipt(amount: result.donEarned, onTap: onDonHistory)
        else if (!result.isDaily)
          GNote(text: 'g5.practice.result.donNotDaily'.tr(), icon: GIcons.coin),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.stars,
  });

  final String title;
  final String subtitle;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExcludeSemantics(
          child: SvgPicture.string(_medalSvg, width: 160, height: 124),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GText.display(26),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GText.onest(14, color: GColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'g5.practice.result.starsA11y'.tr(
            namedArgs: {'count': '$stars'},
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Star(on: stars >= 1, size: 30),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _Star(on: stars >= 2, size: 40),
                ),
                const SizedBox(width: 8),
                _Star(on: stars >= 3, size: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.on, required this.size});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(on ? _starOn : _starOff, width: size, height: size);
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.result,
    required this.previous,
  });

  final String label;
  final TestResult result;
  final TestResult? previous;

  @override
  Widget build(BuildContext context) {
    final prev = previous;
    return GGlass(
      kind: GGlassKind.feat,
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GText.label.copyWith(color: GColors.link),
          ),
          const SizedBox(height: 6),
          Text(
            'g5.practice.result.score'.tr(
              namedArgs: {
                'correct': '${result.correct}',
                'total': '${result.total}',
              },
            ),
            style: GText.display(20).copyWith(height: 1.25),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: prev == null
                ? null
                : 'g5.practice.result.compareA11y'.tr(
                    namedArgs: {
                      'correct': '${result.correct}',
                      'total': '${result.total}',
                      'prevCorrect': '${prev.correct}',
                      'prevTotal': '${prev.total}',
                    },
                  ),
            child: ExcludeSemantics(
              excluding: prev != null,
              child: Column(
                children: [
                  _CompareRow(
                    label: 'g5.practice.result.thisTime'.tr(),
                    correct: result.correct,
                    total: result.total,
                  ),
                  if (prev != null) ...[
                    const SizedBox(height: 10),
                    _CompareRow(
                      label: 'g5.practice.result.previous'.tr(),
                      correct: prev.correct,
                      total: prev.total,
                      muted: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.correct,
    required this.total,
    this.muted = false,
  });

  final String label;
  final int correct;
  final int total;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final value = total <= 0 ? 0.0 : correct / total;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            maxLines: 1,
            style: GText.onest(
              12.5,
              weight: FontWeight.w600,
              color: GColors.textLabel,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: muted
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0x14FFFFFF)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: const ColoredBox(color: Color(0x42FFFFFF)),
                        ),
                      ],
                    ),
                  ),
                )
              : GProgressBar(value: value),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '$correct/$total',
            textAlign: TextAlign.right,
            style: GText.display(
              13,
            ).copyWith(color: muted ? GColors.textMuted : GColors.text),
          ),
        ),
      ],
    );
  }
}

class _DonReceipt extends StatelessWidget {
  const _DonReceipt({required this.amount, required this.onTap});

  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onTap,
      semanticLabel: 'g5.practice.result.donA11y'.tr(
        namedArgs: {'count': '$amount'},
      ),
      pressedScale: .98,
      child: GGlass(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const GTile(icon: GIcons.coin, hue: GHue.gold, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('+$amount DON', style: GText.display(17)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const GIcon(
                        GIcons.checkCircle,
                        size: 15,
                        color: Color(0xFFBFF3DB),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'g5.practice.result.donConfirmed'.tr(),
                        style: GText.onest(
                          12.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFFBFF3DB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const GIcon(
              GIcons.caretRight,
              size: 18,
              color: GColors.chevron,
              secondaryOpacity: 0,
            ),
          ],
        ),
      ),
    );
  }
}

const _starPath =
    'M12 2.4l2.47 6.6 7.04.31-5.52 4.39 1.89 6.79L12 16.6l-5.88 3.89 1.89-6.79-5.52-4.39 7.04-.31z';

const _starOn =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><defs>'
    '<linearGradient id="s" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFEFB0"/>'
    '<stop offset=".5" stop-color="#FFC547"/><stop offset="1" stop-color="#D98208"/></linearGradient></defs>'
    '<path d="$_starPath" fill="url(#s)" stroke="url(#s)" stroke-width="1.6" stroke-linejoin="round"/></svg>';

const _starOff =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<path d="$_starPath" fill="#FFFFFF" fill-opacity=".07" stroke="#FFFFFF" stroke-opacity=".22" '
    'stroke-width="1.4" stroke-linejoin="round"/></svg>';

/// Kanvasdagi medal (U08) — flutter_svg qo'llab-quvvatlaydigan elementlar bilan.
const _medalSvg =
    '<svg viewBox="0 0 240 186" xmlns="http://www.w3.org/2000/svg"><defs>'
    '<radialGradient id="g"><stop offset="0" stop-color="#FFC94D" stop-opacity=".34"/>'
    '<stop offset="1" stop-color="#FFC94D" stop-opacity="0"/></radialGradient>'
    '<linearGradient id="a" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFEFB0"/>'
    '<stop offset=".45" stop-color="#FFC547"/><stop offset="1" stop-color="#C9760A"/></linearGradient>'
    '<linearGradient id="b" x1="1" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFE08A"/>'
    '<stop offset="1" stop-color="#A45A08"/></linearGradient>'
    '<linearGradient id="r1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5B8DFF"/>'
    '<stop offset="1" stop-color="#1E3A9E"/></linearGradient>'
    '<linearGradient id="r2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5FC3F5"/>'
    '<stop offset="1" stop-color="#0B5E9C"/></linearGradient></defs>'
    '<circle cx="120" cy="88" r="92" fill="url(#g)"/>'
    '<path d="M120 2v14M120 160v14M30 88h14M196 88h14M57 25l10 10M173 141l10 10M183 25l-10 10M67 141l-10 10" '
    'stroke="#FFE3A3" stroke-opacity=".18" stroke-width="2" stroke-linecap="round"/>'
    '<path d="M96 110 80 170l18-10 12 16 14-58z" fill="url(#r1)"/>'
    '<path d="M144 110l16 60-18-10-12 16-14-58z" fill="url(#r2)"/>'
    '<circle cx="120" cy="84" r="50" fill="url(#a)"/><circle cx="120" cy="84" r="39" fill="url(#b)"/>'
    '<circle cx="120" cy="84" r="39" fill="none" stroke="#FFF4C7" stroke-opacity=".5" stroke-width="1.5"/>'
    '<path d="M120 60l7.4 15 16.6 2.4-12 11.7 2.8 16.5L120 97.8l-14.8 7.8 2.8-16.5-12-11.7 16.6-2.4z" fill="#FFF6DA"/>'
    '<path d="M86 62a38 38 0 0 1 22-18" stroke="#FFFFFF" stroke-opacity=".55" stroke-width="4" stroke-linecap="round" fill="none"/>'
    '<path d="M198 36l3 8 8 3-8 3-3 8-3-8-8-3 8-3z" fill="#FFE3A3" opacity=".9"/>'
    '<path d="M42 122l2 5.5 5.5 2-5.5 2-2 5.5-2-5.5-5.5-2 5.5-2z" fill="#A9C4FF" opacity=".9"/>'
    '<circle cx="210" cy="78" r="3" fill="#5B8DFF"/><circle cx="28" cy="82" r="2.5" fill="#FFD27A"/></svg>';
