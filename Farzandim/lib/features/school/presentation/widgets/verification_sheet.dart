// ─────────────────────────────────────────────────────────────────────
// VerificationSheet — "To'laganman, tekshiring" (to'lov tekshiruvi so'rovi)
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilgan shakl:
//   - to'lov usuli: onlayn (Click, Payme, Uzum, karta, o'tkazma) yoki naqd;
//   - onlayn → o'tkazma chekining rasmi (skrinshot) MAJBURIY; naqd → rasm
//     yo'q, faqat izoh (kimga va qachon berildi);
//   - qaysi oy(lar) uchun: o'quv yilining 12 oyi (to'lov oyi tanlangan);
//   - izoh.
// Maktabga boradigan matn shulardan yig'iladi va oldindan ko'rsatiladi
// (≤ 500 belgi); rasm alohida fayl bo'lib ketadi. Maktab tekshirib javob
// beradi (push `SCHOOL_VERIFICATION_ANSWERED`). Bitta eslatmada bitta ochiq
// so'rov — 409 bo'lsa xato varaq ichida.

import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/services/image_picker_service.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/payment_view_models.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/school_form_rules.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_form_fields.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

/// Chek skrinshoti o'qilishi uchun: eni 1600 px gacha, JPEG 85%.
const double _receiptMaxWidth = 1600;
const int _receiptQuality = 85;

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
  final _note = TextEditingController();
  PaymentMethod? _method;
  late final List<DateTime> _months = academicYearMonths(
    widget.reminder.nextDay ?? DateTime.now(),
  );
  late final Set<DateTime> _selected = {_dueMonth};
  Uint8List? _receipt;
  bool _picking = false;
  bool _sending = false;
  String? _error;

  DateTime get _dueMonth {
    final due = widget.reminder.nextDay ?? DateTime.now();
    return DateTime(due.year, due.month);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _monthName(DateTime m) => 'leaderboard.months.${m.month}'.tr();

  String get _message {
    final method = _method;
    return composeVerificationMessage(
      labels: (
        method: 'school.payments.composed.method'.tr(),
        months: 'school.payments.composed.months'.tr(),
      ),
      method: method?.labelKey.tr(),
      months: [
        for (final m in _months)
          if (_selected.contains(m)) '${_monthName(m)} ${m.year}',
      ],
      note: _note.text,
    );
  }

  /// Nima yetishmayapti (tugma o'chiq bo'lsa izoh); `null` — yuborish mumkin.
  String? get _missing {
    final method = _method;
    if (method == null) return 'school.payments.chooseMethod'.tr();
    if (method.isOnline && _receipt == null) {
      return 'school.payments.proofNeed'.tr();
    }
    return null;
  }

  bool get _canSubmit =>
      !_sending && _missing == null && canSubmitVerification(_message);

  void _pickMethod(PaymentMethod method) => setState(() {
    _method = _method == method ? null : method;
    _error = null;
  });

  Future<void> _pickReceipt() async {
    if (_picking || _sending) return;
    setState(() => _picking = true);
    try {
      final file = await ref
          .read(imagePickerServiceProvider)
          .pickImageFile(
            source: ImageSource.gallery,
            imageQuality: _receiptQuality,
            maxWidth: _receiptMaxWidth,
          );
      final bytes = await file?.readAsBytes();
      if (!mounted || bytes == null) return;
      if (bytes.length > kReceiptMaxBytes) {
        setState(() => _error = 'school.payments.proofTooBig'.tr());
        return;
      }
      setState(() {
        _receipt = bytes;
        _error = null;
      });
    } on Object {
      if (mounted) setState(() => _error = 'errors.generic'.tr());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final online = _method?.isOnline ?? false;
    final result = await ref
        .read(paymentActionsProvider.notifier)
        .requestVerification(
          paymentReminderId: widget.reminder.id,
          message: _message,
          receipt: online ? _receipt : null,
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
    final method = _method;
    final error = _error;
    final message = _message;
    final missing = _missing;
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
        SchoolFieldLabel('school.payments.method'.tr()),
        const SizedBox(height: 8),
        _MethodGroup(
          label: 'school.payments.methodOnline'.tr(),
          methods: [
            for (final m in PaymentMethod.values)
              if (m.isOnline) m,
          ],
          selected: method,
          enabled: !_sending,
          onPick: _pickMethod,
        ),
        const SizedBox(height: 10),
        _MethodGroup(
          label: 'school.payments.methodOffline'.tr(),
          methods: const [PaymentMethod.cash],
          selected: method,
          enabled: !_sending,
          onPick: _pickMethod,
        ),
        if (method != null && method.isOnline) ...[
          const SizedBox(height: 18),
          _ReceiptPicker(
            bytes: _receipt,
            busy: _picking,
            enabled: !_sending,
            onPick: _pickReceipt,
            onRemove: () => setState(() => _receipt = null),
          ),
        ],
        if (method == PaymentMethod.cash) ...[
          const SizedBox(height: 18),
          SchoolNote(
            icon: SolarIconsBold.wallet,
            text: 'school.payments.cashHint'.tr(),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: SchoolFieldLabel('school.payments.months'.tr())),
            Text(
              'school.payments.yearLabel'.tr(
                namedArgs: {
                  'from': '${_months.first.year}',
                  'to': '${_months.last.year}',
                },
              ),
              style: skText(12, c: SK.dim),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.15,
          children: [
            for (final m in _months)
              _MonthCell(
                label: _monthName(m),
                selected: _selected.contains(m),
                due: m == _dueMonth,
                onTap: _sending
                    ? null
                    : () => setState(() {
                        if (!_selected.remove(m)) _selected.add(m);
                      }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SchoolTextArea(
          label: 'school.payments.extra'.tr(),
          hint: method == PaymentMethod.cash
              ? 'school.payments.cashNoteHint'.tr()
              : 'school.payments.extraHint'.tr(),
          controller: _note,
          maxLength: 300,
          maxLines: 3,
          enabled: !_sending,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 16),
          SchoolFieldLabel('school.payments.preview'.tr()),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SK.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SK.blue.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: skText(13.5)),
                if (_receipt != null && (method?.isOnline ?? false)) ...[
                  const SizedBox(height: 8),
                  SkTag(
                    label: 'school.payments.hasReceipt'.tr(),
                    color: SK.green,
                    icon: SolarIconsBold.gallery,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          SchoolInlineError(message: error),
        ] else if (missing != null) ...[
          const SizedBox(height: 14),
          Text(
            missing,
            textAlign: TextAlign.center,
            style: skText(12.5, c: SK.dim),
          ),
        ],
        const SizedBox(height: 16),
        ParvozPrimaryButton(
          label: 'school.payments.verifySubmit'.tr(),
          onPressed: _submit,
          enabled: _canSubmit,
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

class _MethodGroup extends StatelessWidget {
  const _MethodGroup({
    required this.label,
    required this.methods,
    required this.selected,
    required this.enabled,
    required this.onPick,
  });

  final String label;
  final List<PaymentMethod> methods;
  final PaymentMethod? selected;
  final bool enabled;
  final ValueChanged<PaymentMethod> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: skText(
            11,
            c: SK.faint,
            w: FontWeight.w600,
          ).copyWith(letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in methods)
              SkChip(
                label: m.labelKey.tr(),
                icon: m.isOnline ? null : SolarIconsBold.wallet,
                selected: selected == m,
                onTap: enabled ? () => onPick(m) : () {},
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.due,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// To'lov sanasi oyi (nuqta bilan belgilanadi).
  final bool due;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? SK.blue : SK.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? SK.blue
                  : due
                  ? SK.sky.withValues(alpha: 0.6)
                  : SK.border,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 1,
                style: skText(
                  12.5,
                  w: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Onlayn to'lov chekining rasmi: tanlash, ko'rish, almashtirish.
class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.bytes,
    required this.busy,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final bool busy;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SK.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: bytes == null ? SK.sky.withValues(alpha: 0.45) : SK.green,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkIconBubble(
                icon: bytes == null
                    ? SolarIconsBold.gallerySend
                    : SolarIconsBold.galleryCheck,
                color: bytes == null ? SK.sky : SK.green,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bytes == null
                      ? 'school.payments.proofTitle'.tr()
                      : 'school.payments.proofAttached'.tr(),
                  style: skText(14.5, w: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'school.payments.proofHint'.tr(),
            style: skText(12.5, c: SK.dim, height: 1.45),
          ),
          const SizedBox(height: 12),
          if (bytes != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    width: 72,
                    height: 108,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    cacheWidth: 216,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SkChip(
                        label: 'school.payments.proofChange'.tr(),
                        icon: SolarIconsBold.refresh,
                        selected: false,
                        onTap: enabled ? onPick : () {},
                      ),
                      SkChip(
                        label: 'school.payments.proofRemove'.tr(),
                        icon: SolarIconsBold.trashBinMinimalistic,
                        selected: false,
                        onTap: enabled ? onRemove : () {},
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            ParvozSecondaryButton(
              label: 'school.payments.proofPick'.tr(),
              onPressed: enabled && !busy ? onPick : () {},
              leading: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      SolarIconsBold.gallery,
                      size: 20,
                      color: Colors.white,
                    ),
            ),
        ],
      ),
    );
  }
}
