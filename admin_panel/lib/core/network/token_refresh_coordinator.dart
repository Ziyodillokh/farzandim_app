import 'dart:async';

/// Single in-flight refresh; parallel waiters share the same [Future].
final class TokenRefreshCoordinator {
  TokenRefreshCoordinator._();

  static Future<String?>? _inFlight;

  /// Runs [refresh] at most once concurrently; all callers await the same result.
  static Future<String?> runLocked(Future<String?> Function() refresh) {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final fut = refresh();
    _inFlight = fut;
    fut.whenComplete(() {
      if (identical(_inFlight, fut)) {
        _inFlight = null;
      }
    });
    return fut;
  }
}
