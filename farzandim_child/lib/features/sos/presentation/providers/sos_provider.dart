// ─────────────────────────────────────────────────────────────────────
// sos_provider — SosService Riverpod state
// ─────────────────────────────────────────────────────────────────────
//
// SosNotifier 4 ta holatni boshqaradi: idle / sending / sent / error.
// SosButton shu state'ni kuzatib visual feedback ko'rsatadi.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    try {
      final id = await _ref.read(backendSosRepositoryProvider).triggerAlert(
            childId: pairing.childId!,
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

  void reset() {
    state = const SosState();
  }
}
