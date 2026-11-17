// ─────────────────────────────────────────────────────────────────────
// SchoolContactsScreen — "Maktab bilan bog'lanish"
// ─────────────────────────────────────────────────────────────────────
//
// O'quvchi tanlanadi (bir nechta bo'lsa) → uning kontaktlari guruhlab:
// sinf rahbari (ajratilgan karta), rahbariyat, psixolog, fan
// o'qituvchilari. Tepada — shu o'quvchi bo'yicha "Murojaatlarim".
// Xodim bosilsa — uning sahifasi (shablonlar va yozish).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_tiles.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolContactsScreen extends ConsumerStatefulWidget {
  const SchoolContactsScreen({this.studentId, super.key});

  /// Tanlangan o'quvchi (`?student=`); berilmasa — birinchisi.
  final String? studentId;

  @override
  ConsumerState<SchoolContactsScreen> createState() =>
      _SchoolContactsScreenState();
}

class _SchoolContactsScreenState extends ConsumerState<SchoolContactsScreen> {
  String? _selected;

  String? _studentOf(SchoolLinks links) {
    final students = links.students;
    if (students.isEmpty) return null;
    final wanted = _selected ?? widget.studentId;
    return students.any((s) => s.id == wanted) ? wanted : students.first.id;
  }

  Future<void> _refresh(String studentId) async {
    ref
      ..invalidate(schoolContactsProvider(studentId))
      ..invalidate(schoolThreadsProvider);
    try {
      await ref
          .read(schoolContactsProvider(studentId).future)
          .timeout(const Duration(seconds: 8));
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(schoolLinksProvider);
    final body = links.when(
      loading: () => const SchoolLoadingView(),
      error: (error, _) => SchoolErrorView(
        error: SchoolFailure.fromError(error),
        onRetry: () => ref.invalidate(schoolLinksProvider),
      ),
      data: (links) {
        final studentId = _studentOf(links);
        if (studentId == null) {
          return SchoolMessageView(
            icon: SolarIconsBold.usersGroupRounded,
            title: 'school.connect.emptyTitle'.tr(),
            message: 'school.connect.emptyBody'.tr(),
          );
        }
        return RefreshIndicator(
          color: SK.blue,
          backgroundColor: SK.card,
          onRefresh: () => _refresh(studentId),
          child: _ContactsBody(
            students: links.students,
            studentId: studentId,
            onSelect: (id) => setState(() => _selected = id),
          ),
        );
      },
    );
    return SchoolScaffold(title: 'school.connect.title'.tr(), body: body);
  }
}

class _ContactsBody extends ConsumerWidget {
  const _ContactsBody({
    required this.students,
    required this.studentId,
    required this.onSelect,
  });

  final List<LinkedStudent> students;
  final String studentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(schoolContactsProvider(studentId));
    final threads =
        (ref.watch(schoolThreadsProvider).valueOrNull?.items ?? const [])
            .where((t) => t.student.id == studentId)
            .toList(growable: false);
    void open(SchoolContact c) => unawaited(
      context.push(AppRoutes.schoolContactPath(c.staffId, student: studentId)),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
      children: [
        if (students.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = students[i];
                return SkChip(
                  label: '${studentFirstName(s.fullName)} · ${s.className}',
                  selected: s.id == studentId,
                  onTap: () => onSelect(s.id),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        const _PrivacyNote(),
        if (threads.isNotEmpty) ...[
          SkSectionLabel('school.connect.myThreads'.tr()),
          for (final t in threads) ...[
            ThreadTile(
              thread: t,
              onTap: () =>
                  unawaited(context.push(AppRoutes.schoolThreadPath(t.id))),
            ),
            const SizedBox(height: 10),
          ],
        ],
        ...contacts.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: SK.blue)),
            ),
          ],
          error: (error, _) => [
            const SizedBox(height: 24),
            SchoolInlineError(
              message: SchoolFailure.fromError(error).messageKey.tr(),
            ),
          ],
          data: (data) => _groups(data, open),
        ),
      ],
    );
  }

  List<Widget> _groups(SchoolContacts data, void Function(SchoolContact) open) {
    if (data.contacts.isEmpty) {
      return [
        const SizedBox(height: 30),
        SchoolMessageView(
          icon: SolarIconsBold.usersGroupRounded,
          title: 'school.connect.emptyTitle'.tr(),
          message: 'school.connect.emptyBody'.tr(),
        ),
      ];
    }
    return [
      for (final group in ContactGroup.values)
        if (data.inGroup(group).isNotEmpty) ...[
          SkSectionLabel(group.labelKey.tr()),
          for (final contact in data.inGroup(group)) ...[
            ContactCard(
              contact: contact,
              featured: group == ContactGroup.classTeacher,
              onTap: () => open(contact),
            ),
            const SizedBox(height: 10),
          ],
        ],
    ];
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return SkCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const SkIconBubble(
            icon: SolarIconsBold.shieldCheck,
            color: SK.green,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'school.connect.privacy'.tr(),
                  style: skText(13, w: FontWeight.w500, height: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  'school.connect.replyTime'.tr(),
                  style: skText(12, c: SK.dim, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
