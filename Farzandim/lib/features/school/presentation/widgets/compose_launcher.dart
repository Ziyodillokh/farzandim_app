// Boshqa sahifalardan (e'lon, kelmagan kun, to'lov) kerakli xodimga
// to'g'ridan-to'g'ri yozish: o'quvchi kontaktlari yuklanadi, mos xodim
// topiladi va tayyor matn bilan yozish varag'i ochiladi. Xodim hali
// panelga ulanmagan bo'lsa — kontaktlar ro'yxati (boshqasini tanlash).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/compose_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Kimga yoziladi.
enum ContactTarget { homeroom, administration, psychologist }

/// [contacts] ichidan [target] xodimi (ma'muriyat yo'q bo'lsa — direktor).
SchoolContact? contactFor(SchoolContacts contacts, ContactTarget target) {
  final list = contacts.contacts;
  return switch (target) {
    ContactTarget.homeroom =>
      contacts.inGroup(ContactGroup.classTeacher).firstOrNull,
    ContactTarget.administration =>
      list.where((c) => c.role == StaffRole.admin).firstOrNull ??
          list.where((c) => c.role == StaffRole.director).firstOrNull,
    ContactTarget.psychologist =>
      contacts.inGroup(ContactGroup.support).firstOrNull,
  };
}

Future<void> composeTo(
  BuildContext context,
  WidgetRef ref, {
  required String studentId,
  required ContactTarget target,
  required ContactTopic topic,
  String? prefill,
}) async {
  final SchoolContacts contacts;
  try {
    contacts = await ref.read(schoolContactsProvider(studentId).future);
  } on SchoolFailure catch (failure) {
    if (context.mounted) AppToast.error(context, failure.messageKey.tr());
    return;
  }
  if (!context.mounted) return;
  final contact = contactFor(contacts, target);
  if (contact == null) {
    AppToast.info(context, 'school.connect.noHomeroom'.tr());
    unawaited(context.push(AppRoutes.schoolContactsPath(student: studentId)));
    return;
  }
  await showComposeSheet(
    context,
    contact: contact,
    student: contacts.student,
    topic: topic,
    prefill: prefill,
  );
}
