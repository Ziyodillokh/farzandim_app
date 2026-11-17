// ─────────────────────────────────────────────────────────────────────
// SchoolSectionTiles — Maktab sahifasidagi «Bo'limlar» (P02)
// ─────────────────────────────────────────────────────────────────────
//
// 2×2 plita, har biri o'z holati bilan:
//   - E'lonlar — o'qilmaganlar soni;
//   - To'lovlar — to'lov kuni kelgan/o'tganlar (qizil holat), tekshiruv
//     yoki keyingi to'lovgacha kunlar;
//   - Davomat — "Bugun: 2 / 2 keldi";
//   - Bog'lanish — sinf rahbari va maktab (yangi javoblar soni).
// Ma'lumot kelmasa (yuklanmoqda / xato) — neytral izoh, plita baribir
// bosiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';
import 'package:farzandim/features/school/presentation/payment_view_models.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _tileBg = Color(0xFF11151D);
const _tileBorder = Color(0x14FFFFFF); // oq 8%
const _alertBorder = Color(0x52F87171);
const _muted = Color(0xFF8A93A6);
const _alertText = Color(0xFFFDA4AF);
const _alertDot = Color(0xFFF43F5E);
const _countBlue = Color(0xFF2F6BFF);
const double _tileMinHeight = 124;

/// Plita rangi: asos (fon va chegara) va ikon rangi.
enum _Hue {
  blue(Color(0xFF4F86FF), Color(0xFFA0C0FF)),
  rose(Color(0xFFF43F5E), Color(0xFFFFA0B4)),
  green(Color(0xFF10B981), Color(0xFF80E4BA)),
  // Kanvasda binafsha — loyihada binafsha ishlatilmaydi, shuning uchun amber.
  amber(Color(0xFFF59E0B), Color(0xFFFFD480));

  const _Hue(this.base, this.icon);

  final Color base;
  final Color icon;
}

class SchoolSectionTiles extends StatelessWidget {
  const SchoolSectionTiles({
    required this.students,
    required this.onAttendance,
    super.key,
  });

  final List<LinkedStudent> students;
  final VoidCallback onAttendance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TileRow(left: _AnnouncementsTile(), right: _PaymentsTile()),
        const SizedBox(height: 10),
        _TileRow(
          left: _AttendanceTile(students: students, onTap: onAttendance),
          right: const _ContactTile(),
        ),
      ],
    );
  }
}

/// Ikki plita bir xil balandlikda (katta shriftda ham toshmaydi).
class _TileRow extends StatelessWidget {
  const _TileRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _AnnouncementsTile extends ConsumerWidget {
  const _AnnouncementsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(schoolUnreadCountProvider).valueOrNull ?? 0;
    final title = 'school.announcements.title'.tr();
    final subtitle = unread > 0
        ? 'school.home.tiles.announcementsNew'.tr(
            namedArgs: {'count': '$unread'},
          )
        : 'school.home.tiles.announcementsNone'.tr();
    return _Tile(
      icon: SolarIconsBold.letterUnread,
      hue: _Hue.blue,
      title: title,
      subtitle: subtitle,
      semanticsLabel: '$title, $subtitle',
      count: unread,
      onTap: () => context.push(AppRoutes.schoolAnnouncements),
    );
  }
}

class _PaymentsTile extends ConsumerWidget {
  const _PaymentsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(schoolPaymentsProvider).valueOrNull;
    final summary = reminders == null
        ? null
        : paymentsSummaryOf(reminders, DateTime.now());
    final due = summary?.due ?? 0;
    final title = 'school.payments.title'.tr();
    final subtitle = switch (summary) {
      null => 'school.home.tiles.paymentsHint'.tr(),
      PaymentsSummary(due: > 0) => 'school.home.tiles.paymentsDue'.tr(),
      PaymentsSummary(checking: > 0) =>
        'school.home.tiles.paymentsChecking'.tr(),
      PaymentsSummary(:final nextInDays?) =>
        'school.home.tiles.paymentsNext'.tr(namedArgs: {'days': '$nextInDays'}),
      _ => 'school.home.tiles.paymentsNone'.tr(),
    };
    return _Tile(
      icon: SolarIconsBold.billList,
      hue: _Hue.rose,
      title: title,
      subtitle: subtitle,
      semanticsLabel: due > 0
          ? 'school.home.tiles.paymentsDueA11y'.tr(namedArgs: {'count': '$due'})
          : '$title, $subtitle',
      count: due,
      alert: due > 0,
      onTap: () => context.push(AppRoutes.schoolPayments),
    );
  }
}

class _AttendanceTile extends ConsumerWidget {
  const _AttendanceTile({required this.students, required this.onTap});

  final List<LinkedStudent> students;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = todayAttendanceCount([
      for (final student in students)
        ref.watch(todayAttendanceProvider(student.id)).valueOrNull,
    ]);
    final title = 'school.attendance.title'.tr();
    final args = {'came': '${count.came}', 'total': '${count.total}'};
    final (subtitle, label) = switch (count) {
      _ when students.isEmpty || !count.known => (
        'school.home.tiles.attendanceHint'.tr(),
        null,
      ),
      (total: 0, came: _, known: _) => (
        'school.home.tiles.attendanceNoLessons'.tr(),
        null,
      ),
      _ => (
        'school.home.tiles.attendanceToday'.tr(namedArgs: args),
        'school.home.tiles.attendanceA11y'.tr(namedArgs: args),
      ),
    };
    return _Tile(
      icon: SolarIconsBold.calendarMark,
      hue: _Hue.green,
      title: title,
      subtitle: subtitle,
      semanticsLabel: label ?? '$title, $subtitle',
      onTap: onTap,
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(schoolThreadsUnreadProvider);
    final title = 'school.home.tiles.contact'.tr();
    final subtitle = unread > 0
        ? 'school.connect.newReplies'.tr(namedArgs: {'count': '$unread'})
        : 'school.home.tiles.contactBody'.tr();
    return _Tile(
      icon: SolarIconsBold.chatRoundDots,
      hue: _Hue.amber,
      title: title,
      subtitle: subtitle,
      semanticsLabel: '$title, $subtitle',
      count: unread,
      onTap: () => context.push(AppRoutes.schoolContacts),
    );
  }
}

/// Bitta plita: rangli ikon, soni (ixtiyoriy), nom va holat izohi.
/// [alert] — qizil chegara, burchakda nur va qizil son (to'lanmagan).
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.hue,
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.onTap,
    this.count = 0,
    this.alert = false,
  });

  final IconData icon;
  final _Hue hue;
  final String title;
  final String subtitle;
  final String semanticsLabel;
  final VoidCallback onTap;
  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: _tileMinHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: alert ? _alertBorder : _tileBorder),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(const Color(0x09FFFFFF), _tileBg),
                _tileBg,
              ],
            ),
          ),
          child: Stack(
            children: [
              if (alert)
                const Positioned(
                  right: -60,
                  top: -60,
                  child: _Glow(color: Color(0xFFEF4444)),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconChip(icon: icon, hue: hue),
                        const Spacer(),
                        if (count > 0) _Count(count: count, alert: alert),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: skText(16, w: FontWeight.w700, height: 1.3),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (alert) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _alertDot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: skText(
                                  12.5,
                                  w: FontWeight.w500,
                                  c: alert ? _alertText : _muted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.hue});

  final IconData icon;
  final _Hue hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: hue.base.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: hue.base.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: 21, color: hue.icon),
    );
  }
}

/// Burchakdagi son: oddiy — ko'k; [alert] — qizil gradient va halqa.
class _Count extends StatelessWidget {
  const _Count({required this.count, required this.alert});

  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: alert ? null : _countBlue,
        gradient: alert
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF5A6E), Color(0xFFE11D48)],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: alert ? Border.all(color: _tileBg, width: 2) : null,
        boxShadow: alert
            ? const [
                BoxShadow(
                  color: Color(0x8CE11D48),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: skText(12.5, w: FontWeight.w700, height: 1),
      ),
    );
    if (!alert) return badge;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -5,
          right: -5,
          top: -5,
          bottom: -5,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0x2EEF4444),
              shape: BoxShape.circle,
            ),
          ),
        ),
        badge,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
            stops: const [0, 0.7],
          ),
        ),
      ),
    );
  }
}
