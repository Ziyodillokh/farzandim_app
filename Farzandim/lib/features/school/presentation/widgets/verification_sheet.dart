// ─────────────────────────────────────────────────────────────────────
// VerificationSheet — "To'laganman, tekshiring" (to'lov tekshiruvi so'rovi)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona maktabga to'lov qilganini yozadi (≤ 500 belgi); maktab tekshirib
// javob beradi (push `SCHOOL_VERIFICATION_ANSWERED`). Bitta eslatmada bitta
// ochiq so'rov — 409 bo'lsa xato varaq ichida, ro'yxatlar yangilanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/school_form_rules.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_form_fields.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Varaqni ochadi. `true` — so'rov maktabga yuborildi.
Future<bool> showVerificationSheet(
  BuildContext context, {
  required SchoolPaymentReminder reminder,
}) async {
  final sent = await showSchoolSheet<bool>(
    context,
    builder: (_) => _VerificationSheet(reminder: reminder),
  );
  return sent ?? false;
}

class _VerificationSheet extends ConsumerStatefulWidget {
  const _VerificationSheet({required this.reminder});

  final SchoolPaymentReminder reminder;

  @override
  ConsumerState<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends ConsumerState<_VerificationSheet> {
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// Matn o'zgarganda tugma holati qayta hisoblanadi, eski xato yo'qoladi.
  void _onEdited(String _) => setState(() => _error = null);

  Future<void> _submit() async {
    if (_sending || !canSubmitVerification(_message.text)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(paymentActionsProvider.notifier)
        .requestVerification(
          paymentReminderId: widget.reminder.id,
          message: _message.text,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.success(context, 'school.payments.verifySent'.tr());
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = result.error ?? 'errors.generic'.tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminder = widget.reminder;
    final error = _error;
    final subtitle = [
      if (reminder.schoolName.isNotEmpty) reminder.schoolName,
      if (reminder.nextDate.isNotEmpty)
        'school.payments.dateLine'.tr(
          namedArgs: {'date': formatSchoolDay(reminder.nextDate)},
        ),
    ].join(' · ');
    return SchoolSheetFrame(
      title: 'school.payments.verifyTitle'.tr(),
      subtitle: subtitle,
      children: [
        SchoolNote(
          icon: SolarIconsBold.infoCircle,
          text: 'school.payments.verifyNote'.tr(),
        ),
        const SizedBox(height: 18),
        SchoolTextArea(
          label: 'school.payments.verifyLabel'.tr(),
          hint: 'school.payments.verifyHint'.tr(),
          controller: _message,
          maxLength: kVerificationMessageMax,
          maxLines: 5,
          enabled: !_sending,
          onChanged: _onEdited,
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          SchoolInlineError(message: error),
        ],
        const SizedBox(height: 22),
        ParvozPrimaryButton(
          label: 'school.payments.verifySubmit'.tr(),
          onPressed: _submit,
          enabled: canSubmitVerification(_message.text),
          loading: _sending,
          showArrow: false,
        ),
        const SizedBox(height: 4),
        SchoolTextButton(
          label: 'common.cancel'.tr(),
          onTap: _sending ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
