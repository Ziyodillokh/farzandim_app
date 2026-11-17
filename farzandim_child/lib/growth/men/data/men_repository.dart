// «Men» manbai: DON daftari, nishonlar, haftalik faollik, bildirishnoma
// sozlamalari, ma'lumotni o'chirish so'rovi va rozilik sanasi (bola o'z
// hisobi bilan). 404 — server bu imkoniyatni hali bilmaydi: ekranlar uni
// «ma'lumot yo'q» deb ko'rsatadi, xato emas.

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:flutter/foundation.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Server bu yo'lni bilmaydi (404) yoki bola juftlanmagan.
class MenUnavailable implements Exception {
  const MenUnavailable();
}

abstract interface class MenRepository {
  Future<DonLedgerPage> loadLedger({String? cursor});

  Future<List<BadgeState>> loadBadges();

  Future<WeeklyActivity> loadWeekly();

  Future<NotificationPrefs> loadNotificationPrefs();

  Future<NotificationPrefs> saveNotificationPrefs(NotificationPrefs prefs);

  Future<DeletionRequest?> latestDeletionRequest();

  Future<DeletionRequest> requestDeletion();

  /// Ota-ona qurilmani ulagan (rozilik bergan) sana.
  Future<DateTime?> consentDate();
}

class ApiMenRepository implements MenRepository {
  ApiMenRepository(this._dio, this._childId);

  final Dio _dio;
  final String? _childId;

  String get _child {
    final id = _childId;
    if (id == null) throw const MenUnavailable();
    return '/children/${Uri.encodeComponent(id)}';
  }

  @override
  Future<DonLedgerPage> loadLedger({String? cursor}) => _guard(() async {
    final res = await _dio.get<Object?>(
      '$_child/don-ledger',
      queryParameters: {'limit': 50, 'cursor': ?cursor},
    );
    return DonLedgerPage.fromJson(res.data);
  });

  @override
  Future<List<BadgeState>> loadBadges() => _guard(() async {
    final res = await _dio.get<Object?>('$_child/badges');
    final data = res.data;
    return jsonList(data is Map ? data['items'] : null, BadgeState.tryFromJson);
  });

  @override
  Future<WeeklyActivity> loadWeekly() => _guard(() async {
    final res = await _dio.get<Object?>('/learning/weekly');
    return WeeklyActivity.fromJson(res.data);
  });

  @override
  Future<NotificationPrefs> loadNotificationPrefs() => _guard(() async {
    final res = await _dio.get<Object?>('$_child/notification-preferences');
    return NotificationPrefs.fromJson(res.data);
  });

  @override
  Future<NotificationPrefs> saveNotificationPrefs(NotificationPrefs prefs) =>
      _guard(() async {
        final res = await _dio.put<Object?>(
          '$_child/notification-preferences',
          data: prefs.toJson(),
        );
        return NotificationPrefs.fromJson(res.data);
      });

  @override
  Future<DeletionRequest?> latestDeletionRequest() => _guard(() async {
    final res = await _dio.get<Object?>('$_child/deletion-requests/latest');
    return DeletionRequest.tryFromJson(res.data);
  });

  @override
  Future<DeletionRequest> requestDeletion() => _guard(() async {
    final res = await _dio.post<Object?>('$_child/deletion-requests');
    return DeletionRequest.tryFromJson(res.data) ??
        (throw const FormatException('deletion request'));
  });

  @override
  Future<DateTime?> consentDate() => _guard(() async {
    final res = await _dio.get<Object?>(_child);
    final data = res.data;
    return data is Map ? jsonInstant(data['pairedAt']) : null;
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      debugPrint('[men] ${e.requestOptions.path}: ${e.response?.statusCode}');
      if (e.response?.statusCode == 404) throw const MenUnavailable();
      rethrow;
    }
  }
}

final menRepositoryProvider = Provider<MenRepository>(
  (ref) => ApiMenRepository(
    ref.watch(dioClientProvider),
    ref.watch(pairingStateProvider.select((s) => s.childId)),
  ),
);

/// 404 → `null` (ekran «ma'lumot yo'q» holatini ko'rsatadi).
Future<T?> _orNull<T>(Future<T> future) async {
  try {
    return await future;
  } on MenUnavailable {
    return null;
  }
}

final donLedgerProvider = FutureProvider.autoDispose<DonLedgerPage?>((
  ref,
) async {
  final page = await _orNull(ref.watch(menRepositoryProvider).loadLedger());
  if (page == null || kShowAudioVideo) return page;
  return DonLedgerPage(
    balance: page.balance,
    pending: page.pending,
    items: [
      for (final e in page.items)
        if (e.kind != DonKind.book && e.kind != DonKind.video) e,
    ],
    nextCursor: page.nextCursor,
  );
});

final badgesProvider = FutureProvider.autoDispose<List<BadgeState>?>(
  (ref) => _orNull(ref.watch(menRepositoryProvider).loadBadges()),
);

final weeklyActivityProvider = FutureProvider.autoDispose<WeeklyActivity?>(
  (ref) => _orNull(ref.watch(menRepositoryProvider).loadWeekly()),
);

final notificationPrefsProvider =
    FutureProvider.autoDispose<NotificationPrefs?>(
      (ref) =>
          _orNull(ref.watch(menRepositoryProvider).loadNotificationPrefs()),
    );

final latestDeletionRequestProvider =
    FutureProvider.autoDispose<DeletionRequest?>(
      (ref) => _orNull<DeletionRequest?>(
        ref.watch(menRepositoryProvider).latestDeletionRequest(),
      ),
    );

final consentDateProvider = FutureProvider.autoDispose<DateTime?>(
  (ref) => _orNull<DateTime?>(ref.watch(menRepositoryProvider).consentDate()),
);
