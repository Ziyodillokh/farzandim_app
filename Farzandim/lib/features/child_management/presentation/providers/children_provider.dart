// ─────────────────────────────────────────────────────────────────────
// children_provider — Backend REST only (Sprint 4.4.22 cleanup)
// ─────────────────────────────────────────────────────────────────────
//
// Sprint 4.4 migrationdan keyin Firebase fallback olib tashlandi.
// Bolalar ma'lumotlari faqat Backend REST orqali keladi (Telegram auth).

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/shared/models/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pull-to-refresh / manual refresh trigger. `invalidate` o'rniga bu counter
/// oshiriladi: `invalidate` provider'ni DISPOSE qilib oldingi qiymatni
/// yo'qotadi (dashboard bir lahza bo'sh "add-child" flash beradi), counter esa
/// provider'ni RECOMPUTE qiladi → oldingi ro'yxat saqlanib turadi
/// (`copyWithPrevious`), shuning uchun ekran bo'shab ketmaydi.
final childrenRefreshTickProvider = StateProvider<int>((_) => 0);

/// Jonli holat "puls"i — har 30s emit. Buni watch qilgan widget (masalan
/// dashboard `_StatusLine`) qayta build bo'lib `isLiveOnline`ni qayta
/// hisoblaydi (DateTime.now() asosli getter timer'siz "muzlab" qolardi).
///
/// FAQAT rebuild pulse — refetch QILMAYDI (ro'yxatni `childrenProvider`ning
/// o'zi ichki 60s poll bilan yangilaydi). `autoDispose`: dashboard yopilsa
/// puls to'xtaydi; fonda ham emit qilmaydi (lifecycle skip — bekorga ish yo'q).
final statusTickProvider = StreamProvider.autoDispose<int>((ref) async* {
  // MUHIM (zombi-guard): bekor qilingan async* generator faqat KEYINGI
  // yield'da to'xtaydi — `continue` yo'lida yield yo'q, shuning uchun
  // dispose/recompute'dan keyin generator abadiy yashab qolardi. onDispose
  // har rebuild'da ham chaqiriladi (riverpod 2.6) → flag ishonchli.
  var alive = true;
  ref.onDispose(() => alive = false);
  var i = 0;
  yield i;
  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 30), (t) => t)) {
    if (!alive) return;
    if (!isAppResumed(ref)) continue;
    yield ++i;
  }
});

/// Bolalar ro'yxati — Backend REST + ichki 60s polling.
///
/// Auth bo'lmasa bo'sh ro'yxat qaytaradi.
/// CRUD operatsiyadan keyin `ref.invalidate(childrenProvider)` chaqiriladi.
///
/// MASSHTAB (P0-1): polling shu generator ICHIDA — tashqi tick-recompute
/// emas. Afzalliklari: (1) ilova FONDA bo'lsa so'rov yuborilmaydi
/// (lifecycle skip); (2) natija o'zgarmagan bo'lsa yield qilinmaydi —
/// AsyncData identity saqlanib BARCHA watcher'lar (dashboard, xarita,
/// limits) 60s'lik behuda rebuild'lardan qutuladi; (3) loading→data
/// transition'lar ham yo'q (recompute bo'lmagani uchun).
final childrenProvider = StreamProvider<List<Child>>((ref) {
  // FAQAT "authenticated" holati o'zgarsa qayta ishga tushadi. Optimistik
  // startup'da auth ikki marta emit qiladi (cached → fresh user) — `.select`
  // bo'lmasa har emission qayta-fetch qilib, bir lahza bo'sh ro'yxat → "yangi
  // bola qo'shish" sahifasiga otib ketardi (regressiya). User obyekti
  // yangilanishi endi qayta-fetch QILMAYDI.
  final isAuthed =
      ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
  // Manual refresh trigger (pull-to-refresh, resume, CRUD'dan keyin) —
  // recompute darhol yangi fetch boshlaydi.
  ref.watch(childrenRefreshTickProvider);
  if (!isAuthed) return Stream.value(const <Child>[]);
  return _backendChildrenStream(ref);
});

/// Backend REST'dan bolalarni o'qiydi + har 60s ichki poll. Birinchi fetch
/// xatosi YUTILMAYDI (StreamProvider error → copyWithPrevious, dashboard
/// bo'sh "flash" bermaydi); poll xatolari skip (oxirgi qiymat saqlanadi).
Stream<List<Child>> _backendChildrenStream(Ref ref) async* {
  // MUHIM (zombi-guard): bekor qilingan async* generator faqat KEYINGI
  // yield'da to'xtaydi. Bu loop'da `continue`/dedup/catch yo'llari yield
  // QILMAYDI — guard'siz har recompute (resume tick, CRUD, pull-to-refresh)
  // eski generatorni YETIM qoldirib, u o'z Stream.periodic'i bilan abadiy
  // poll qilaverardi (logout'dan keyin — cheksiz 401). onDispose har
  // rebuild'da ham chaqiriladi → flag recompute'da ham ishonchli.
  var alive = true;
  ref.onDispose(() => alive = false);

  final repo = ref.watch(backendChildRepositoryProvider);

  // NET-07 (SWR): keshdagi oxirgi ro'yxat DARHOL ko'rsatiladi — cold
  // start'da dashboard server javobini kutib spinner'da turmaydi. Yangi
  // ma'lumot pastdagi fetch bilan keladi (farq bo'lsa UI yangilanadi).
  var current = const <Child>[];
  final cached = await repo.getCachedChildren();
  if (cached != null && cached.isNotEmpty) {
    current = cached;
    yield current;
  }

  try {
    final fresh = await repo.getChildren();
    if (current.isEmpty || !listEquals(fresh, current)) {
      current = fresh;
      yield fresh;
    }
  } catch (_) {
    // Kesh ko'rsatilgan bo'lsa — saqlanadi (offline UX); kesh ham yo'q
    // bo'lsa error'ni yuqoriga otamiz (dashboard error+retry ko'rsatadi).
    if (current.isEmpty) rethrow;
  }

  await for (final _
      in Stream<int>.periodic(const Duration(seconds: 60), (t) => t)) {
    if (!alive) return;
    // Ilova fonda — so'rov yubormaymiz (batareya + backend yuki).
    if (!isAppResumed(ref)) continue;
    try {
      final fresh = await repo.getChildren();
      if (!alive) return;
      // O'zgarmagan bo'lsa yield YO'Q — eski List identity qoladi,
      // watcher'lar rebuild bo'lmaydi (Child'da value-based == bor).
      if (!listEquals(fresh, current)) {
        current = fresh;
        yield fresh;
      }
    } catch (_) {
      // tarmoq blip — oxirgi qiymat saqlanadi, keyingi tick qayta uradi
    }
  }
}

/// Bolalar ro'yxati — sinxron access.
final childrenListProvider = Provider<List<Child>>((ref) {
  return ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
});

/// `id` bo'yicha bolani topish (sync).
final childByIdProvider = Provider.family<Child?, String>((ref, id) {
  return ref
      .watch(childrenListProvider)
      .firstWhereOrNull((c) => c.id == id);
});

/// Bola CRUD harakatlari uchun notifier.
class ChildActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ChildActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  BackendChildRepository get _repo =>
      _ref.read(backendChildRepositoryProvider);

  void _invalidateList() => _ref.invalidate(childrenProvider);

  void _invalidateAvatar(String childId) {
    _ref.invalidate(childAvatarUrlProvider(childId));
    // MEM-4 muhim: avatar proxy URL BARQAROR (childId-based, backend key
    // ham `child-avatars/<id>.<ext>`) — CachedNetworkImage disk-keshi
    // yangi rasm yuklangach ham ESKISINI ko'rsataverardi. Evict shart.
    unawaited(
      CachedNetworkImage.evictFromCache(_repo.avatarProxyUrl(childId)),
    );
  }

  /// Yangi bola qo'shish.
  Future<Result<Child>> addChild({
    required String name,
    required int age,
    required Gender gender,
    required String region,
    Uint8List? photoBytes,
    String? deviceModel,
    String? phoneNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      var child = await _repo.addChild(
        name: name,
        age: age,
        gender: gender,
        region: region,
        phoneNumber: phoneNumber,
      );
      if (photoBytes != null) {
        try {
          child = await _repo.uploadAvatar(child.id, photoBytes);
          _invalidateAvatar(child.id);
        } catch (e) {
          // Avatar upload xato — fotosiz davom etamiz (lekin log qoldiramiz).
          debugPrint('addChild: avatar upload xato: $e');
        }
      }
      state = const AsyncValue.data(null);
      _invalidateList();
      return Result.success(child);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(friendlyError(e));
    }
  }

  /// Bola ma'lumotlarini yangilash.
  Future<Result<void>> updateChild(
    String childId,
    Child updated, {
    Uint8List? newPhotoBytes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateChild(childId, updated);
      if (newPhotoBytes != null) {
        try {
          await _repo.uploadAvatar(childId, newPhotoBytes);
          _invalidateAvatar(childId);
        } catch (e) {
          // Avatar upload xato — metadata saqlangan, fotosiz (log qoldiramiz).
          debugPrint('updateChild: avatar upload xato: $e');
        }
      }
      state = const AsyncValue.data(null);
      _invalidateList();
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(friendlyError(e));
    }
  }

  /// Yangi pair-code generatsiya.
  Future<Result<String>> regenerateFamilyCode(String childId) async {
    state = const AsyncValue.loading();
    try {
      final newCode = await _repo.regenerateFamilyCode(childId);
      state = const AsyncValue.data(null);
      _invalidateList();
      return Result.success(newCode);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(friendlyError(e));
    }
  }

  /// Bolani o'chirish (Backend cascade delete).
  Future<Result<void>> deleteChild(String childId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteChild(childId);
      state = const AsyncValue.data(null);
      _invalidateList();
      return const Result<void>.success();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return Result.failure(friendlyError(e));
    }
  }
}

final childActionsProvider =
    StateNotifierProvider<ChildActionsNotifier, AsyncValue<void>>(
  ChildActionsNotifier.new,
);

/// Bola avatar URL — Backend rasm proxy (`/children/:id/avatar/image`).
///
/// Tarmoq so'rovisiz: bola `photoUrl` (backend `photoPath` bayrog'i) bor
/// bo'lsa barqaror proxy URL quriladi, aks holda `null` (default sticker).
/// Proxy MinIO'dan rasmni stream qiladi — signed URL'dan ishonchliroq
/// (telefon ichki MinIO endpointiga ulanolmaydi).
final childAvatarUrlProvider =
    FutureProvider.family<String?, String>((ref, childId) async {
  final backendAuth = ref.watch(backendAuthProvider);
  if (backendAuth is! AuthAuthenticated) return null;
  final child = ref.watch(childByIdProvider(childId));
  if (child == null || child.photoUrl == null) return null;
  final repo = ref.watch(backendChildRepositoryProvider);
  return repo.avatarProxyUrl(childId);
});
