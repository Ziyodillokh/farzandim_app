// ─────────────────────────────────────────────────────────────────────
// AttendanceCalendar — oylik davomat kalendari (Dushanbadan boshlanadi)
// ─────────────────────────────────────────────────────────────────────
//
// Belgilangan kun — holat rangida (keldi yashil, kechikdi sariq, kelmadi
// qizil, erta ketdi ko'k, sababli kulrang-ko'k; ranglar `SchoolStatusChip`
// bilan bir xil). Belgilanmagan o'tgan o'quv kuni — ingichka hoshiya,
// dam olish kuni — xira, bugun — ko'k halqa, kelajak — oddiy.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (lokal) ════════════
const _blue = Color(0xFF216BFF);
const _dim = Color(0x8CFFFFFF); // oq 55%
const _cellHeight = 40.0;
const _daysPerWeek = 7;

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.3);

class AttendanceCalendar extends StatelessWidget {
  const AttendanceCalendar({
    required this.attendance,
    required this.today,
    super.key,
  });

  final MonthAttendance attendance;

  /// Toshkent bugungi kuni, "YYYY-MM-DD".
  final String today;

  @override
  Widget build(BuildContext context) {
    final cells = attendanceCalendarCells(attendance, today: today);
    final rows = (cells.length / _daysPerWeek).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (var weekday = 1; weekday <= _daysPerWeek; weekday++)
              Expanded(
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      schoolWeekdayShort(weekday),
                      style: _pop(12, w: FontWeight.w500, c: _dim),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(top: row == 0 ? 0 : 6),
            child: Row(
              children: [
                for (var col = 0; col < _daysPerWeek; col++)
                  Expanded(
                    child: _DayCell(cell: _at(cells, row * _daysPerWeek + col)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static AttendanceCalendarCell? _at(
    List<AttendanceCalendarCell?> cells,
    int index,
  ) => index < cells.length ? cells[index] : null;
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.cell});

  final AttendanceCalendarCell? cell;

  /// Davomat belgisi bor holat (rangli katak).
  static bool _isMarked(SchoolDayStatus status) => switch (status) {
    SchoolDayStatus.present ||
    SchoolDayStatus.late ||
    SchoolDayStatus.absent ||
    SchoolDayStatus.leftEarly ||
    SchoolDayStatus.excused => true,
    SchoolDayStatus.pending ||
    SchoolDayStatus.holiday ||
    SchoolDayStatus.unknown => false,
  };

  @override
  Widget build(BuildContext context) {
    final cell = this.cell;
    if (cell == null) return const SizedBox(height: _cellHeight);
    final status = cell.status;
    final marked = !cell.isFuture && _isMarked(status);
    final pendingPast = !cell.isFuture && status == SchoolDayStatus.pending;
    final color = schoolStatusColor(status);
    final textColor = switch (status) {
      _ when marked => color,
      SchoolDayStatus.holiday => Colors.white.withValues(alpha: 0.3),
      _ when cell.isFuture => Colors.white.withValues(alpha: 0.6),
      _ => Colors.white.withValues(alpha: 0.85),
    };
    final Border? border;
    if (cell.isToday) {
      border = Border.all(color: _blue, width: 1.5);
    } else if (pendingPast) {
      border = Border.all(color: Colors.white.withValues(alpha: 0.14));
    } else {
      border = null;
    }
    return Semantics(
      label: cell.isFuture
          ? '${cell.day}'
          : '${cell.day}: ${status.labelKey.tr()}',
      excludeSemantics: true,
      child: Container(
        height: _cellHeight,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: marked ? color.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Text(
          '${cell.day}',
          style: _pop(
            13.5,
            w: marked || cell.isToday ? FontWeight.w600 : FontWeight.w400,
            c: textColor,
          ),
        ),
      ),
    );
  }
}
