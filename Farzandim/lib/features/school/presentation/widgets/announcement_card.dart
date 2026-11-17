// E'lon kartasi (ro'yxat): muallif roli ikoni, sarlavha, qisqa matn,
// kimga (butun maktab / sinf / shaxsan), muhimlik va o'qilmaganlik.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Muallif yorlig'i: lavozim (bo'lsa) yoki rol nomi; muallif yo'q — maktab.
String announcementAuthorLabel(SchoolAnnouncement a) {
  final author = a.author;
  if (author == null) {
    return a.schoolName.isEmpty
        ? 'school.announcements.school'.tr()
        : a.schoolName;
  }
  final role = roleOfApi(author.role).labelKey.tr();
  return author.position.isNotEmpty ? author.position : role;
}

/// Kimga yorlig'i (`null` — ma'lumot yo'q).
String? announcementAudienceLabel(SchoolAnnouncement a) {
  final audience = a.audience;
  if (audience == null) return null;
  return switch (audience.kind) {
    AnnouncementAudienceKind.school =>
      'school.announcements.audience.school'.tr(),
    AnnouncementAudienceKind.classes =>
      'school.announcements.audience.classes'.tr(
        namedArgs: {'classes': audience.classNames.join(', ')},
      ),
    AnnouncementAudienceKind.personal =>
      'school.announcements.audience.personal'.tr(),
    AnnouncementAudienceKind.unknown => null,
  };
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    required this.announcement,
    required this.onTap,
    this.caption,
    super.key,
  });

  final SchoolAnnouncement announcement;
  final VoidCallback onTap;

  /// Qo'shimcha izoh (masalan, "Bildirishnomadan").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final unread = !a.isRead;
    final role = roleOfApi(a.author?.role);
    final color = a.isImportant ? SK.amber : roleColor(role);
    final sentAt = a.sentAt;
    final audience = announcementAudienceLabel(a);
    final caption = this.caption;
    return SkCard(
      onTap: onTap,
      accent: unread ? (a.isImportant ? SK.amber : SK.blue) : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      semanticsLabel: a.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkIconBubble(
                icon: a.isImportant
                    ? SolarIconsBold.dangerCircle
                    : a.author == null
                    ? SolarIconsBold.letterUnread
                    : roleIcon(role),
                color: color,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcementAuthorLabel(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: skText(12.5, c: color, w: FontWeight.w600),
                    ),
                    if (sentAt != null)
                      Text(
                        schoolStampLabel(sentAt),
                        style: skText(11.5, c: SK.faint, height: 1.3),
                      ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: a.isImportant ? SK.amber : SK.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: skText(
              15,
              w: unread ? FontWeight.w700 : FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (a.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              a.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: skText(13, c: SK.dim, height: 1.45),
            ),
          ],
          if (audience != null || a.isImportant || caption != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (a.isImportant)
                  SkTag(
                    label: 'school.announcements.important'.tr(),
                    color: SK.amber,
                  ),
                if (audience != null)
                  SkTag(
                    label: audience,
                    color: SK.dim,
                    icon: SolarIconsBold.usersGroupRounded,
                  ),
                if (caption != null) SkTag(label: caption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
