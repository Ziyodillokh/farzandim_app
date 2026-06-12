// ─────────────────────────────────────────────────────────────────────
// polling — lifecycle-aware polling skaffoldining YAGONA manbasi
// ─────────────────────────────────────────────────────────────────────
//
// Avval bu skaffold (zombi-guard + Stream.periodic + isAppResumed skip +
// PollBackoff + SWR birinchi-yield + dedup) 5 ta provider'da copy-paste
// edi — har nusxada bir xil izohlar bilan. Endi bitta manba: xulq
// o'zgartirish bitta joyda, testlar ham shu yerda.

import 'dart:async';

import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/core/utils/poll_backoff.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Polling provayder uchun qisqa keep-alive (P0-1).
///
/// `autoDispose` watcher ketishi bilan provider'ni darhol o'ldiradi —
/// foydalanuvchi tez orqaga qaytsa loading "flash" bo'lardi. Qisqa
/// keep-alive: tez qaytishda kesh turadi, uzoq ketilsa polling BUTUNLAY
/// to'xtaydi (avval `autoDispose`siz ekran bir marta ochilgach polling
/// ILOVA UMRI DAVOMIDA davom etardi — 100k user'da minglab keraksiz RPS).
void keepAliveFor(Ref<dynamic> ref, Duration duration) {
  final link = ref.keepAlive();
  final timer = Timer(duration, link.close);
  ref.onDispose(timer.cancel);
}

/// Lifecycle-aware, backoff'li fetch-polling oqimi.
///
/// Oqim tartibi:
///   1. [readCache] (ixtiyoriy, SWR/NET-07) — keshdagi qiymat DARHOL yield
///      (cold start'da ekran spinner'da turmaydi); `null` → kesh yo'q.
///   2. Birinchi [fetch]:
///        - kesh ko'rsatilgan bo'lsa xato YUTILADI (offline UX — oxirgi
///          qiymat saqlanadi);
///        - kesh yo'q bo'lsa xato yuqoriga otiladi (provider error+retry
///          UI) — [swallowFirstError] `true` bundan mustasno (polling
///          keyin qayta uradi).
///   3. Har [interval]da poll: ilova FONDA bo'lsa so'rov yuborilmaydi
///      (batareya + backend yuki); ketma-ket xatolarda [PollBackoff]
///      kadansni siyraklashtiradi; xatoda yield YO'Q — oxirgi qiymat
///      saqlanadi.
///
/// [isSame] berilsa o'zgarmagan natija yield QILINMAYDI — AsyncData
/// identity saqlanib, barcha watcher'lar behuda rebuild'dan qutuladi
/// (element turida value-based `==` bo'lishi shart).
///
/// MUHIM (zombi-guard, ichkarida hal qilingan): bekor qilingan async*
/// generator faqat KEYINGI yield'da to'xtaydi — `continue`/dedup/catch
/// yo'llari yield qilmaydi, guard'siz har recompute eski generatorni
/// YETIM qoldirib, u abadiy poll qilaverardi (logout'dan keyin cheksiz
/// 401). `onDispose` har rebuild'da ham chaqiriladi → flag ishonchli.
Stream<T> pollFetchStream<T>(
  Ref<dynamic> ref, {
  required Duration interval,
  required Future<T> Function() fetch,
  Future<T?> Function()? readCache,
  bool Function(T prev, T next)? isSame,
  bool swallowFirstError = false,
}) async* {
  var alive = true;
  ref.onDispose(() => alive = false);

  var hasValue = false;
  late T last;
  bool changed(T next) =>
      !hasValue || isSame == null || !isSame(last, next);

  if (readCache != null) {
    final cached = await readCache();
    if (!alive) return;
    if (cached != null) {
      hasValue = true;
      last = cached;
      yield cached;
    }
  }

  try {
    final fresh = await fetch();
    if (!alive) return;
    if (changed(fresh)) {
      hasValue = true;
      last = fresh;
      yield fresh;
    }
  } catch (_) {
    if (!hasValue && !swallowFirstError) rethrow;
  }

  final backoff = PollBackoff();
  await for (final _ in Stream<void>.periodic(interval)) {
    if (!alive) return;
    if (!isAppResumed(ref)) continue;
    if (backoff.shouldSkipTick) continue;
    try {
      final fresh = await fetch();
      if (!alive) return;
      backoff.onSuccess();
      if (changed(fresh)) {
        hasValue = true;
        last = fresh;
        yield fresh;
      }
    } catch (_) {
      // tarmoq blip — backoff: ketma-ket xatolarda siyraklashadi
      backoff.onFailure();
    }
  }
}

/// Sof rebuild-"puls" oqimi — har [interval]da o'sib boruvchi son emit
/// qiladi, REFETCH QILMAYDI. `DateTime.now()` asosli getter'lar (masalan
/// `isLiveOnline`) timer'siz "muzlab" qolmasligi uchun watcher'larni
/// qayta build qildiradi. Fonda emit yo'q; dispose'da to'xtaydi
/// (zombi-guard [pollFetchStream]dagi kabi).
Stream<int> pollTickStream(Ref<dynamic> ref, Duration interval) async* {
  var alive = true;
  ref.onDispose(() => alive = false);
  var i = 0;
  yield i;
  await for (final _ in Stream<void>.periodic(interval)) {
    if (!alive) return;
    if (!isAppResumed(ref)) continue;
    yield ++i;
  }
}
