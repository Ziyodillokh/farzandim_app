// ─────────────────────────────────────────────────────────────────────
// NotificationsPoller — bildirishnomalar ro'yxatini yangilab turish
// ─────────────────────────────────────────────────────────────────────
//
// Avval: har 15 s GET /notifications (~240/soat), ilova fonda ham —
// provider hech qachon yopilmasdi; tarmoq xatosida ro'yxat va nishon
// bo'shab qolardi. Endi:
//   • ekranda: birinchi yuklash + WS `notification:*` hodisalarida darhol
//     yangilash + kamdan-kam zaxira so'rov (WS uzilgan bo'lsa ham eskirmasin);
//   • fonda: so'rov YO'Q; ilova qaytganda darhol yangilanadi;
//   • xato: oxirgi ma'lum ro'yxat saqlanadi (hech narsa yuklanmagan bo'lsa
//     xato chiqariladi — UI cheksiz "yuklanmoqda"da qolmasin).

import 'dart:async';

import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:flutter/foundation.dart';

/// Zaxira so'rov oralig'i (asosiy yangilanish — WS hodisalari).
const kNotificationsFallbackPoll = Duration(minutes: 2);

/// Ro'yxat hali bir marta ham yuklanmadi va so'rov muvaffaqiyatsiz.
class NotificationsUnavailable implements Exception {
  const NotificationsUnavailable();

  @override
  String toString() => 'NotificationsUnavailable';
}

class NotificationsPoller {
  NotificationsPoller({
    required Future<List<AppNotification>?> Function() fetch,
    Duration interval = kNotificationsFallbackPoll,
  }) : _fetch = fetch,
       _interval = interval;

  /// `null` — so'rov muvaffaqiyatsiz (ro'yxat bo'sh degani emas).
  final Future<List<AppNotification>?> Function() _fetch;
  final Duration _interval;

  final _controller = StreamController<List<AppNotification>>();
  Timer? _timer;
  bool _isActive = false;
  bool _hasData = false;
  bool _isFetching = false;
  bool _isRerunRequested = false;
  bool _isDisposed = false;

  Stream<List<AppNotification>> get stream => _controller.stream;

  /// Ilova ekranda (`true`) — darhol yangilash va zaxira so'rov; fonda
  /// (`false`) — hech qanday so'rov yo'q.
  void setActive(bool isActive) {
    if (_isDisposed || isActive == _isActive) return;
    _isActive = isActive;
    _timer?.cancel();
    _timer = null;
    if (!isActive) return;
    unawaited(refresh());
    _timer = Timer.periodic(_interval, (_) => unawaited(refresh()));
  }

  /// Darhol yangilash (WS hodisasi). Fonda — e'tiborsiz (qaytganda baribir
  /// yangilanadi). Parallel chaqiruvlar bitta so'rovga birlashadi.
  Future<void> refresh() async {
    if (_isDisposed || !_isActive) return;
    if (_isFetching) {
      _isRerunRequested = true;
      return;
    }
    _isFetching = true;
    try {
      do {
        _isRerunRequested = false;
        await _fetchOnce();
      } while (_isRerunRequested && _isActive && !_isDisposed);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _fetchOnce() async {
    List<AppNotification>? items;
    try {
      items = await _fetch();
    } catch (e) {
      debugPrint('NotificationsPoller: $e');
    }
    if (_isDisposed) return;
    if (items != null) {
      _hasData = true;
      _controller.add(items);
      return;
    }
    if (!_hasData) _controller.addError(const NotificationsUnavailable());
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_controller.close());
  }
}
