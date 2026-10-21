// Kunlik davomat belgisi (rangli nuqta + yorliq) va o'quvchining bugungi
// holati (belgi + kirish/chiqish vaqti). Dashboard kartasi, maktab sahifasi
// va davomat ekrani bir xil ko'rinishni ishlatadi. Erta ketish va to'lov
// so'rovlari holatlari ham shu palitrada (`SchoolPill`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Holat ranglari ════════════
const _green = Color(0xFF34C759);
const _amber = Color(0xFFFBBF24);
const _red = Color(0xFFFF5A5D);
const _blueSoft = Color(0xFF6FA0FF);
const _slate = Color(0xFFB4C2D6);
const _dim = Color(0x8CFFFFFF); // oq 55%

/// Holat rangi: keldi — yashil, kechikdi — sariq, kelmadi — qizil,
/// erta ketdi — ko'k, sababli — kulrang-ko'k, qolganlari — xira oq.
Color schoolStatusColor(SchoolDayStatus status) => switch (status) {
  SchoolDayStatus.present => _green,
  SchoolDayStatus.late => _amber,
  SchoolDayStatus.absent => _red,
  SchoolDayStatus.leftEarly => _blueSoft,
  SchoolDayStatus.excused => _slate,
  SchoolDayStatus.pending ||
  SchoolDayStatus.holiday ||
  SchoolDayStatus.unknown => _dim,
};

/// Erta ketish so'rovi: kutilmoqda — sariq, tasdiqlandi — yashil,
/// rad etildi — qizil.
Color earlyExitStatusColor(EarlyExitStatus status) => switch (status) {
  EarlyExitStatus.pending => _amber,
  EarlyExitStatus.approved => _green,
  EarlyExitStatus.rejected => _red,
  EarlyExitStatus.unknown => _dim,
};

/// To'lov tekshiruvi: ko'rib chiqilmoqda — sariq, javob berildi — yashil,
/// yopilgan — xira.
Color verificationStatusColor(VerificationStatus status) => switch (status) {
  VerificationStatus.open => _amber,
  VerificationStatus.answered => _green,
  VerificationStatus.closed || VerificationStatus.unknown => _dim,
};

/// Rangli nuqta + yorliq ("Keldi", "Kelmadi", ...); [count] berilsa
/// yorliqdan keyin son ("Keldi 12" — oy jami uchun).
class SchoolStatusChip extends StatelessWidget {
  const SchoolStatusChip({required this.status, this.count, super.key});

  final SchoolDayStatus status;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final label = status.labelKey.tr();
    final count = this.count;
    return SchoolPill(
      label: count == null ? label : '$label $count',
      color: schoolStatusColor(status),
    );
  }
}

/// Holat belgilarining umumiy ko'rinishi: rangli nuqta + yorliq pill
/// (davomat, erta ketish va to'lov so'rovlari).
class SchoolPill extends StatelessWidget {
  const SchoolPill({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            // Tor joyda (kichik ekran, uzun yorliq) qisqaradi — toshmaydi.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O'quvchining bugungi holati: belgi + "Kirish 08:05 · Chiqish 13:30".
/// Yuklanayotganda, xatoda yoki ma'lumot yo'q bo'lsa hech narsa
/// ko'rsatilmaydi (karta balandligi sakramasin deb joy ham olmaydi).
class SchoolTodayStatus extends ConsumerWidget {
  const SchoolTodayStatus({required this.studentId, super.key});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider(studentId));
    if (!today.hasValue) return const SizedBox.shrink();
    final day = today.valueOrNull;
    final status = SchoolDayStatus.of(day);
    if (status == SchoolDayStatus.unknown) return const SizedBox.shrink();
    final record = day?.record;
    final times = [
      if (record?.inAt case final inAt?)
        'school.attendance.inAt'.tr(namedArgs: {'time': inAt}),
      if (record?.outAt case final outAt?)
        'school.attendance.outAt'.tr(namedArgs: {'time': outAt}),
    ].join(' · ');
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SchoolStatusChip(status: status),
        if (times.isNotEmpty)
          Text(
            times,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: _dim,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}
