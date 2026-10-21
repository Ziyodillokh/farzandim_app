// ─────────────────────────────────────────────────────────────────────
// SchoolLinkCard — maktab sahifasidagi bitta maktab (vasiy yozuvi)
// ─────────────────────────────────────────────────────────────────────
//
// Logo + nom + shahar, o'quvchilar (bugungi holat, farzandga moslash) va
// "Aloqani uzish". O'quvchi qatori bosilsa — uning davomati; moslash
// tugmasi — moslash varag'i (oilaning boshqa a'zosi moslagan o'quvchida
// tugma yo'q, faqat izoh).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _rowBg = Color(0x0AFFFFFF); // oq 4%
const _rowBorder = Color(0x14FFFFFF); // oq 8%
const _chipBg = Color(0xFF1B2128);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.4,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

class SchoolLinkCard extends StatelessWidget {
  const SchoolLinkCard({
    required this.link,
    required this.children,
    required this.onOpenStudent,
    required this.onMatch,
    required this.onUnlink,
    this.unlinking = false,
    super.key,
  });

  final SchoolLink link;

  /// Maktab javobidagi farzandlar — ilovada topilmasa ism shu yerdan.
  final List<ChildRef> children;
  final ValueChanged<LinkedStudent> onOpenStudent;
  final ValueChanged<LinkedStudent> onMatch;
  final VoidCallback onUnlink;

  /// Aloqa uzilmoqda — tugmada spinner, qayta bosilmaydi.
  final bool unlinking;

  @override
  Widget build(BuildContext context) {
    final school = link.school;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SchoolLogo(school: school, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      school.displayName.isEmpty
                          ? 'school.title'.tr()
                          : school.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(16),
                    ),
                    if (school.city.isNotEmpty)
                      Text(school.city, style: _pop(13, c: _dim)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (link.students.isEmpty)
            Text('school.home.noStudents'.tr(), style: _pop(13.5, c: _dim)),
          for (final (i, student) in link.students.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _StudentRow(
              student: student,
              children: children,
              onOpen: () => onOpenStudent(student),
              onMatch: () => onMatch(student),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: _UnlinkButton(loading: unlinking, onTap: onUnlink),
          ),
        ],
      ),
    );
  }
}

/// O'quvchi: avatar, ism, sinf · moslash holati, bugungi holat, moslash
/// tugmasi. Qator bosilsa — davomat.
class _StudentRow extends ConsumerWidget {
  const _StudentRow({
    required this.student,
    required this.children,
    required this.onOpen,
    required this.onMatch,
  });

  final LinkedStudent student;
  final List<ChildRef> children;
  final VoidCallback onOpen;
  final VoidCallback onMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = student.childId;
    final appChild = childId == null
        ? null
        : ref.watch(childByIdProvider(childId));
    final childName =
        appChild?.name ??
        children.firstWhereOrNull((c) => c.id == childId)?.name;
    final details = [
      if (student.className.isNotEmpty)
        'school.classLabel'.tr(namedArgs: {'name': student.className}),
      _matchText(childName),
    ].join(' · ');

    // O'quvchi qatori — tugma (ichidagi "Farzandga bog'lash" alohida tugma).
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        onTap: onOpen,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _rowBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _rowBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appChild != null)
                ChildAvatar(child: appChild, size: 40, showBorder: false)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _chipBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsBold.backpack,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(15, w: FontWeight.w500),
                    ),
                    Text(details, style: _pop(12.5, c: _dim)),
                    const SizedBox(height: 6),
                    SchoolTodayStatus(studentId: student.id),
                    if (!student.isMatchedByOther) ...[
                      const SizedBox(height: 10),
                      _MatchButton(
                        matched: student.isMatchedToMine,
                        onTap: onMatch,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 20,
                  color: _dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _matchText(String? childName) {
    if (student.isMatchedToMine) {
      return 'school.home.matchedTo'.tr(namedArgs: {'child': childName ?? '—'});
    }
    if (student.isMatchedByOther) return 'school.home.linkedByOther'.tr();
    return 'school.home.notMatched'.tr();
  }
}

/// Moslanmagan — ko'k "Farzandga bog'lash"; moslangan — yengil
/// "O'zgartirish". Tor ekranda yorliq qisqaradi (toshmaydi).
class _MatchButton extends StatelessWidget {
  const _MatchButton({required this.matched, required this.onTap});

  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: matched ? Colors.white.withValues(alpha: 0.08) : _blue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                matched
                    ? SolarIconsOutline.pen
                    : SolarIconsBold.userCheckRounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  matched
                      ? 'school.home.changeMatch'.tr()
                      : 'school.home.match'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(13, w: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Aloqani uzish" — xira matnli tugma (tasdiqlash oynasi chaqiruvchida).
class _UnlinkButton extends StatelessWidget {
  const _UnlinkButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: !loading,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _dim),
                )
              else
                const Icon(SolarIconsOutline.logout_2, size: 16, color: _dim),
              const SizedBox(width: 6),
              Text('school.home.unlink'.tr(), style: _pop(13, c: _dim)),
            ],
          ),
        ),
      ),
    );
  }
}
