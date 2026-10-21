// ─────────────────────────────────────────────────────────────────────
// EarlyExitSheet — erta ketish so'rovi (faqat BUGUN uchun)
// ─────────────────────────────────────────────────────────────────────
//
// O'quvchi (bog'langan o'quvchilardan; bitta bo'lsa — o'zi), ketish vaqti
// (24 soat, Toshkent bo'yicha keyingi chorak soat taklif qilinadi), sabab
// (≤ 160) va kim olib ketishi (≤ 80). Sanani server qo'yadi. Xato varaq
// ichida: 409 — "bugun uchun so'rov ko'rib chiqilmoqda".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_early_exit_providers.dart';
import 'package:farzandim/features/school/presentation/school_form_rules.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_form_fields.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Varaqni ochadi; [links] dagi o'quvchilardan tanlanadi ([initialStudentId]
/// oldindan belgilanadi). `true` — so'rov yuborildi.
Future<bool> showEarlyExitSheet(
  BuildContext context, {
  required SchoolLinks links,
  String? initialStudentId,
}) async {
  if (links.students.isEmpty) return false;
  final sent = await showSchoolSheet<bool>(
    context,
    builder: (_) =>
        _EarlyExitSheet(links: links, initialStudentId: initialStudentId),
  );
  return sent ?? false;
}

class _EarlyExitSheet extends ConsumerStatefulWidget {
  const _EarlyExitSheet({required this.links, this.initialStudentId});

  final SchoolLinks links;
  final String? initialStudentId;

  @override
  ConsumerState<_EarlyExitSheet> createState() => _EarlyExitSheetState();
}

class _EarlyExitSheetState extends ConsumerState<_EarlyExitSheet> {
  final _reason = TextEditingController();
  final _pickup = TextEditingController();
  late String? _studentId = _initialStudent();
  TimeOfDay? _time;
  bool _sending = false;
  String? _error;

  List<LinkedStudent> get _students => widget.links.students;

  /// Bitta o'quvchi — o'zi; berilgani ro'yxatda bo'lsa — u; aks holda
  /// tanlanmagan (adashib boshqa farzandga yuborilmasin).
  String? _initialStudent() {
    if (_students.length == 1) return _students.single.id;
    final initial = widget.initialStudentId;
    return _students.any((s) => s.id == initial) ? initial : null;
  }

  String? get _hhmm {
    final time = _time;
    return time == null ? null : formatHhMm(time.hour, time.minute);
  }

  bool get _canSubmit => canSubmitEarlyExit(
    studentId: _studentId,
    time: _hhmm,
    reason: _reason.text,
    pickupBy: _pickup.text,
  );

  @override
  void dispose() {
    _reason.dispose();
    _pickup.dispose();
    super.dispose();
  }

  /// Kiritish o'zgarganda tugma holati qayta hisoblanadi, eski xato yo'qoladi.
  void _onEdited(String _) => setState(() => _error = null);

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final suggested = suggestedEarlyExitTime(tashkentNow());
    final picked = await showSchoolTimePicker(
      context,
      initial:
          _time ?? TimeOfDay(hour: suggested.hour, minute: suggested.minute),
      helpText: 'school.earlyExit.time'.tr(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final studentId = _studentId;
    final time = _hhmm;
    if (_sending || !_canSubmit || studentId == null || time == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(earlyExitActionsProvider.notifier)
        .request(
          studentId: studentId,
          time: time,
          reason: _reason.text,
          pickupBy: _pickup.text,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.success(context, 'school.earlyExit.sent'.tr());
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = result.error ?? 'errors.generic'.tr();
    });
  }

  /// "7-A sinf · 12-maktab" (maktab bir nechta bo'lsa ham aniq bo'lsin).
  String _studentDetails(LinkedStudent student) {
    final school = widget.links.linkOfStudent(student.id)?.school;
    return [
      if (student.className.isNotEmpty)
        'school.classLabel'.tr(namedArgs: {'name': student.className}),
      if (school != null && school.displayName.isNotEmpty) school.displayName,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final single = _students.length == 1;
    return SchoolSheetFrame(
      title: 'school.earlyExit.sheetTitle'.tr(),
      subtitle: 'school.earlyExit.sheetSubtitle'.tr(),
      children: [
        SchoolNote(
          icon: SolarIconsBold.calendarMark,
          text: 'school.earlyExit.todayOnly'.tr(),
        ),
        const SizedBox(height: 18),
        SchoolFieldLabel('school.earlyExit.student'.tr()),
        const SizedBox(height: 8),
        for (final (i, student) in _students.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          SchoolChoiceTile(
            icon: SolarIconsBold.backpack,
            title: student.fullName,
            subtitle: _studentDetails(student),
            selected: _studentId == student.id,
            onTap: single || _sending
                ? null
                : () => setState(() {
                    _studentId = student.id;
                    _error = null;
                  }),
          ),
        ],
        const SizedBox(height: 18),
        SchoolPickerField(
          label: 'school.earlyExit.time'.tr(),
          icon: SolarIconsOutline.clockCircle,
          placeholder: 'school.earlyExit.timeHint'.tr(),
          value: _hhmm,
          onTap: _sending ? null : _pickTime,
        ),
        const SizedBox(height: 18),
        SchoolTextArea(
          label: 'school.earlyExit.reason'.tr(),
          hint: 'school.earlyExit.reasonHint'.tr(),
          controller: _reason,
          maxLength: kEarlyExitReasonMax,
          maxLines: 3,
          enabled: !_sending,
          onChanged: _onEdited,
        ),
        const SizedBox(height: 18),
        SchoolTextArea(
          label: 'school.earlyExit.pickupBy'.tr(),
          hint: 'school.earlyExit.pickupHint'.tr(),
          controller: _pickup,
          maxLength: kEarlyExitPickupMax,
          enabled: !_sending,
          onChanged: _onEdited,
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          SchoolInlineError(message: error),
        ],
        const SizedBox(height: 22),
        ParvozPrimaryButton(
          label: 'school.earlyExit.submit'.tr(),
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
