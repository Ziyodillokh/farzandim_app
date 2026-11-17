// ─────────────────────────────────────────────────────────────────────
// attendance_summary — davomat kunlar ro'yxati qatori
// ─────────────────────────────────────────────────────────────────────
//
// Hafta kuni va sana, holat belgisi (kalendar ranglari bilan bir xil),
// kirish / chiqish vaqti. Oy jami — `attendance_month.dart`.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (lokal) ════════════
const _rowBg = Color(0x0AFFFFFF); // oq 4%
const _rowBorder = Color(0x14FFFFFF); // oq 8%
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.45);

/// Kunlar ro'yxati qatori: hafta kuni va sana, holat, kirish/chiqish.
class AttendanceDayRow extends StatelessWidget {
  const AttendanceDayRow({required this.day, required this.today, super.key});

  final AttendanceDay day;

  /// Toshkent bugungi kuni, "YYYY-MM-DD".
  final String today;

  /// "Bugun" yoki hafta kuni ("Du").
  String _dayLabel({required bool isToday}) {
    if (isToday) return 'school.attendance.today'.tr();
    final weekday = day.day?.weekday;
    return weekday == null ? '' : schoolWeekdayShort(weekday);
  }

  @override
  Widget build(BuildContext context) {
    final record = day.record;
    final times = [
      if (record?.inAt case final inAt?)
        'school.attendance.inAt'.tr(namedArgs: {'time': inAt}),
      if (record?.outAt case final outAt?)
        'school.attendance.outAt'.tr(namedArgs: {'time': outAt}),
    ].join(' · ');
    final isToday = day.date == today;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _rowBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isToday ? _blue : _rowBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayLabel(isToday: isToday),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(12, c: isToday ? _blue : _dim),
                ),
                Text(
                  formatSchoolDayShort(day.date),
                  style: _pop(15, w: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SchoolStatusChip(status: SchoolDayStatus.of(day)),
                if (times.isNotEmpty) Text(times, style: _pop(12.5, c: _dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
