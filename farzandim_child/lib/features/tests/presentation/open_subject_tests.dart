// Fan testlarini ochish — "Boshlash", "Test ishlash", "Yana ishlash".
//
// Kunlik test oqimi (Daily Learning) backend bilan quriladi. Hozircha
// berilgan fanlardan birinchi HAQIQIY testlari borini ochadi
// (`/tests/subject`); hech biri bo'lmasa — xabar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/tests/domain/test_subject.dart';
import 'package:farzandim_child/features/tests/presentation/providers/tests_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void openSubjectTests(
  BuildContext context,
  WidgetRef ref,
  Iterable<Subject> candidates,
) {
  HapticFeedback.selectionClick();
  // Testlar hali yuklanmagan / xato — "tez orada" deyish noto'g'ri bo'lardi.
  final async = ref.read(backendContestsProvider);
  if (!async.hasValue) {
    if (async.hasError) _showSnack(context, 'contests.loadError'.tr());
    return;
  }
  for (final subject in candidates) {
    final key = subjectTestKey(subject);
    final group = ref.read(testSubjectProvider(key));
    if (group != null && group.count > 0) {
      context.push('/tests/subject', extra: key);
      return;
    }
  }
  _showSnack(context, 'tests.subjectSoon'.tr());
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}
