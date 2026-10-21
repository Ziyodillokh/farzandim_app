// Davomat QR natijasi: keldi (vaqt + kechikish belgisi), ketdi (vaqt),
// allaqachon belgilangan — yoki tushunarli xato va "Qayta skanerlash".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/attendance_display.dart';
import 'package:farzandim_child/features/school/presentation/widgets/attendance_widgets.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_result_page.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Muvaffaqiyatli skanerlash natijasi.
class CheckInResultView extends StatelessWidget {
  const CheckInResultView({
    super.key,
    required this.result,
    required this.onDone,
  });

  final CheckInResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final action = result.action;
    final today = result.today;
    final record = today?.record;
    final (icon, color, titleKey) = switch (action) {
      CheckInAction.arrived => (
        Icons.check_rounded,
        HomeColors.green,
        'school.checkIn.arrivedTitle',
      ),
      CheckInAction.departed => (
        Icons.waving_hand_rounded,
        HomeColors.blue,
        'school.checkIn.departedTitle',
      ),
      CheckInAction.none => (
        Icons.event_available_rounded,
        HomeColors.blue,
        'school.checkIn.alreadyTitle',
      ),
      CheckInAction.unknown => (
        Icons.check_rounded,
        HomeColors.blue,
        'school.checkIn.recordedTitle',
      ),
    };
    return SchoolResultPage(
      key: ValueKey('check-in-${action.name}'),
      icon: icon,
      color: color,
      title: titleKey.tr(),
      actions: [SetupButton(label: 'school.checkIn.done'.tr(), onTap: onDone)],
      children: [
        if (action == CheckInAction.arrived &&
            record?.status == AttendanceStatus.late) ...[
          const SizedBox(height: 12),
          const _LateBadge(),
        ],
        ...switch (action) {
          CheckInAction.arrived => [
            const SizedBox(height: 18),
            _TimeBlock(labelKey: 'school.today.arrived', time: record?.inAt),
          ],
          CheckInAction.departed => [
            const SizedBox(height: 18),
            _TimeBlock(labelKey: 'school.today.left', time: record?.outAt),
          ],
          _ when today != null => [
            const SizedBox(height: 16),
            AttendanceStatusChip(kind: attendanceChipOf(today), maxWidth: 220),
            const SizedBox(height: 14),
            AttendanceTimes(record: record),
          ],
          _ => const <Widget>[],
        },
        for (final key in _notesOf(result)) ...[
          const SizedBox(height: 12),
          Text(
            key.tr(),
            textAlign: TextAlign.center,
            style: homeText(14, color: HomeColors.textDim, height: 1.45),
          ),
        ],
      ],
    );
  }

  /// Natija ostidagi izohlar (tarjima kalitlari).
  static List<String> _notesOf(CheckInResult result) {
    final record = result.today?.record;
    return switch (result.action) {
      CheckInAction.arrived => [
        if (record?.status == AttendanceStatus.late) 'school.checkIn.lateHint',
        'school.checkIn.parentsNotified',
      ],
      CheckInAction.departed => [
        'school.checkIn.departedBody',
        'school.checkIn.parentsNotified',
      ],
      CheckInAction.none || CheckInAction.unknown => [
        if (record?.inAt != null && record?.outAt == null)
          'school.checkIn.exitLater'
        else if (isStaffDecision(record))
          'school.today.hints.staffMarked',
      ],
    };
  }
}

/// Server rad etdi / tarmoq yo'q — xabar, "Qayta skanerlash" va "Yopish".
class CheckInFailureView extends StatelessWidget {
  const CheckInFailureView({
    super.key,
    required this.code,
    required this.onScanAgain,
    required this.onClose,
  });

  final SchoolErrorCode code;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final icon = switch (code) {
      SchoolErrorCode.network => Icons.wifi_off_rounded,
      SchoolErrorCode.outsideHours => Icons.schedule_rounded,
      SchoolErrorCode.notEnrolled => Icons.person_search_rounded,
      SchoolErrorCode.kioskInvalid ||
      SchoolErrorCode.kioskExpired => Icons.qr_code_2_rounded,
      _ => Icons.error_outline_rounded,
    };
    return SchoolResultPage(
      key: ValueKey('check-in-failed-${code.name}'),
      icon: icon,
      color: HomeColors.orange,
      title: 'school.checkIn.failedTitle'.tr(),
      actions: [
        SetupButton(label: 'school.checkIn.scanAgain'.tr(), onTap: onScanAgain),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onClose,
          child: Text(
            'common.close'.tr(),
            style: homeText(
              15,
              weight: FontWeight.w600,
              color: HomeColors.textDim,
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: 12),
        Text(
          code.messageKey.tr(),
          textAlign: TextAlign.center,
          style: homeText(15, color: HomeColors.textDim, height: 1.45),
        ),
      ],
    );
  }
}

class _LateBadge extends StatelessWidget {
  const _LateBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: HomeColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomeColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SolarIconsBold.clockCircle,
            size: 16,
            color: HomeColors.amber,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'school.checkIn.lateBadge'.tr(),
              style: homeText(
                13,
                weight: FontWeight.w700,
                color: HomeColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Katta vaqt ("08:12") va uning nomi.
class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.labelKey, required this.time});

  final String labelKey;
  final String? time;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labelKey.tr(),
          style: homeText(13, color: HomeColors.textDim, height: 1.2),
        ),
        const SizedBox(height: 4),
        Text(time ?? kNoAttendanceTime, style: homeDisplay(40, height: 1.1)),
      ],
    );
  }
}
