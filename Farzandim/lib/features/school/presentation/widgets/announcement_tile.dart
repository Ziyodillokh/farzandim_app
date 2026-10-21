// ─────────────────────────────────────────────────────────────────────
// AnnouncementTile — maktab e'loni (yig'iq / ochiq)
// ─────────────────────────────────────────────────────────────────────
//
// Yig'iq: o'qilmagan nuqtasi, maktab · vaqt, "Muhim" belgisi, sarlavha va
// matnning 2 qatori. Bosilsa ochiladi (to'liq matn, belgilab nusxa olish
// mumkin) — ochilganda chaqiruvchi "o'qildi" deb belgilaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _blue = Color(0xFF216BFF);
const _amber = Color(0xFFFBBF24);
const _dim = Color(0x99FFFFFF); // oq 60%

/// Yig'iq holatda ko'rinadigan matn qatorlari.
const int _previewLines = 2;

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    required this.announcement,
    required this.expanded,
    this.onTap,
    this.caption,
    super.key,
  });

  final SchoolAnnouncement announcement;
  final bool expanded;

  /// `null` — o'zgarmas karta (ochib-yopilmaydi, strelkasiz).
  final VoidCallback? onTap;

  /// Maktab · vaqt o'rniga ko'rsatiladigan izoh (push matni kartasi).
  final String? caption;

  String get _caption {
    final caption = this.caption;
    if (caption != null) return caption;
    final sentAt = announcement.sentAt;
    return [
      if (announcement.schoolName.isNotEmpty) announcement.schoolName,
      if (sentAt != null) schoolStampLabel(sentAt),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final unread = !announcement.isRead;
    final toggles = onTap != null;
    return Semantics(
      button: toggles,
      expanded: toggles ? expanded : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: unread ? _blue.withValues(alpha: 0.55) : _cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (unread) ...[
                    Semantics(
                      label: 'school.announcements.unread'.tr(),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(12.5, c: _dim),
                    ),
                  ),
                  if (announcement.isImportant) ...[
                    const SizedBox(width: 8),
                    SchoolPill(
                      label: 'school.announcements.important'.tr(),
                      color: _amber,
                    ),
                  ],
                  if (toggles) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        SolarIconsOutline.altArrowDown,
                        size: 18,
                        color: _dim,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                announcement.title,
                maxLines: expanded ? null : _previewLines,
                overflow: expanded ? null : TextOverflow.ellipsis,
                style: _pop(
                  15.5,
                  w: unread ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (announcement.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                if (expanded)
                  SelectableText(
                    announcement.body,
                    style: _pop(14, c: Colors.white.withValues(alpha: 0.85)),
                  )
                else
                  Text(
                    announcement.body,
                    maxLines: _previewLines,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(14, c: _dim),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
