import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Emits `true` when offline, `false` when online.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit() : super(false) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _init() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      emit(_isOffline(initial));
    } catch (_) {
      emit(false);
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) => emit(_isOffline(results)),
      onError: (_) => emit(false),
    );
  }

  static bool _isOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return true;
    }
    return results.every((r) => r == ConnectivityResult.none);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
