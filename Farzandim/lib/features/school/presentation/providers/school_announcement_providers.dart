// ─────────────────────────────────────────────────────────────────────
// school_announcement_providers — maktab e'lonlari (ota-ona)
// ─────────────────────────────────────────────────────────────────────
//
// - `schoolUnreadCountProvider`: dashboard kartasi va maktab sahifasidagi
//   "E'lonlar" belgisi. Sonni server hisoblaydi — 1 elementli sahifa
//   so'raladi.
// - `schoolAnnouncementsProvider`: e'lonlar ekrani — 20 tadan sahifalar,
//   `loadMore`, optimistik "o'qildi" (xatoda qaytariladi) va serverning
//   o'qilmaganlar soni.
// Yangilash: push, resume va pull-to-refresh (`invalidateSchoolData`).

import 'dart:async';
import 'dart:math' as math;

import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard ↔ maktab sahifasi o'tishlarida qayta so'ralmasin.
const Duration _unreadCacheTtl = Duration(minutes: 2);

/// Barcha maktablar bo'yicha o'qilmagan e'lonlar soni.
final schoolUnreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Bog'lanish yo'q (yoki bo'lim mavjud emas) → e'lon ham yo'q: so'rovsiz.
  final hasLinks = ref.watch(
    schoolLinksProvider.select((links) => links.valueOrNull?.hasLinks ?? false),
  );
  if (!hasLinks) return 0;
  final repo = ref.watch(schoolRepositoryProvider);
  keepAliveFor(ref, _unreadCacheTtl);
  final page = await repo.fetchAnnouncements(limit: 1);
  return page.unread;
});

/// E'lonlar ekrani holati.
@immutable
class SchoolAnnouncementsState {
  const SchoolAnnouncementsState({
    this.items = const [],
    this.page = 0,
    this.totalPages = 1,
    this.unread = 0,
    this.loading = true,
    this.loadingMore = false,
    this.failure,
    this.moreFailure,
  });

  static const Object _keep = Object();

  /// Yuklangan e'lonlar (yangisi oldin, id bo'yicha takrorsiz).
  final List<SchoolAnnouncement> items;

  /// Oxirgi yuklangan sahifa (0 — hali yo'q).
  final int page;
  final int totalPages;

  /// O'qilmaganlar: birinchi sahifadagi server soni + shu ekranda
  /// o'qilganlar ayirmasi.
  final int unread;

  /// Birinchi sahifa yuklanmoqda (ro'yxat hali yo'q).
  final bool loading;
  final bool loadingMore;

  /// Oxirgi to'liq yuklash xatosi (ro'yxat bo'sh bo'lsa — xato holati).
  final SchoolFailure? failure;

  /// Keyingi sahifa xatosi — ro'yxat qoladi, "qayta urinish" tugmasi.
  final SchoolFailure? moreFailure;

  bool get hasMore => page > 0 && page < totalPages;

  SchoolAnnouncementsState copyWith({
    List<SchoolAnnouncement>? items,
    int? page,
    int? totalPages,
    int? unread,
    bool? loading,
    bool? loadingMore,
    Object? failure = _keep,
    Object? moreFailure = _keep,
  }) {
    return SchoolAnnouncementsState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      unread: unread ?? this.unread,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: identical(failure, _keep)
          ? this.failure
          : failure as SchoolFailure?,
      moreFailure: identical(moreFailure, _keep)
          ? this.moreFailure
          : moreFailure as SchoolFailure?,
    );
  }
}

class SchoolAnnouncementsNotifier
    extends StateNotifier<SchoolAnnouncementsState> {
  /// [onReadConfirmed] — server "o'qildi"ni tasdiqlaganda (o'qilmaganlar
  /// belgisini yangilash uchun); ekran yopilgan bo'lsa ham chaqiriladi.
  ///
  /// [signedIn] `null` — kirish holati hali aniqlanmagan (sovuq start):
  /// so'rovsiz "yuklanmoqda"da qoladi, holat aniqlangach provider qayta
  /// quriladi.
  SchoolAnnouncementsNotifier({
    required SchoolRepository repository,
    required bool? signedIn,
    required VoidCallback onReadConfirmed,
  }) : _repo = repository,
       _signedIn = signedIn ?? false,
       _onReadConfirmed = onReadConfirmed,
       super(const SchoolAnnouncementsState()) {
    if (signedIn == null) return;
    if (signedIn) {
      unawaited(refresh());
    } else {
      state = const SchoolAnnouncementsState(
        loading: false,
        failure: SchoolFailure(SchoolFailureKind.sessionExpired),
      );
    }
  }

  final SchoolRepository _repo;
  final bool _signedIn;
  final VoidCallback _onReadConfirmed;

  /// `refresh`dan keyin kechikkan `loadMore`/`markRead` javobi yangi
  /// ro'yxatni buzmasin.
  int _generation = 0;

  /// Birinchi sahifani qayta yuklash (pull-to-refresh). Yangilanayotganda
  /// eski ro'yxat ekranda qoladi; xato `state.failure`da.
  Future<void> refresh() async {
    if (!_signedIn) return;
    final generation = ++_generation;
    state = state.copyWith(
      loading: state.page == 0,
      loadingMore: false,
      failure: null,
      moreFailure: null,
    );
    try {
      final first = await _repo.fetchAnnouncements();
      if (!mounted || generation != _generation) return;
      state = SchoolAnnouncementsState(
        items: first.items,
        page: first.page,
        totalPages: first.totalPages,
        unread: first.unread,
        loading: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      final failure = SchoolFailure.fromError(e);
      debugPrint('[school] announcements: $failure');
      state = state.copyWith(loading: false, failure: failure);
    }
  }

  /// Keyingi sahifa (ro'yxat oxirida). Sahifa xatosidan keyin avtomatik
  /// chaqirilmaydi — [retryMore] bilan. O'qilmaganlar soni o'zgarmaydi:
  /// bu ekranda o'qilganlar allaqachon ayirilgan.
  Future<void> loadMore() async {
    final current = state;
    if (!current.hasMore ||
        current.loading ||
        current.loadingMore ||
        current.moreFailure != null) {
      return;
    }
    final generation = _generation;
    state = current.copyWith(loadingMore: true);
    try {
      final next = await _repo.fetchAnnouncements(page: current.page + 1);
      if (!mounted || generation != _generation) return;
      final known = {for (final item in state.items) item.id};
      state = state.copyWith(
        items: List.unmodifiable([
          ...state.items,
          ...next.items.where((item) => known.add(item.id)),
        ]),
        page: next.page,
        totalPages: next.totalPages,
        loadingMore: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        loadingMore: false,
        moreFailure: SchoolFailure.fromError(e),
      );
    }
  }

  /// Sahifa xatosidan keyin "qayta urinish".
  Future<void> retryMore() {
    state = state.copyWith(moreFailure: null);
    return loadMore();
  }

  /// E'lon ochildi → "o'qildi". Ro'yxatda bo'lsa darhol belgilanadi va
  /// son kamayadi; server rad etsa qaytariladi. Ro'yxatda yo'q (push'dagi
  /// eski e'lon) — faqat serverga yuboriladi. `true` — server tasdiqladi.
  Future<bool> markRead(String id) async {
    if (id.isEmpty) return false;
    final index = state.items.indexWhere((item) => item.id == id);
    final original = index < 0 ? null : state.items[index];
    if (original != null && original.isRead) return true;
    final generation = _generation;
    final optimistic = original?.markedRead(DateTime.now());
    if (optimistic != null) {
      state = state.copyWith(
        items: _replace(state.items, optimistic),
        unread: math.max(0, state.unread - 1),
      );
    }
    try {
      final readAt = await _repo.markAnnouncementRead(id);
      _onReadConfirmed();
      if (mounted) _confirm(id, readAt);
      return true;
    } catch (e) {
      debugPrint('[school] announcement read: ${SchoolFailure.fromError(e)}');
      if (mounted && original != null && generation == _generation) {
        _rollback(original, optimistic);
      }
      return false;
    }
  }

  /// Oraliqda ro'yxat yangilanib, e'lon yana "o'qilmagan" kelgan bo'lsa
  /// (o'qish serverga yetmasdan olingan) — belgilanadi va son kamayadi.
  void _confirm(String id, DateTime readAt) {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0 || state.items[index].isRead) return;
    state = state.copyWith(
      items: _replace(state.items, state.items[index].markedRead(readAt)),
      unread: math.max(0, state.unread - 1),
    );
  }

  /// Optimistik belgini qaytaradi (e'lon hali o'sha nusxa bo'lsa).
  void _rollback(SchoolAnnouncement original, SchoolAnnouncement? optimistic) {
    final index = state.items.indexWhere((item) => item.id == original.id);
    if (index < 0 || !identical(state.items[index], optimistic)) return;
    state = state.copyWith(
      items: _replace(state.items, original),
      unread: state.unread + 1,
    );
  }

  static List<SchoolAnnouncement> _replace(
    List<SchoolAnnouncement> items,
    SchoolAnnouncement next,
  ) => List.unmodifiable([
    for (final item in items) item.id == next.id ? next : item,
  ]);
}

/// Yangilash signali: `invalidateSchoolData` uni bekor qilganda yangi
/// qiymat oladi va ochiq e'lonlar ekrani `refresh` qiladi — provayderni
/// qayta yaratish yuklangan sahifalar va aylantirish joyini yo'qotardi.
final schoolAnnouncementsRefreshSignal = Provider.autoDispose<Object>(
  (ref) => Object(),
);

/// E'lonlar ekrani (login'ga bog'langan; ekran yopilsa tozalanadi).
final schoolAnnouncementsProvider =
    StateNotifierProvider.autoDispose<
      SchoolAnnouncementsNotifier,
      SchoolAnnouncementsState
    >((ref) {
      // `container.invalidate` faqat tirik provayderni yangilaydi va ekran
      // yopilgandan keyin ham xavfsiz (bu provayderning `ref`i esa yo'q).
      final container = ref.container;
      final notifier = SchoolAnnouncementsNotifier(
        repository: ref.watch(schoolRepositoryProvider),
        signedIn: ref.watch(schoolSignedInProvider),
        onReadConfirmed: () => container.invalidate(schoolUnreadCountProvider),
      );
      ref.listen<Object>(
        schoolAnnouncementsRefreshSignal,
        (_, _) => unawaited(notifier.refresh()),
      );
      return notifier;
    });
