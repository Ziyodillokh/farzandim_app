// Bola joriy joylashuvi va manzili provider'lari.

import 'dart:async';

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/core/utils/app_lifecycle.dart';
import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/location/data/models/child_location.dart';
import 'package:farzandim/features/location/data/repositories/backend_location_repository.dart';
import 'package:farzandim/features/location/data/services/geocoding_service.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola joriy joylashuvi — 4 kanal birga ishlaydi:
///   1. boshlang'ich REST fetch (xato bo'lsa provider error — retry UI);
///   2. WS `location:updated` jonli oqim;
///   3. WS qayta ulanganda REST resync (uzilish davrida o'tkazib
///      yuborilganlar tiklanadi) — avval bu yo'q edi va socket bir uzilsa
///      xarita ilova qayta ochilmaguncha muzlab qolardi;
///   4. socket uzuq bo'lsa 30s polling fallback + ilova resume'ida resync.
final childLocationProvider = StreamProvider.autoDispose
    .family<ChildLocation?, String>((ref, childId) async* {
      final isAuthed = ref.watch(
        backendAuthProvider.select((s) => s is AuthAuthenticated),
      );
      if (!isAuthed) {
        yield null;
        return;
      }
      // Ekrandan tez qaytishda qayta fetch bo'lmasin, uzoq ketilsa esa
      // obuna/polling butunlay to'xtasin.
      keepAliveFor(ref, const Duration(minutes: 2));
      var alive = true;
      ref.onDispose(() => alive = false);

      final repo = ref.watch(backendLocationRepositoryProvider);
      final socket = ref.watch(socketClientProvider);

      final controller = StreamController<ChildLocation?>();
      ChildLocation? last;
      // Eski/dublikat nuqta yangisini bosib ketmasin.
      void push(ChildLocation? loc) {
        if (!alive || controller.isClosed) return;
        if (loc == null) {
          if (last == null) controller.add(null);
          return;
        }
        if (last != null && loc.updatedAt.isBefore(last!.updatedAt)) return;
        last = loc;
        controller.add(loc);
      }

      Future<void> resync() async {
        try {
          push(await repo.getLatest(childId));
        } catch (_) {
          // oxirgi qiymat saqlanadi, keyingi kanal qayta uradi
        }
      }

      final wsSub = repo.locationEvents(childId).listen(push);
      // Socket qayta ulandi — uzilish davrida o'tkazib yuborilganni olamiz.
      final stateSub = socket.stateStream.listen((s) {
        if (s == SocketConnectionState.connected) unawaited(resync());
      });
      // Fondan qaytganda ham yangilaymiz.
      final lifecycleSub = ref.listen<AppLifecycleState>(appLifecycleProvider, (
        prev,
        next,
      ) {
        if (next == AppLifecycleState.resumed &&
            prev != AppLifecycleState.resumed) {
          unawaited(resync());
        }
      });
      // Socket uzuq paytda 30s polling — jonli oqimsiz ham xarita yuradi.
      final pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!alive || !isAppResumed(ref)) return;
        if (socket.state == SocketConnectionState.connected) return;
        unawaited(resync());
      });

      ref.onDispose(() {
        pollTimer.cancel();
        unawaited(wsSub.cancel());
        unawaited(stateSub.cancel());
        lifecycleSub.close();
        unawaited(controller.close());
      });

      // Boshlang'ich nuqta: xato bo'lsa va hali hech narsa yo'q bo'lsa —
      // provider error (ekran retry ko'rsatadi); 404 esa null (bola hali
      // lokatsiya yubormagan).
      try {
        push(await repo.getLatest(childId));
      } catch (e) {
        if (last == null) rethrow;
      }

      yield* controller.stream;
    });

/// Bola joriy joylashuvi manzili (reverse geocoding) — joylashuv
/// o'zgarganda avtomatik qayta hisoblanadi. Kalit yo'q / xato bo'lsa
/// `null` (UI koordinata yoki "Noma'lum joylashuv" ko'rsatadi).
final childAddressProvider = FutureProvider.family<String?, String>((
  ref,
  childId,
) async {
  final loc = ref.watch(childLocationProvider(childId)).valueOrNull;
  if (loc == null) return null;
  return ref
      .watch(geocodingServiceProvider)
      .reverse(loc.latitude, loc.longitude);
});
