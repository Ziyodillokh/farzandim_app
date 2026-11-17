// Maktab tabi «Bugun»: har bog'langan o'quvchining bugungi holati — keldi /
// kechikdi / kelmadi / erta ketdi (vaqti bilan), sinfi va maktabi. Karta
// bosilsa — o'sha o'quvchining davomat kalendari.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF);
const _dim = Color(0x99FFFFFF);

/// Holat rangi (yashil — keldi, sariq — kechikdi / erta ketdi, qizil —
/// kelmadi, ko'k — sababli, kulrang — hali yo'q / dam olish).
Color schoolDayColor(SchoolDayStatus status) => switch (status) {
  SchoolDayStatus.present => const Color(0xFF22C55E),
  SchoolDayStatus.late || SchoolDayStatus.leftEarly => const Color(0xFFF59E0B),
  SchoolDayStatus.absent => const Color(0xFFFF5A5D),
  SchoolDayStatus.excused => const Color(0xFF3C82FF),
  SchoolDayStatus.pending ||
  SchoolDayStatus.holiday ||
  SchoolDayStatus.unknown => const Color(0xFF8A94A6),
};

class SchoolTodayStudents extends StatelessWidget {
  const SchoolTodayStudents({
    required this.links,
    required this.onOpen,
    super.key,
  });

  final SchoolLinks links;
  final ValueChanged<LinkedStudent> onOpen;

  @override
  Widget build(BuildContext context) {
    final students = links.students;
    if (students.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final student in students) ...[
          _StudentTodayCard(
            student: student,
            schoolName: links.linkOfStudent(student.id)?.school.displayName,
            onTap: () => onOpen(student),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StudentTodayCard extends ConsumerWidget {
  const _StudentTodayCard({
    required this.student,
    required this.schoolName,
    required this.onTap,
  });

  final LinkedStudent student;
  final String? schoolName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider(student.id));
    final day = today.valueOrNull;
    final status = today.isLoading && day == null
        ? null
        : SchoolDayStatus.of(day);
    final color = status == null ? _dim : schoolDayColor(status);
    final inAt = day?.record?.inAt;
    final outAt = day?.record?.outAt;
    final name = student.fullName.trim();
    final initials = name.isEmpty
        ? '?'
        : name
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p.characters.first.toUpperCase())
              .join();
    final subtitle = [
      if (student.className.isNotEmpty)
        'home.school.className'.tr(namedArgs: {'name': student.className}),
      if (schoolName != null && schoolName!.isNotEmpty) schoolName!,
    ].join(' · ');
    return Semantics(
      button: true,
      label: [
        name,
        if (status != null) status.labelKey.tr(),
        if (inAt != null) inAt,
      ].join(', '),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: .12), _card],
                stops: const [0, .6],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3C82FF), Color(0xFF216BFF)],
                        ),
                      ),
                      child: Text(
                        initials,
                        style: GoogleFonts.unbounded(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.unbounded(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: _dim,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      SolarIconsOutline.altArrowRight,
                      size: 20,
                      color: _dim,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatusPill(
                      label: status == null
                          ? 'common.loading'.tr()
                          : status.labelKey.tr(),
                      color: color,
                    ),
                    const Spacer(),
                    if (inAt != null)
                      _Time(icon: SolarIconsBold.login, text: inAt),
                    if (outAt != null) ...[
                      const SizedBox(width: 12),
                      _Time(icon: SolarIconsBold.logout, text: outAt),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: .16),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _dim),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
