// Maktab bilan bog'lanish: kontakt va yozishma kartalari.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Xodim kartasi. [featured] — sinf rahbari (kattaroq, rangli nur bilan).
class ContactCard extends StatelessWidget {
  const ContactCard({
    required this.contact,
    required this.onTap,
    this.featured = false,
    super.key,
  });

  final SchoolContact contact;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(contact.role);
    final subtitle = contact.position.isNotEmpty
        ? contact.position
        : contact.role.labelKey.tr();
    return SkCard(
      onTap: onTap,
      tint: featured ? color : null,
      padding: EdgeInsets.all(featured ? 18 : 14),
      semanticsLabel: '${contact.fullName}, $subtitle',
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SkAvatar(
                name: contact.fullName,
                color: color,
                size: featured ? 56 : 46,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: SK.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: SK.border),
                  ),
                  child: Icon(roleIcon(contact.role), size: 13, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skText(
                    featured ? 16 : 15,
                    w: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skText(13, c: color, w: FontWeight.w500, height: 1.35),
                ),
                if (featured) ...[
                  const SizedBox(height: 6),
                  Text(
                    'school.connect.roleHint.${contact.role.name}'.tr(),
                    style: skText(12.5, c: SK.dim, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (contact.unread > 0)
            _CountDot(count: contact.unread)
          else if (contact.isConfidential)
            const Icon(SolarIconsBold.lockKeyhole, size: 18, color: SK.faint)
          else
            const Icon(
              SolarIconsOutline.altArrowRight,
              size: 20,
              color: SK.faint,
            ),
        ],
      ),
    );
  }
}

/// "Murojaatlarim" qatori: xodim, oxirgi xabar va holat.
class ThreadTile extends StatelessWidget {
  const ThreadTile({required this.thread, required this.onTap, super.key});

  final SchoolThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final staff = thread.staff;
    final color = roleColor(staff.role);
    final at = thread.lastMessageAt;
    final (label, tone) = switch (thread) {
      SchoolThread(unread: > 0) => ('school.connect.newReply', SK.blue),
      SchoolThread(resolved: true) => ('school.connect.resolved', SK.green),
      SchoolThread(lastFromStaff: true) => (
        'school.connect.answered',
        SK.green,
      ),
      _ => ('school.connect.waiting', SK.amber),
    };
    return SkCard(
      onTap: onTap,
      accent: thread.unread > 0 ? SK.blue : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkAvatar(name: staff.fullName, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        staff.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: skText(
                          14.5,
                          w: thread.unread > 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (at != null)
                      Text(
                        schoolStampLabel(at),
                        style: skText(11.5, c: SK.faint, height: 1.3),
                      ),
                  ],
                ),
                Text(
                  staff.role.labelKey.tr(),
                  style: skText(12, c: color, w: FontWeight.w500, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  thread.preview ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: skText(
                    13,
                    c: thread.unread > 0 ? SK.text : SK.dim,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                SkTag(label: label.tr(), color: tone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SK.blue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count', style: skText(12, w: FontWeight.w700, height: 1.2)),
    );
  }
}
