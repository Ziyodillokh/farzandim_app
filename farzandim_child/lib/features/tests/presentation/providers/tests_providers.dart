// Testlar sahifasi providerlari — haqiqiy backend testlari ustida.

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/tests/domain/test_subject.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Fanlar bo'yicha" — barcha testlar fan bo'yicha guruhlangan.
final testSubjectsProvider = Provider<List<TestSubjectGroup>>(
  (ref) => groupTestsBySubject(ref.watch(allTestsProvider)),
);

/// Bitta fan guruhi (kalit bo'yicha); topilmasa `null`.
final testSubjectProvider = Provider.family<TestSubjectGroup?, String>((
  ref,
  key,
) {
  for (final group in ref.watch(testSubjectsProvider)) {
    if (group.key == key) return group;
  }
  return null;
});

/// Qidiruv natijalari (so'rov bo'yicha).
final testSearchProvider = Provider.autoDispose
    .family<List<ContestModel>, String>(
      (ref, query) => searchTests(ref.watch(allTestsProvider), query),
    );
