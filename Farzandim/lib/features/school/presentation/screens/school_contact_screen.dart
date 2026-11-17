// ─────────────────────────────────────────────────────────────────────
// SchoolContactScreen — maktab xodimi sahifasi
// ─────────────────────────────────────────────────────────────────────
//
// Xodim kartasi (rol, lavozim, nima bo'yicha yozish mumkin), psixolog
// uchun maxfiylik eslatmasi, mavjud yozishma va rolga mos shablonlar.
// Shablon bosilsa — tayyor matn bilan yozish varag'i; "O'zim yozaman" —
// bo'sh matn.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/compose_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_text_fit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/topic_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolContactScreen extends ConsumerWidget {
  const SchoolContactScreen({
    required this.staffId,
    required this.studentId,
    super.key,
  });

  final String staffId;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(schoolContactsProvider(studentId));
    final body = contacts.when(
      loading: () => const SchoolLoadingView(),
      error: (error, _) => SchoolErrorView(
        error: SchoolFailure.fromError(error),
        onRetry: () => ref.invalidate(schoolContactsProvider(studentId)),
      ),
      data: (data) {
        final contact = data.contacts
            .where((c) => c.staffId == staffId)
            .firstOrNull;
        if (contact == null) {
          return SchoolMessageView(
            icon: SolarIconsBold.userCross,
            title: 'school.connect.unavailable'.tr(),
            message: 'school.errors.contactUnavailable'.tr(),
          );
        }
        return _ContactBody(contact: contact, student: data.student);
      },
    );
    return SchoolScaffold(title: 'school.connect.title'.tr(), body: body);
  }
}

class _ContactBody extends StatelessWidget {
  const _ContactBody({required this.contact, required this.student});

  final SchoolContact contact;
  final ConnectStudent student;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(contact.role);
    final threadId = contact.threadId;
    final topics = topicsFor(contact.role);
    void compose(ContactTopic topic, {String? prefill}) => unawaited(
      showComposeSheet(
        context,
        contact: contact,
        student: student,
        topic: topic,
        prefill: prefill,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
      children: [
        _Hero(contact: contact, student: student, color: color),
        if (contact.isConfidential) ...[
          const SizedBox(height: 12),
          SchoolNote(
            icon: SolarIconsBold.lockKeyhole,
            text: 'school.connect.confidential'.tr(),
          ),
        ],
        if (threadId != null) ...[
          const SizedBox(height: 12),
          SkCard(
            onTap: () =>
                unawaited(context.push(AppRoutes.schoolThreadPath(threadId))),
            accent: contact.unread > 0 ? SK.blue : null,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                const SkIconBubble(
                  icon: SolarIconsBold.chatRoundDots,
                  size: 40,
                ),
                const SizedBox(width: 12),
                if (contact.unread > 0)
                  Expanded(
                    child: SkTagRow(
                      leading: _openChatLabel(),
                      tag: SkTag(
                        label: 'school.connect.newReply'.tr(),
                        color: SK.blue,
                      ),
                    ),
                  )
                else ...[
                  Expanded(child: _openChatLabel()),
                  const Icon(
                    SolarIconsOutline.altArrowRight,
                    size: 20,
                    color: SK.faint,
                  ),
                ],
              ],
            ),
          ),
        ],
        SkSectionLabel('school.connect.writeSection'.tr()),
        WriteOwnCard(onTap: () => compose(ContactTopic.other)),
        SkSectionLabel('school.connect.orTemplate'.tr()),
        SkTwoColumnRows(
          aspectRatio: 1.08,
          children: [
            for (final topic in topics)
              TopicCard(topic: topic, onTap: () => compose(topic)),
          ],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.contact,
    required this.student,
    required this.color,
  });

  final SchoolContact contact;
  final ConnectStudent student;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SkCard(
      tint: color,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        children: [
          SkAvatar(name: contact.fullName, color: color, size: 76),
          const SizedBox(height: 14),
          Text(
            contact.fullName,
            textAlign: TextAlign.center,
            style: skDisplay(19, w: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              SkTag(
                label: contact.role.labelKey.tr(),
                color: color,
                icon: roleIcon(contact.role),
              ),
              if (contact.position.isNotEmpty &&
                  contact.position != contact.role.labelKey.tr())
                SkTag(label: contact.position, color: SK.dim),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'school.connect.roleHint.${contact.role.name}'.tr(),
            textAlign: TextAlign.center,
            style: skText(13, c: SK.dim, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SK.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(SolarIconsBold.userRounded, size: 15, color: SK.dim),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'school.connect.aboutStudent'.tr(
                      namedArgs: {
                        'name': student.name,
                        'className': student.className,
                      },
                    ),
                    style: skText(12.5, c: SK.dim, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _openChatLabel() => Text(
  'school.connect.openChat'.tr(),
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: skText(14.5, w: FontWeight.w600, height: 1.35),
);
