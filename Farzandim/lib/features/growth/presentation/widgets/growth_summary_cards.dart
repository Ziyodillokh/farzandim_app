// ─────────────────────────────────────────────────────────────────────
// growth_summary_cards — Growth xulosasi kartalari (ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// O'rtacha natija (oldingi davrga nisbatan o'zgarish bilan), testlar /
// faol kunlar / ketma-ket kunlar, fanlar bo'yicha chiziqlar, eng yaxshi
// fan va mashq qilishga arziydigan fan. Uslub maktab kartalari bilan bir
// xil: karta #1A1F23, hairline oq 12%, radius 24.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/growth/presentation/growth_view_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _chipBg = Color(0xFF1B2128);
const _track = Color(0x14FFFFFF); // oq 8%
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _green = Color(0xFF34C759);
const _amber = Color(0xFFFBBF24);
const _orange = Color(0xFFFB923C);
const _flame = Color(0xFFFF7A1A);

/// Foiz chizig'i uchun maksimal qiymat.
const double _fullPercent = 100;

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.8,
  height: 1.2,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.45);

/// Natija darajasi rangi (yaxshi — yashil, o'rtacha — sariq, past —
/// to'q sariq; qizil ishlatilmaydi — ohang qo'llab-quvvatlovchi).
Color growthLevelColor(ResultLevel level) => switch (level) {
  ResultLevel.good => _green,
  ResultLevel.fair => _amber,
  ResultLevel.low => _orange,
};

/// O'zgarish yo'nalishi rangi.
Color growthTrendColor(GrowthTrend trend) => switch (trend) {
  GrowthTrend.up => _green,
  GrowthTrend.down => _orange,
  GrowthTrend.flat => _dim,
};

/// Fan ikoni.
IconData growthSubjectIcon(LearningSubject subject) => switch (subject) {
  LearningSubject.math => SolarIconsBold.calculator,
  LearningSubject.english => SolarIconsBold.translation,
  LearningSubject.native => SolarIconsBold.book,
  LearningSubject.history => SolarIconsBold.hourglass,
  LearningSubject.biology => SolarIconsBold.dna,
  LearningSubject.geography => SolarIconsBold.globus,
  LearningSubject.physics => SolarIconsBold.atom,
  LearningSubject.chemistry => SolarIconsBold.testTube,
  LearningSubject.informatics => SolarIconsBold.laptop,
  LearningSubject.russian => SolarIconsBold.bookBookmark,
  LearningSubject.unknown => SolarIconsBold.squareAcademicCap,
};

/// Umumiy karta qobig'i.
class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }
}

/// O'rtacha natija, o'zgarish va uchta ko'rsatkich.
class GrowthOverviewCard extends StatelessWidget {
  const GrowthOverviewCard({required this.summary, super.key});

  final LearningSummary summary;

  @override
  Widget build(BuildContext context) {
    final percent = summary.overallPercent;
    final delta = summary.growthPercent;
    final days = '${summary.periodDays}';
    return _GrowthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('growth.overall'.tr(), style: _pop(13, c: _dim)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(growthPercentLabel(percent), style: _unb(30)),
              if (delta != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: _DeltaLabel(delta: delta, days: days),
                ),
              ],
            ],
          ),
          if (percent != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: percent / _fullPercent,
              minHeight: 6,
              color: _blue,
              backgroundColor: _track,
              borderRadius: BorderRadius.circular(99),
              semanticsLabel: 'growth.overall'.tr(),
              semanticsValue: growthPercentLabel(percent),
            ),
          ],
          if (summary.totalAnswers > 0) ...[
            const SizedBox(height: 6),
            Text(
              'growth.answers'.tr(
                namedArgs: {
                  'correct': '${summary.correctAnswers}',
                  'total': '${summary.totalAnswers}',
                },
              ),
              style: _pop(12.5, c: _dim),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  icon: SolarIconsBold.checklist,
                  color: _blue,
                  value: '${summary.testsCount}',
                  label: 'growth.tests'.tr(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: SolarIconsBold.calendarMark,
                  color: _green,
                  value: '${summary.activeDays}/$days',
                  label: 'growth.activeDays'.tr(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  icon: SolarIconsBold.flame,
                  color: _flame,
                  value: '${summary.streakDays}',
                  label: 'growth.streak'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "+5% oldingi 7 kunga nisbatan".
class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel({required this.delta, required this.days});

  final int delta;
  final String days;

  @override
  Widget build(BuildContext context) {
    final trend = growthTrendOf(delta);
    final color = growthTrendColor(trend);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: growthDeltaLabel(delta),
              style: _pop(13, w: FontWeight.w600, c: color),
            ),
            TextSpan(
              text: ' ${'growth.vsPrevious'.tr(namedArgs: {'days': days})}',
              style: _pop(12, c: _dim),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Kichik ko'rsatkich: ikon, qiymat, yorliq.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _unb(17),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _pop(11.5, c: _dim),
          ),
        ],
      ),
    );
  }
}

/// Fanlar bo'yicha foiz chiziqlari.
class GrowthSubjectsCard extends StatelessWidget {
  const GrowthSubjectsCard({required this.subjects, super.key});

  final List<SubjectStat> subjects;

  @override
  Widget build(BuildContext context) {
    return _GrowthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('growth.bySubject'.tr(), style: _unb(15)),
          for (final stat in subjects) ...[
            const SizedBox(height: 14),
            _SubjectBar(stat: stat),
          ],
        ],
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.stat});

  final SubjectStat stat;

  @override
  Widget build(BuildContext context) {
    final color = growthLevelColor(resultLevelOf(stat.percent));
    final name = stat.subject.labelKey.tr();
    final percent = growthPercentLabel(stat.percent);
    return Semantics(
      label: '$name, $percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(growthSubjectIcon(stat.subject), size: 18, color: _dim),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(14, w: FontWeight.w500),
                ),
              ),
              Text(
                'growth.subjectTests'.tr(namedArgs: {'count': '${stat.tests}'}),
                style: _pop(12, c: _dim),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  percent,
                  textAlign: TextAlign.end,
                  style: _pop(14, w: FontWeight.w600, c: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: stat.percent / _fullPercent,
            minHeight: 6,
            color: color,
            backgroundColor: _track,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }
}

/// Eng yaxshi fan va mashq qilishga arziydigan fan (bo'lganlari).
class GrowthHighlights extends StatelessWidget {
  const GrowthHighlights({required this.summary, super.key});

  final LearningSummary summary;

  @override
  Widget build(BuildContext context) {
    final strong = summary.strongSubject;
    final focus = summary.focusSubject;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (strong != null)
          _HighlightTile(
            icon: SolarIconsBold.cupStar,
            color: _green,
            label: 'growth.strong'.tr(),
            subject: strong,
          ),
        if (strong != null && focus != null) const SizedBox(height: 8),
        if (focus != null)
          _HighlightTile(
            icon: SolarIconsBold.target,
            color: _amber,
            label: 'growth.focus'.tr(),
            subject: focus,
            hint: 'growth.focusHint'.tr(),
          ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subject,
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final LearningSubject subject;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return _GrowthCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _pop(12.5, c: _dim)),
                Text(
                  subject.labelKey.tr(),
                  style: _pop(15.5, w: FontWeight.w600),
                ),
                if (hint != null) Text(hint, style: _pop(12.5, c: _dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
