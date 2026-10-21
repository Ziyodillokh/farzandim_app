// ─────────────────────────────────────────────────────────────────────
// attendance_summary — oy jami (kelish foizi + holatlar) va kun qatori
// ─────────────────────────────────────────────────────────────────────
//
// Kelish foizi = (keldi + kechikdi + erta ketdi) / belgilangan o'quv
// kunlari (backend hisoblaydi). Belgilangan kun yo'q bo'lsa foiz o'rniga
// "—" (0% chalg'itadi). Holat belgilari kalendar ranglari bilan bir xil.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _rowBg = Color(0x0AFFFFFF); // oq 4%
const _rowBorder = Color(0x14FFFFFF); // oq 8%
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

/// Foiz chizig'i uchun maksimal qiymat.
const double _fullRate = 100;

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

/// Oy jami kartasi: kelish foizi, chiziq va holatlar soni.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    required this.summary,
    required this.rate,
    super.key,
  });

  final AttendanceSummary summary;

  /// Kelish foizi, 0–100.
  final int rate;

  @override
  Widget build(BuildContext context) {
    final entries = attendanceSummaryEntries(summary);
    final showRate = hasAttendanceRate(summary);
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
          Text('school.attendance.rate'.tr(), style: _pop(13, c: _dim)),
          const SizedBox(height: 2),
          Text(showRate ? '$rate%' : '—', style: _unb(30)),
          if (showRate) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: rate / _fullRate,
              minHeight: 6,
              color: _blue,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
              semanticsLabel: 'school.attendance.rate'.tr(),
              semanticsValue: '$rate%',
            ),
          ],
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('school.attendance.noMarks'.tr(), style: _pop(13.5, c: _dim))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in entries)
                  SchoolStatusChip(status: entry.status, count: entry.count),
              ],
            ),
        ],
      ),
    );
  }
}

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
