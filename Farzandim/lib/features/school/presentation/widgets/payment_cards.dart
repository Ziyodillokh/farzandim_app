// ─────────────────────────────────────────────────────────────────────
// payment_cards — To'lovlar sahifasi kartalari
// ─────────────────────────────────────────────────────────────────────
//
// `PaymentStatusCard` — eslatma holati: keyingi sana katta, necha kun
// qolgani / bugun / o'tgani, oldindan to'langan oylar, to'xtatilganlik,
// farzandlar va amallar ("To'laganman, tekshiring", ma'muriyatga savol).
// `PaymentTimeline` — maktab amallari va so'rovlar bitta tarixda.
// Summa yoki qarz YO'Q (TZ 4.5).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/payment_view_models.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_text_fit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

Color paymentStatusColor(PaymentStatus s) => switch (s.kind) {
  PaymentStatusKind.overdue => SK.red,
  PaymentStatusKind.today => SK.amber,
  PaymentStatusKind.upcoming => s.isSoon ? SK.amber : SK.green,
  PaymentStatusKind.checking => SK.sky,
  PaymentStatusKind.paused || PaymentStatusKind.unknown => SK.dim,
};

String paymentStatusLabel(PaymentStatus s) => switch (s.kind) {
  PaymentStatusKind.overdue => 'school.payments.status.overdue'.tr(
    namedArgs: {'count': '${s.days}'},
  ),
  PaymentStatusKind.today => 'school.payments.status.today'.tr(),
  PaymentStatusKind.upcoming => 'school.payments.status.upcoming'.tr(
    namedArgs: {'count': '${s.days}'},
  ),
  PaymentStatusKind.checking => 'school.payments.status.checking'.tr(),
  PaymentStatusKind.paused => 'school.payments.status.paused'.tr(),
  PaymentStatusKind.unknown => 'school.payments.nextDate'.tr(),
};

class PaymentStatusCard extends StatelessWidget {
  const PaymentStatusCard({
    required this.reminder,
    required this.status,
    required this.onVerify,
    required this.onAsk,
    this.school,
    super.key,
  });

  final SchoolPaymentReminder reminder;
  final PaymentStatus status;
  final SchoolInfo? school;
  final VoidCallback onVerify;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final color = paymentStatusColor(status);
    final school = this.school;
    final onAsk = this.onAsk;
    final checking = r.openVerification;
    return SkCard(
      tint: color,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (school != null)
                SchoolLogo(school: school, size: 36)
              else
                const SkIconBubble(
                  icon: SolarIconsBold.squareAcademicCap,
                  size: 36,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: SkTagRow(
                  leading: Text(
                    r.schoolName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: skText(14.5, w: FontWeight.w600, height: 1.35),
                  ),
                  tag: SkTag(label: paymentStatusLabel(status), color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('school.payments.nextDate'.tr(), style: skText(12.5, c: SK.dim)),
          const SizedBox(height: 2),
          Text(
            formatSchoolDay(r.nextDate),
            style: skDisplay(30, c: r.paused ? SK.dim : SK.text),
          ),
          if (r.prepaidMonths > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SkTag(
                label: 'school.payments.status.prepaid'.tr(
                  namedArgs: {'count': '${r.prepaidMonths}'},
                ),
                color: SK.green,
                icon: SolarIconsBold.checkCircle,
              ),
            ),
          ],
          if (r.children.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final child in r.children)
                  SkTag(
                    label: child.className.isEmpty
                        ? child.name
                        : '${child.name} · ${child.className}',
                    icon: SolarIconsBold.backpack,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (checking)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SK.sky.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SK.sky.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(SolarIconsBold.hourglass, size: 18, color: SK.sky),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'school.payments.pin.checking'.tr(),
                      style: skText(13, c: SK.sky, w: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else if (!r.paused)
            ParvozPrimaryButton(
              label: 'school.payments.verify'.tr(),
              onPressed: onVerify,
              showArrow: false,
              height: 52,
            ),
          if (onAsk != null) ...[
            const SizedBox(height: 8),
            ParvozSecondaryButton(
              label: 'school.payments.askAdmin'.tr(),
              onPressed: onAsk,
              leading: const Icon(
                SolarIconsBold.chatRoundDots,
                size: 20,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Maktab amallari va so'rovlar tarixi (vertikal chiziq bilan).
class PaymentTimeline extends StatelessWidget {
  const PaymentTimeline({
    required this.events,
    this.focusVerificationId,
    this.focusKey,
    super.key,
  });

  final List<PaymentEvent> events;
  final String? focusVerificationId;
  final GlobalKey? focusKey;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          'school.payments.historyEmpty'.tr(),
          style: skText(13, c: SK.dim),
        ),
      );
    }
    // Push'dagi so'rovning birinchi (eng yangi) yozuvi ajratiladi.
    final focusIndex = events.indexWhere(
      (e) =>
          e.verificationId != null && e.verificationId == focusVerificationId,
    );
    return SkCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        children: [
          for (final (i, e) in events.indexed)
            _EventRow(
              key: i == focusIndex ? focusKey : null,
              event: e,
              last: i == events.length - 1,
              highlighted: i == focusIndex,
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.last,
    required this.highlighted,
    super.key,
  });

  final PaymentEvent event;
  final bool last;
  final bool highlighted;

  (IconData, Color, String) _look() {
    final e = event;
    return switch (e.kind) {
      PaymentEventKind.requestSent => (
        SolarIconsBold.plain,
        SK.sky,
        'school.payments.requestSent'.tr(),
      ),
      PaymentEventKind.schoolAnswered => (
        SolarIconsBold.chatRoundCheck,
        SK.green,
        'school.payments.schoolAnswered'.tr(),
      ),
      PaymentEventKind.schoolAction => switch (e.action) {
        PaymentAction.verified => (
          SolarIconsBold.billCheck,
          SK.green,
          'school.payments.action.verified'.tr(),
        ),
        PaymentAction.paused => (
          SolarIconsBold.pauseCircle,
          SK.dim,
          'school.payments.action.paused'.tr(),
        ),
        PaymentAction.resumed => (
          SolarIconsBold.playCircle,
          SK.sky,
          'school.payments.action.resumed'.tr(),
        ),
        PaymentAction.shifted => (
          SolarIconsBold.calendarMark,
          SK.amber,
          'school.payments.action.shifted'.tr(),
        ),
        PaymentAction.created => (
          SolarIconsBold.billList,
          SK.teal,
          'school.payments.action.created'.tr(),
        ),
        _ => (
          SolarIconsBold.infoCircle,
          SK.dim,
          'school.payments.action.unknown'.tr(),
        ),
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = _look();
    final text = event.text;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                SkIconBubble(icon: icon, color: color, size: 30),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: SK.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: skText(13.5, w: FontWeight.w600, height: 1.35),
                  ),
                  Text(
                    schoolStampLabel(event.at),
                    style: skText(11.5, c: SK.faint, height: 1.35),
                  ),
                  if (event.hasReceipt) ...[
                    const SizedBox(height: 6),
                    SkTag(
                      label: 'school.payments.hasReceipt'.tr(),
                      color: SK.green,
                      icon: SolarIconsBold.gallery,
                    ),
                  ],
                  if (text != null && text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: highlighted ? 0.14 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: highlighted
                              ? SK.blue
                              : color.withValues(alpha: 0.2),
                          width: highlighted ? 1.5 : 1,
                        ),
                      ),
                      child: Text(text, style: skText(13, height: 1.45)),
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
