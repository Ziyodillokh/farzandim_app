// ─────────────────────────────────────────────────────────────────────
// school_connect_providers — maktab bilan aloqa va farzand statistikasi
// ─────────────────────────────────────────────────────────────────────
//
// - `schoolContactsProvider(studentId)`: o'quvchi bo'yicha kontaktlar.
// - `schoolThreadsProvider`: "Murojaatlarim" va o'qilmagan javoblar
//   (Maktab tabi nishoniga qo'shiladi).
// - `schoolThreadProvider(threadId)`: yozishma.
// - `studentOverviewProvider(studentId)`: "Farzandim maktabda".
// - `SchoolConnectActions`: xabar yuborish va "o'qildi".
// Yangilash: push (`SCHOOL_PARENT_MESSAGE`), resume, pull-to-refresh.

import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/data/school_connect_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab nishoni uchun — o'tishlarda qayta so'ralmasin.
const Duration _threadsCacheTtl = Duration(minutes: 2);

final schoolContactsProvider = FutureProvider.autoDispose
    .family<SchoolContacts, String>((ref, studentId) {
      return ref
          .watch(schoolConnectRepositoryProvider)
          .fetchContacts(studentId);
    });

/// Barcha yozishmalar (bog'lanish yo'q bo'lsa — so'rovsiz bo'sh).
final schoolThreadsProvider = FutureProvider.autoDispose<SchoolThreads>((
  ref,
) async {
  final hasLinks = ref.watch(
    schoolLinksProvider.select((links) => links.valueOrNull?.hasLinks ?? false),
  );
  if (!hasLinks) return SchoolThreads.empty;
  keepAliveFor(ref, _threadsCacheTtl);
  return ref.watch(schoolConnectRepositoryProvider).fetchThreads();
});

/// O'qilmagan xodim javoblari (Maktab tabi va "Bog'lanish" kartasi).
final schoolThreadsUnreadProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(schoolThreadsProvider).valueOrNull?.unread ?? 0,
);

final schoolThreadProvider = FutureProvider.autoDispose
    .family<SchoolThread, String>((ref, threadId) {
      return ref.watch(schoolConnectRepositoryProvider).fetchThread(threadId);
    });

final studentOverviewProvider = FutureProvider.autoDispose
    .family<StudentOverview, String>((ref, studentId) {
      return ref
          .watch(schoolConnectRepositoryProvider)
          .fetchOverview(studentId);
    });

/// Xabar yuborish va o'qildi — natija tegishli ro'yxatlarga yoziladi.
class SchoolConnectActions {
  SchoolConnectActions(this._ref);

  final Ref _ref;

  SchoolConnectRepository get _repo =>
      _ref.read(schoolConnectRepositoryProvider);

  /// Xodimga yangi xabar (yozishma bo'lmasa ochiladi) → yozishma.
  Future<SchoolThread> start({
    required SchoolContact contact,
    required String studentId,
    required ContactTopic topic,
    required String body,
  }) async {
    final thread = await _repo.startThread(
      staffId: contact.staffId,
      studentId: studentId,
      topic: topic,
      body: body,
    );
    _afterChange(studentId);
    return thread;
  }

  Future<SchoolThread> send({
    required SchoolThread thread,
    required String body,
    ContactTopic? topic,
  }) async {
    final next = await _repo.sendMessage(
      threadId: thread.id,
      body: body,
      topic: topic,
    );
    _afterChange(thread.student.id);
    return next;
  }

  /// Yozishma ochildi — xodim javoblari o'qilgan (xato jim: keyingi
  /// ochilishda qayta belgilanadi).
  Future<void> markRead(SchoolThread thread) async {
    if (thread.unread == 0) return;
    try {
      await _repo.markThreadRead(thread.id);
    } on Object {
      return;
    }
    _ref
      ..invalidate(schoolThreadsProvider)
      ..invalidate(schoolContactsProvider(thread.student.id));
  }

  void _afterChange(String studentId) {
    _ref
      ..invalidate(schoolThreadsProvider)
      ..invalidate(schoolContactsProvider(studentId));
  }
}

final schoolConnectActionsProvider = Provider<SchoolConnectActions>(
  SchoolConnectActions.new,
);
