// ─────────────────────────────────────────────────────────────────────
// SchoolDashboardCard — dashboard'dagi maktab kartasi (joylashuvdan keyin)
// ─────────────────────────────────────────────────────────────────────
//
//   - maktab ro'yxati yuklanmagan / xato / bo'lim mavjud emas → ko'rinmaydi;
//   - bog'lanish yo'q → "Maktab taklif kodi bormi?" (taklif kodi sahifasi);
//   - shu farzandga moslangan o'quvchi → maktab, bugungi holat,
//     kirish/chiqish vaqti va o'qilmagan e'lonlar (bosilsa — maktab);
//   - moslanmagan o'quvchilar bor → "Bog'lash" (moslash varag'i);
//   - aks holda → ko'rinmaydi.
// Uslub dashboard `_Card` bilan bir xil: oq 7% fon, oq 10% chegara, r24.
// Karta ko'rinsagina tepasida 4px oraliq bo'ladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/student_child_match_sheet.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── Dashboard tokenlari (dashboard_screen.dart bilan bir xil) ───
const Color _blue = Color(0xFF216BFF);
const Color _cardBg = Color(0x12FFFFFF); // oq ~7%
const Color _cardBorder = Color(0x1AFFFFFF); // oq ~10%
const Color _dim = Color(0x8CFFFFFF); // oq 55%
const double _radius = 24;

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.5,
  height: 1.4,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Dashboard maktab kartasi ([childId] — tanlangan farzand).
class SchoolDashboardCard extends ConsumerWidget {
  const SchoolDashboardCard({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(schoolLinksProvider).valueOrNull;
    final Widget card;
    switch (SchoolCardMode.of(links, childId)) {
      case SchoolCardHidden():
        return const SizedBox.shrink();
      case SchoolCardInvite():
        card = _CardShell(
          onTap: () => context.push(AppRoutes.schoolLink),
          child: const _InviteContent(),
        );
      case SchoolCardStudent(:final student, :final school):
        card = _CardShell(
          onTap: () => context.push(AppRoutes.school),
          child: _StudentContent(student: student, school: school),
        );
      case SchoolCardMatch(links: final current, :final students):
        card = _CardShell(
          onTap: () => _openMatch(context, ref, current, students),
          child: _MatchContent(count: students.length),
        );
    }
    return Padding(padding: const EdgeInsets.only(top: 4), child: card);
  }

  static Future<void> _openMatch(
    BuildContext context,
    WidgetRef ref,
    SchoolLinks links,
    List<LinkedStudent> students,
  ) async {
    final addChild = await showStudentChildMatchSheet(
      context,
      links: links,
      studentIds: [for (final student in students) student.id],
    );
    if (addChild && context.mounted) guardAddChild(context, ref);
  }
}

/// Dashboard `_Card` nusxasi: flat shisha + ripple.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(_radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: br,
        border: Border.all(color: _cardBorder),
      ),
      child: ClipRRect(
        borderRadius: br,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bog'lanish yo'q — taklif kodi CTA.
class _InviteContent extends StatelessWidget {
  const _InviteContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(SolarIconsBold.squareAcademicCap, size: 26, color: _dim),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'dashboard.school.inviteTitle'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _unb(16),
              ),
              Text(
                'dashboard.school.inviteSubtitle'.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _pop(14, c: _dim),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const _Chevron(),
      ],
    );
  }
}

/// Moslangan o'quvchi: maktab, sinf, bugungi holat, o'qilmagan e'lonlar.
class _StudentContent extends ConsumerWidget {
  const _StudentContent({required this.student, required this.school});

  final LinkedStudent student;
  final SchoolInfo? school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(schoolUnreadCountProvider).valueOrNull ?? 0;
    final name = school?.displayName ?? '';
    return Row(
      children: [
        SchoolLogo(school: school, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'school.title'.tr() : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _unb(16),
              ),
              if (student.className.isNotEmpty)
                Text(
                  'school.classLabel'.tr(
                    namedArgs: {'name': student.className},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(13, c: _dim),
                ),
              const SizedBox(height: 4),
              SchoolTodayStatus(studentId: student.id),
            ],
          ),
        ),
        if (unread > 0) ...[
          const SizedBox(width: 8),
          _UnreadBadge(
            count: unread,
            onTap: () => context.push(AppRoutes.schoolAnnouncements),
          ),
        ],
        const SizedBox(width: 8),
        const _Chevron(),
      ],
    );
  }
}

/// O'qilmagan e'lonlar — ko'k pill (konvert + son; to'liq matn ekran
/// o'quvchi uchun); bosilsa e'lonlar sahifasi. Ixcham — tor ekranda bugungi
/// holatga joy qolsin; bosish maydoni esa kamida 48x48 (karta bosilishi
/// bilan adashmasin).
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  /// Bosish maydonining eng kichik o'lchami (Material / HIG).
  static const double _minTapTarget = 48;

  @override
  Widget build(BuildContext context) {
    final shown = count > 99 ? '99+' : '$count';
    final label = 'dashboard.school.unread'.tr(namedArgs: {'count': shown});
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    SolarIconsBold.letterUnread,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(shown, style: _pop(12, w: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Moslanmagan o'quvchilar — "Bog'lash" taklifi.
class _MatchContent extends StatelessWidget {
  const _MatchContent({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(SolarIconsBold.userCheckRounded, size: 26, color: _dim),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'dashboard.school.matchTitle'.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _unb(16),
              ),
              Text(
                'dashboard.school.matchSubtitle'.tr(
                  namedArgs: {'count': '$count'},
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pop(14, c: _dim),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'dashboard.school.matchCta'.tr(),
            style: _pop(13, w: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Icon(
      SolarIconsBold.altArrowRight,
      size: 22,
      color: Colors.white.withValues(alpha: 0.5),
    );
  }
}
