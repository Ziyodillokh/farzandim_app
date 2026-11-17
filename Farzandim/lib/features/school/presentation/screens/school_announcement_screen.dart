// ─────────────────────────────────────────────────────────────────────
// SchoolAnnouncementScreen — bitta e'lon
// ─────────────────────────────────────────────────────────────────────
//
// Muhim e'lon banneri, sarlavha, kimdan / kimga / qachon, to'liq matn
// (belgilab nusxa olish mumkin). Amallar: sinf rahbariga savol (e'lon
// nomi bilan tayyor matn), matnni nusxalash. Ochilganda "o'qildi".
// E'lon ro'yxatdan `extra` bilan keladi; bo'lmasa yuklangan
// sahifalardan id bo'yicha olinadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/announcement_card.dart';
import 'package:farzandim/features/school/presentation/widgets/compose_launcher.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolAnnouncementScreen extends ConsumerStatefulWidget {
  const SchoolAnnouncementScreen({
    required this.announcementId,
    this.initial,
    super.key,
  });

  final String announcementId;

  /// Ro'yxatdan kelgan e'lon (`extra`).
  final SchoolAnnouncement? initial;

  @override
  ConsumerState<SchoolAnnouncementScreen> createState() =>
      _SchoolAnnouncementScreenState();
}

class _SchoolAnnouncementScreenState
    extends ConsumerState<SchoolAnnouncementScreen> {
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null || !initial.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(schoolAnnouncementsProvider.notifier)
              .markRead(widget.announcementId),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(
      schoolAnnouncementsProvider.select(
        (s) => s.items.where((i) => i.id == widget.announcementId).firstOrNull,
      ),
    );
    final announcement = loaded ?? widget.initial;
    return SchoolScaffold(
      title: 'school.announcements.detailTitle'.tr(),
      body: announcement == null
          ? SchoolMessageView(
              icon: SolarIconsBold.letterUnread,
              title: 'school.announcements.detailTitle'.tr(),
              message: 'school.announcements.notFound'.tr(),
            )
          : _Detail(announcement: announcement),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.announcement});

  final SchoolAnnouncement announcement;

  /// Savol uchun o'quvchi: e'lon maktabidagi, sinfi auditoriyada bo'lgani.
  LinkedStudent? _studentFor(SchoolLinks? links) {
    if (links == null) return null;
    final inSchool = [
      for (final link in links.links)
        if (announcement.schoolId.isEmpty ||
            link.school.id == announcement.schoolId)
          ...link.students,
    ];
    final classes = announcement.audience?.classNames ?? const <String>[];
    return inSchool.where((s) => classes.contains(s.className)).firstOrNull ??
        inSchool.firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = announcement;
    final role = roleOfApi(a.author?.role);
    final color = a.isImportant ? SK.amber : roleColor(role);
    final sentAt = a.sentAt;
    final audience = announcementAudienceLabel(a);
    final author = a.author;
    final student = _studentFor(ref.watch(schoolLinksProvider).valueOrNull);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
      children: [
        if (a.isImportant) ...[
          SkCard(
            tint: SK.amber,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Icon(
                  SolarIconsBold.dangerCircle,
                  size: 20,
                  color: SK.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'school.announcements.importantBanner'.tr(),
                    style: skText(13, c: SK.amber, w: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SkCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title, style: skDisplay(19, w: FontWeight.w500)),
              const SizedBox(height: 16),
              _Meta(
                icon: author == null
                    ? SolarIconsBold.buildings
                    : roleIcon(role),
                color: color,
                label: 'school.announcements.from'.tr(),
                value: author == null
                    ? announcementAuthorLabel(a)
                    : [
                        if (author.name.isNotEmpty) author.name,
                        announcementAuthorLabel(a),
                      ].join(' · '),
              ),
              if (audience != null)
                _Meta(
                  icon: SolarIconsBold.usersGroupRounded,
                  color: SK.sky,
                  label: 'school.announcements.to'.tr(),
                  value: audience,
                ),
              if (sentAt != null)
                _Meta(
                  icon: SolarIconsBold.clockCircle,
                  color: SK.dim,
                  label: 'school.announcements.sentAt'.tr(),
                  value: schoolStampLabel(sentAt),
                ),
              const SizedBox(height: 6),
              const Divider(color: SK.hairline, height: 24),
              SelectableText(a.body, style: skText(15, height: 1.65)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (student != null)
          _ActionButton(
            icon: SolarIconsBold.chatRoundDots,
            color: SK.sky,
            label: 'school.announcements.ask'.tr(),
            onTap: () => unawaited(
              composeTo(
                context,
                ref,
                studentId: student.id,
                target: ContactTarget.homeroom,
                topic: ContactTopic.other,
                prefill: 'school.announcements.askPrefill'.tr(
                  namedArgs: {'title': a.title},
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _ActionButton(
          icon: SolarIconsBold.copy,
          color: SK.dim,
          label: 'school.announcements.copy'.tr(),
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: '${a.title}\n\n${a.body}'),
            );
            if (context.mounted) {
              AppToast.success(context, 'school.announcements.copied'.tr());
            }
          },
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SkIconBubble(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(label, style: skText(12.5, c: SK.dim)),
          ),
          Expanded(
            child: Text(
              value,
              style: skText(13.5, w: FontWeight.w500, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SkCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          SkIconBubble(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: skText(14, w: FontWeight.w500)),
          ),
          const Icon(
            SolarIconsOutline.altArrowRight,
            size: 18,
            color: SK.faint,
          ),
        ],
      ),
    );
  }
}
