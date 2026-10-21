// ─────────────────────────────────────────────────────────────────────
// payment_cards — to'lov eslatmasi va tekshiruv so'rovi kartalari
// ─────────────────────────────────────────────────────────────────────
//
// Eslatma ataylab summasiz: maktab, keyingi to'lov sanasi, oldindan
// to'langan oylar, "eslatmalar to'xtatilgan" belgisi va o'quvchilar.
// "To'laganman, tekshiring" ochiq so'rov bo'lsa o'chiq ("ko'rib
// chiqilmoqda"). So'rov kartasi: holat, xabar va maktab javobi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _innerBg = Color(0x0AFFFFFF); // oq 4%
const _innerBorder = Color(0x14FFFFFF); // oq 8%
const _blue = Color(0xFF216BFF);
const _blueSoft = Color(0xFF6FA0FF);
const _green = Color(0xFF34C759);
const _dim = Color(0x99FFFFFF); // oq 60%

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.5,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// To'lov eslatmasi kartasi.
class PaymentReminderCard extends StatelessWidget {
  const PaymentReminderCard({
    required this.reminder,
    required this.onVerify,
    this.school,
    super.key,
  });

  final SchoolPaymentReminder reminder;

  /// Bog'lanishlardagi maktab (logo uchun); topilmasa `null`.
  final SchoolInfo? school;

  /// "To'laganman, tekshiring" (ochiq so'rov bo'lsa tugma o'chiq).
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final date = reminder.nextDate.isEmpty
        ? '—'
        : formatSchoolDay(reminder.nextDate);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SchoolLogo(school: school, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reminder.schoolName.isEmpty
                          ? 'school.title'.tr()
                          : reminder.schoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(15.5, w: FontWeight.w600),
                    ),
                    // Alohida qatorda — tor ekranda nomni siqib qo'ymasin.
                    if (reminder.paused) ...[
                      const SizedBox(height: 4),
                      SchoolPill(
                        label: 'school.payments.paused'.tr(),
                        color: _dim,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _innerBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _innerBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  SolarIconsBold.calendarMark,
                  size: 24,
                  color: _blueSoft,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'school.payments.nextDate'.tr(),
                        style: _pop(12.5, c: _dim),
                      ),
                      Text(date, style: _unb(18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (reminder.prepaidMonths > 0) ...[
            const SizedBox(height: 10),
            _InfoLine(
              icon: SolarIconsBold.checkCircle,
              color: _green,
              text: 'school.payments.prepaid'.tr(
                namedArgs: {'count': '${reminder.prepaidMonths}'},
              ),
            ),
          ],
          for (final child in reminder.children) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: SolarIconsBold.backpack,
              color: _dim,
              text: [
                child.name,
                if (child.className.isNotEmpty)
                  'school.classLabel'.tr(namedArgs: {'name': child.className}),
              ].join(' · '),
            ),
          ],
          const SizedBox(height: 14),
          ParvozSecondaryButton(
            label: reminder.openVerification
                ? 'school.payments.verifyPending'.tr()
                : 'school.payments.verify'.tr(),
            leading: Icon(
              reminder.openVerification
                  ? SolarIconsBold.hourglass
                  : SolarIconsBold.checkCircle,
              size: 20,
              color: Colors.white,
            ),
            enabled: !reminder.openVerification,
            onPressed: onVerify,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _pop(14))),
      ],
    );
  }
}

/// "To'laganman, tekshiring" so'rovi: holat, xabar va maktab javobi.
class VerificationCard extends StatelessWidget {
  const VerificationCard({
    required this.verification,
    this.highlighted = false,
    super.key,
  });

  final PaymentVerification verification;

  /// Push'dan ochilgan so'rov — ko'k hoshiya.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final createdAt = verification.createdAt;
    final answer = verification.answer?.trim() ?? '';
    final answeredAt = verification.answeredAt;
    final details = [
      if (verification.nextDate.isNotEmpty)
        'school.payments.dateLine'.tr(
          namedArgs: {'date': formatSchoolDay(verification.nextDate)},
        ),
      if (createdAt != null) schoolStampLabel(createdAt),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted ? _blue : _cardBorder,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  verification.schoolName.isEmpty
                      ? 'school.title'.tr()
                      : verification.schoolName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(15, w: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              SchoolPill(
                label: verificationStatusKey(verification.status).tr(),
                color: verificationStatusColor(verification.status),
              ),
            ],
          ),
          if (details.isNotEmpty) Text(details, style: _pop(12.5, c: _dim)),
          if (verification.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(verification.message, style: _pop(14)),
          ],
          if (answer.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      'school.verifications.answer'.tr(),
                      if (answeredAt != null) schoolStampLabel(answeredAt),
                    ].join(' · '),
                    style: _pop(12.5, w: FontWeight.w600, c: _blueSoft),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(answer, style: _pop(14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
