// ─────────────────────────────────────────────────────────────────────
// sos_provider — SosService Riverpod state
// ─────────────────────────────────────────────────────────────────────
//
// SosNotifier 4 ta holatni boshqaradi: idle / sending / sent / error.
// SosButton shu state'ni kuzatib visual feedback ko'rsatadi.
//
// SOS bosilganda **joriy joylashuv** ham backend'ga yuboriladi —
// ota-onaga kelgan push xabarda Google Maps havolasi bo'lishi uchun.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/sos/data/repositories/backend_sos_repository.dart';

enum SosStatus { idle, sending, sent, error }

class SosState {
  const SosState({
    this.status = SosStatus.idle,
    this.errorMessage,
    this.lastAlertId,
  });

  final SosStatus status;
  final String? errorMessage;
  final String? lastAlertId;

  SosState copyWith({
    SosStatus? status,
    String? errorMessage,
    String? lastAlertId,
  }) {
    return SosState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastAlertId: lastAlertId ?? this.lastAlertId,
    );
  }
}

final sosStateProvider =
    StateNotifierProvider<SosNotifier, SosState>(SosNotifier.new);

class SosNotifier extends StateNotifier<SosState> {
  SosNotifier(this._ref) : super(const SosState());

  final Ref _ref;

  /// SOS yuborish — Backend POST /api/children/:childId/sos-alerts.
  /// Backend o'zi parent'ga FCM HIGH priority push + WS event yuboradi.
  ///
  /// Joriy joylashuv ham birga yuboriladi:
  ///   1) `getLastKnownPosition()` — bir lahzada qaytadi (kesh)
  ///   2) `getCurrentPosition()` — 3 sek timeout, agar kesh yo'q bo'lsa
  ///   3) Hech qaysisi bo'lmasa — null bilan davom etamiz (SOS to'xtamaydi)
  Future<void> send() async {
    final pairing = _ref.read(pairingStateProvider);
    if (!pairing.isPaired || pairing.childId == null) {
      state = state.copyWith(
        status: SosStatus.error,
        errorMessage: 'Ulanmagan',
      );
      return;
    }

    state = state.copyWith(status: SosStatus.sending);

    // Joylashuv: SOS uchun **tezlik** muhim, GPS fix kutmaymiz.
    final pos = await _resolveCurrentPosition();

    try {
      final id = await _ref.read(backendSosRepositoryProvider).triggerAlert(
            childId: pairing.childId!,
            latitude: pos?.latitude,
            longitude: pos?.longitude,
            accuracy: pos?.accuracy,
          );
      if (id == null) {
        state = state.copyWith(
          status: SosStatus.error,
          errorMessage: 'Backend SOS yuborilmadi',
        );
        return;
      }
      state = state.copyWith(
        status: SosStatus.sent,
        lastAlertId: id,
      );
    } catch (e) {
      state = state.copyWith(
        status: SosStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Joriy joylashuvni tezda olishga harakat qiladi.
  /// SOS — hayot/o'lim, sekundlar muhim → kesh birinchi, GPS keyin.
  Future<Position?> _resolveCurrentPosition() async {
    // 1) Kesh — faqat YANGI bo'lsa (≤2 daqiqa) ishonamiz. Avval har qanday
    //    (hatto soatlab eski) kesh darhol qaytarilardi → bola oxirgi fix'dan
    //    keyin ancha yo'l bosgan bo'lsa, parent NOTO'G'RI joyga yuborilardi
    //    (SOS — hayot/o'lim). LocationService.start() ham freshness guard
    //    ishlatadi (u yerda 10 daqiqa).
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().toUtc().difference(last.timestamp.toUtc()) <=
              const Duration(minutes: 2)) {
        return last;
      }
    } catch (e) {
      debugPrint('SOS getLastKnownPosition xato: $e');
    }
    // 2) Fresh fix — 3 sek timeout (SOS push'ni kechiktirmasin).
    try {
      final fresh = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      return fresh;
    } catch (e) {
      debugPrint('SOS getCurrentPosition xato: $e');
    }
    // 3) Fresh fix bo'lmadi (GPS o'chiq/timeout) — eski bo'lsa ham oxirgi
    //    ma'lum joy hech nimadan yaxshiroq (SOS hech bo'lmasa taxminiy joyni
    //    yuborsin).
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  void reset() {
    state = const SosState();
  }
}
