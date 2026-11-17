// Bildirishnomalar tepasida qadalgan qizil karta: xususiy maktab to'lov sanasi
// kelgan (yoki o'tgan) va hali tasdiqlanmagan eslatmalar. Surib yopilmaydi —
// maktab to'lovni tasdiqlab keyingi sanani surganda o'zi yo'qoladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _red = Color(0xFFE5484D);
const _redBg = Color(0x29E5484D);

/// To'lov sanasi kelgan yoki o'tgan, to'xtatilmagan eslatmalar
/// (eng eskisi birinchi).
List<SchoolPaymentReminder> unpaidPayments(
  List<SchoolPaymentReminder> all,
  String today,
) {
  final due =
      all
          .where((r) => !r.paused && r.nextDate.isNotEmpty)
          .where((r) => r.nextDate.compareTo(today) <= 0)
          .toList()
        ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  return List.unmodifiable(due);
}

/// Qadalgan kartalar uchun ro'yxat (xato yoki maktab yo'q — bo'sh).
final unpaidSchoolPaymentsProvider =
    Provider.autoDispose<List<SchoolPaymentReminder>>((ref) {
      final all = ref.watch(schoolPaymentsProvider).valueOrNull ?? const [];
      return unpaidPayments(all, tashkentTodayStr());
    });

/// "YYYY-MM-DD" → "DD.MM.YYYY".
String _displayDate(String day) {
  final parts = day.split('-');
  return parts.length == 3 ? '${parts[2]}.${parts[1]}.${parts[0]}' : day;
}

/// Bildirishnomalar ro'yxati tepasidagi qadalgan to'lov kartalari.
class SchoolPaymentPin extends ConsumerWidget {
  const SchoolPaymentPin({
    super.key,
    this.padding = EdgeInsets.zero,
    this.onOpen,
  });

  final EdgeInsetsGeometry padding;

  /// Bosilganda (masalan, oynani yopib keyin o'tish);
  /// berilmasa — to'lovlar sahifasi.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(unpaidSchoolPaymentsProvider);
    if (due.isEmpty) return const SizedBox.shrink();
    final today = tashkentTodayStr();
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (final r in due)
            _PinCard(
              reminder: r,
              overdue: r.nextDate.compareTo(today) < 0,
              onTap:
                  onOpen ?? () => context.push(AppRoutes.schoolPaymentsPath()),
            ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.reminder,
    required this.overdue,
    required this.onTap,
  });

  final SchoolPaymentReminder reminder;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = reminder.children.map((c) => c.name).join(', ');
    final title = overdue
        ? 'school.payments.pin.overdue'.tr()
        : 'school.payments.pin.title'.tr();
    final body = 'school.payments.pin.body'.tr(
      namedArgs: {
        'school': reminder.schoolName,
        'children': names,
        'date': _displayDate(reminder.nextDate),
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: '$title. $body',
        child: Material(
          color: _redBg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _red, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.push_pin_rounded, color: _red, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: const Color(0xD9FFFFFF),
                            height: 1.4,
                          ),
                        ),
                        if (reminder.openVerification) ...[
                          const SizedBox(height: 4),
                          Text(
                            'school.payments.pin.checking'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFFFFB4B4),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'school.payments.pin.open'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
