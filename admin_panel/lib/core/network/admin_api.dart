import 'dart:convert';

import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'api_client.dart';
import 'dio_error_mapper.dart';

class LoginResult {
  const LoginResult({
    this.accessToken,
    this.refreshToken,
    this.staff,
    this.requires2fa = false,
    this.challengeId,
    this.maskedPhone,
  });

  final String? accessToken;
  final String? refreshToken;

  /// `POST /auth/login` may include `user` for staff (admin panel).
  final Map<String, dynamic>? staff;

  /// Set when the server requires SMS 2FA before issuing a token.
  final bool requires2fa;
  final String? challengeId;
  final String? maskedPhone;
}

class AdminUsersPageResult {
  const AdminUsersPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
  final int total;
}

class AdminVideosPageResult {
  const AdminVideosPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
  final int total;
}

class AdminAudiobooksPageResult {
  const AdminAudiobooksPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
  final int total;
}

class AdminBooksPageResult {
  const AdminBooksPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
  final int total;
}

class AdminOlympiadsPageResult {
  const AdminOlympiadsPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
  final int total;
}

class AdminModeratorsPageResult {
  const AdminModeratorsPageResult({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
  final int total;
}

class AdminApi {
  AdminApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<LoginResult> login(String email, String password) async {
    try {
      final response = await _guard(
        () => _client.post(
          '/admin/auth/login',
          data: {'email': email, 'password': password},
        ),
      );
      final data = response.data ?? {};

      // 2FA challenge response
      if (data['requires2fa'] == true) {
        return LoginResult(
          requires2fa: true,
          challengeId: data['challengeId']?.toString(),
          maskedPhone: data['maskedPhone']?.toString(),
        );
      }

      final access =
          data['access_token'] as String? ?? data['accessToken'] as String?;
      if (access == null || access.isEmpty) {
        throw StateError('Missing access_token in login response');
      }
      final refresh =
          data['refresh_token'] as String? ?? data['refreshToken'] as String?;
      final u = data['user'];
      final staff = u is Map ? Map<String, dynamic>.from(u) : null;
      return LoginResult(
        accessToken: access,
        refreshToken: refresh,
        staff: staff,
      );
    } on Object catch (e, st) {
      AppLogger.error('admin login', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Sprint 5.x — 2FA TOTP management.
  Future<Map<String, dynamic>> twoFactorStatus() async {
    final res = await _guard(() => _client.get('/admin/auth/2fa/status'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// `/2fa/setup` — yangi secret + otpauth URI qaytaradi (hali enable emas).
  Future<Map<String, dynamic>> twoFactorSetup() async {
    final res = await _guard(() => _client.post('/admin/auth/2fa/setup'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// `/2fa/enable` — initial code'ni tasdiqlash, backup codes qaytariladi.
  Future<Map<String, dynamic>> twoFactorEnable(String code) async {
    final res = await _guard(
      () => _client.post('/admin/auth/2fa/enable', data: {'code': code}),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// `/2fa/disable` — password + (agar enabled bo'lsa) TOTP/backup kod.
  Future<void> twoFactorDisable({
    required String password,
    String? code,
  }) async {
    await _guard(
      () => _client.post(
        '/admin/auth/2fa/disable',
        data: {'password': password, 'code': ?code},
      ),
    );
  }

  /// Sprint 5.x — Audit log read.
  Future<Map<String, dynamic>> fetchAuditLog({
    int page = 1,
    int limit = 50,
    String? action,
    String? resourceType,
    String? status,
    String? from,
    String? to,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/audit-log',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (action != null && action.isNotEmpty) 'action': action,
          if (resourceType != null && resourceType.isNotEmpty) 'resourceType': resourceType,
          if (status != null && status.isNotEmpty) 'status': status,
          'from': ?from,
          'to': ?to,
        },
      ),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<List<String>> fetchAuditActions() async {
    final res = await _guard(() => _client.get('/admin/audit-log/actions'));
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    final list = (data['actions'] as List?)?.cast<dynamic>() ?? const [];
    return list.map((e) => e.toString()).toList();
  }

  /// Verifies 2FA OTP and returns a full LoginResult with tokens.
  Future<LoginResult> verify2fa({
    required String challengeId,
    required String code,
  }) async {
    try {
      final response = await _guard(
        () => _client.post(
          '/admin/auth/2fa/verify',
          data: {'challengeId': challengeId, 'code': code},
        ),
      );
      final data = response.data ?? {};
      final access =
          data['access_token'] as String? ?? data['accessToken'] as String?;
      if (access == null || access.isEmpty) {
        throw StateError('Missing access_token in 2FA verify response');
      }
      final u = data['user'];
      final staff = u is Map ? Map<String, dynamic>.from(u) : null;
      return LoginResult(
        accessToken: access,
        refreshToken:
            data['refresh_token'] as String? ?? data['refreshToken'] as String?,
        staff: staff,
      );
    } on Object catch (e, st) {
      AppLogger.error('admin 2fa verify', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// H7 — server tomonda sessiyani tugatadi: tokenVersion++ va refresh
  /// HttpOnly cookie'sini tozalaydi. Tarmoq xatosi logout'ni to'xtatmaydi.
  Future<void> logout() async {
    try {
      await _client.post('/admin/auth/logout');
    } catch (e, st) {
      AppLogger.warning('admin logout request failed', e);
      AppLogger.debug('logout trace', st);
    }
  }

  Future<Map<String, dynamic>> fetchStaffMe() async {
    final res = await _guard(() => _client.get('/admin/auth/staff-me'));
    final d = res.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    return {};
  }

  Future<AdminModeratorsPageResult> fetchModerators({
    String? q,
    String? role,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/moderators',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (role != null && role.isNotEmpty) 'role': role,
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page,
          'limit': limit,
        },
      ),
    );
    final data = res.data;
    if (data is! Map) {
      return const AdminModeratorsPageResult(
        items: [],
        page: 1,
        totalPages: 1,
        total: 0,
      );
    }
    final map = data.cast<String, dynamic>();
    final raw = (map['items'] ?? []) as List<dynamic>;
    final items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pageN = (map['page'] as num?)?.toInt() ?? page;
    final totalPages = (map['totalPages'] as num?)?.toInt() ?? 1;
    final total = (map['total'] as num?)?.toInt() ?? items.length;
    return AdminModeratorsPageResult(
      items: items,
      page: pageN,
      totalPages: totalPages,
      total: total,
    );
  }

  Future<Map<String, dynamic>> getModerator(String id) async {
    final res = await _guard(() => _client.get('/admin/moderators/$id'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> createModerator(
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.post('/admin/moderators', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> updateModerator(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.patch('/admin/moderators/$id', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> blockModerator(String id) async {
    await _guard(() => _client.post('/admin/moderators/$id/block'));
  }

  Future<void> unblockModerator(String id) async {
    await _guard(() => _client.post('/admin/moderators/$id/unblock'));
  }

  Future<void> deleteModerator(String id) async {
    await _guard(
      () => _client.delete('/admin/moderators/$id', data: const <String, dynamic>{}),
    );
  }

  Future<Map<String, dynamic>> getDashboard({
    DateTime? from,
    DateTime? to,
  }) async {
    final q = <String, dynamic>{};
    if (from != null) q['from'] = from.toIso8601String();
    if (to != null) q['to'] = to.toIso8601String();
    final res = await _guard(
      () => _client.get(
        '/admin/dashboard',
        queryParameters: q.isEmpty ? null : q,
      ),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<List<dynamic>> getUsers() async {
    final r = await fetchUsers();
    return r.items;
  }

  /// Ota-onalar + bolalar (server filtrlash va pagination).
  Future<AdminUsersPageResult> fetchUsers({
    String? q,
    String? role,
    String? status,
    String? plan,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/users',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (role != null && role.isNotEmpty) 'role': role,
          if (status != null && status.isNotEmpty) 'status': status,
          if (plan != null && plan.isNotEmpty) 'plan': plan,
          'page': page,
          'limit': limit,
        },
      ),
    );
    final data = res.data;
    if (data is! Map) {
      return const AdminUsersPageResult(
        items: [],
        page: 1,
        totalPages: 1,
        total: 0,
      );
    }
    final map = data.cast<String, dynamic>();
    final raw = (map['items'] ?? []) as List<dynamic>;
    final items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pag = map['pagination'] as Map?;
    final pageN = (pag?['page'] as num?)?.toInt() ?? page;
    final totalPages = (pag?['totalPages'] as num?)?.toInt() ?? 1;
    final total = (pag?['total'] as num?)?.toInt() ?? items.length;
    return AdminUsersPageResult(
      items: items,
      page: pageN,
      totalPages: totalPages,
      total: total,
    );
  }

  Future<Map<String, dynamic>> getUserById(String id) async {
    final res = await _guard(() => _client.get('/admin/users/$id'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> getChildProfile(String id) async {
    final res = await _guard(() => _client.get('/admin/child-profiles/$id'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<AdminVideosPageResult> fetchVideos({
    String? q,
    String? status,
    String? categoryId,
    String? planRequired,
    String? level,
    int? ageFrom,
    int? ageTo,
    int page = 1,
    int limit = 10,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/videos',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (categoryId != null && categoryId.isNotEmpty)
            'categoryId': categoryId,
          if (planRequired != null && planRequired.isNotEmpty)
            'planRequired': planRequired,
          if (level != null && level.isNotEmpty) 'level': level,
          'ageFrom': ?ageFrom,
          'ageTo': ?ageTo,
          'page': page,
          'limit': limit,
        },
      ),
    );
    final data = res.data;
    if (data is! Map) {
      return const AdminVideosPageResult(
        items: [],
        page: 1,
        totalPages: 1,
        total: 0,
      );
    }
    final map = data.cast<String, dynamic>();
    final raw = (map['items'] ?? []) as List<dynamic>;
    final items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pag = map['pagination'] as Map?;
    final pageN = (pag?['page'] as num?)?.toInt() ?? page;
    final totalPages = (pag?['totalPages'] as num?)?.toInt() ?? 1;
    final total = (pag?['total'] as num?)?.toInt() ?? items.length;
    return AdminVideosPageResult(
      items: items,
      page: pageN,
      totalPages: totalPages,
      total: total,
    );
  }

  Future<List<Map<String, dynamic>>> fetchVideoCategories() async {
    final res = await _guard(
      () =>
          _client.get('/admin/categories', queryParameters: {'kind': 'video'}),
    );
    final raw = res.data;
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAudiobookCategories() async {
    final res = await _guard(
      () => _client.get(
        '/admin/categories',
        queryParameters: {'kind': 'audiobook'},
      ),
    );
    final raw = res.data;
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Multipart upload: `videoFile`, optional `thumbnailFile`, `metadata` JSON string.
  Future<Map<String, dynamic>> uploadVideo({
    required MultipartFile videoFile,
    MultipartFile? thumbnailFile,
    required Map<String, dynamic> metadata,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'videoFile': videoFile,
      'thumbnailFile': ?thumbnailFile,
      'metadata': jsonEncode(metadata),
    });
    final res = await _guard(
      () => _client.postWithoutGlobalLoading(
        '/admin/videos/upload',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 25),
          receiveTimeout: const Duration(minutes: 3),
        ),
        onSendProgress: onSendProgress,
      ),
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> createVideo({
    required String title,
    required String url,
    String? thumbnail,
    String? description,
    int? durationSec,
    required int ageFrom,
    required int ageTo,
    String? categoryId,
    String planRequired = 'free',
    String status = 'hidden',
    bool featured = false,
  }) async {
    final res = await _guard(
      () => _client.post(
        '/admin/videos/create',
        data: {
          'title': title,
          'url': url,
          if (thumbnail != null && thumbnail.trim().isNotEmpty)
            'thumbnail': thumbnail.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'durationSec': ?durationSec,
          'ageFrom': ageFrom,
          'ageTo': ageTo,
          if (categoryId != null && categoryId.isNotEmpty)
            'categoryId': categoryId,
          'planRequired': planRequired,
          'status': status,
          'featured': featured,
        },
      ),
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> approveVideo(String id) async {
    await _guard(() => _client.patch('/admin/videos/$id/approve', data: const {}));
  }

  Future<void> rejectVideo(String id) async {
    await _guard(() => _client.patch('/admin/videos/$id/reject', data: const {}));
  }

  Future<void> deleteVideo(String id) async {
    await _guard(
      () => _client.delete('/admin/videos/$id', data: const <String, dynamic>{}),
    );
  }

  Future<void> patchVideo(String id, {bool? featured, String? status}) async {
    await _guard(
      () => _client.patch(
        '/admin/videos/$id',
        data: {'featured': ?featured, 'status': ?status},
      ),
    );
  }

  Future<void> bulkVideos(List<String> ids, String action) async {
    await _guard(
      () => _client.post(
        '/admin/videos/bulk',
        data: {'ids': ids, 'action': action},
      ),
    );
  }

  Future<AdminAudiobooksPageResult> fetchAudiobooks({
    String? q,
    String? status,
    String? categoryId,
    String? planRequired,
    int? ageFrom,
    int? ageTo,
    int page = 1,
    int limit = 10,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/audiobooks',
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (categoryId != null && categoryId.isNotEmpty)
            'categoryId': categoryId,
          if (planRequired != null && planRequired.isNotEmpty)
            'planRequired': planRequired,
          'ageFrom': ?ageFrom,
          'ageTo': ?ageTo,
          'page': page,
          'limit': limit,
        },
      ),
    );
    final data = res.data;
    if (data is! Map) {
      return const AdminAudiobooksPageResult(
        items: [],
        page: 1,
        totalPages: 1,
        total: 0,
      );
    }
    final map = data.cast<String, dynamic>();
    final raw = (map['items'] ?? []) as List<dynamic>;
    final items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pag = map['pagination'] as Map?;
    final pageN = (pag?['page'] as num?)?.toInt() ?? page;
    final totalPages = (pag?['totalPages'] as num?)?.toInt() ?? 1;
    final total = (pag?['total'] as num?)?.toInt() ?? items.length;
    return AdminAudiobooksPageResult(
      items: items,
      page: pageN,
      totalPages: totalPages,
      total: total,
    );
  }

  Future<Map<String, dynamic>> uploadAudiobook({
    required MultipartFile audioFile,
    MultipartFile? thumbnailFile,
    required Map<String, dynamic> metadata,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'audioFile': audioFile,
      'thumbnailFile': ?thumbnailFile,
      'metadata': jsonEncode(metadata),
    });
    final res = await _guard(
      () => _client.postWithoutGlobalLoading(
        '/admin/audiobooks/upload',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 25),
          receiveTimeout: const Duration(minutes: 3),
        ),
        onSendProgress: onSendProgress,
      ),
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> approveAudiobook(String id) async {
    await _guard(() => _client.patch('/admin/audiobooks/$id/approve', data: const {}));
  }

  Future<void> rejectAudiobook(String id) async {
    await _guard(() => _client.patch('/admin/audiobooks/$id/reject', data: const {}));
  }

  Future<void> deleteAudiobook(String id) async {
    await _guard(
      () => _client.delete('/admin/audiobooks/$id', data: const <String, dynamic>{}),
    );
  }

  Future<void> bulkAudiobooks(List<String> ids, String action) async {
    await _guard(
      () => _client.post(
        '/admin/audiobooks/bulk',
        data: {'ids': ids, 'action': action},
      ),
    );
  }

  // ─── Books / PDF ──────────────────────────────────────────────────────────

  Future<AdminBooksPageResult> fetchBooks({
    String? q,
    String? status,
    String? category,
    String? planRequired,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _guard(
      () => _client.get('/admin/books', queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
        if (category != null && category.isNotEmpty) 'category': category,
        if (planRequired != null && planRequired.isNotEmpty)
          'planRequired': planRequired,
        'page': page,
        'limit': limit,
      }),
    );
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    final items = (data['items'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final pag = (data['pagination'] as Map?)?.cast<String, dynamic>() ?? {};
    return AdminBooksPageResult(
      items: items,
      page: (pag['page'] as num?)?.toInt() ?? page,
      totalPages: (pag['totalPages'] as num?)?.toInt() ?? 1,
      total: (pag['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> createBook(Map<String, dynamic> body) async {
    final res = await _guard(
      () => _client.post('/admin/books/create', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Sprint 5.6d — Books PDF multipart upload.
  ///
  /// `pdfFile`: PDF (maks 50 MB).
  /// `coverFile`: optional cover image (maks 5 MB).
  /// `metadata`: title, author, description?, pages, ageFrom, ageTo,
  ///             category, planRequired, status.
  Future<Map<String, dynamic>> uploadBook({
    required MultipartFile pdfFile,
    MultipartFile? coverFile,
    required Map<String, dynamic> metadata,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'pdfFile': pdfFile,
      'coverFile': ?coverFile,
      'metadata': jsonEncode(metadata),
    });
    final res = await _guard(
      () => _client.postWithoutGlobalLoading(
        '/admin/books/upload',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 25),
          receiveTimeout: const Duration(minutes: 3),
        ),
        onSendProgress: onSendProgress,
      ),
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> updateBook(
      String id, Map<String, dynamic> body) async {
    final res = await _guard(
      () => _client.patch('/admin/books/$id', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> approveBook(String id) async {
    await _guard(() => _client.patch('/admin/books/$id/approve', data: const {}));
  }

  Future<void> rejectBook(String id) async {
    await _guard(() => _client.patch('/admin/books/$id/reject', data: const {}));
  }

  Future<void> deleteBook(String id) async {
    await _guard(
      () => _client.delete('/admin/books/$id', data: const <String, dynamic>{}),
    );
  }

  Future<Map<String, dynamic>> getVideoAnalytics() async {
    final res = await _guard(() => _client.get('/admin/analytics/videos'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> sendNotification({
    required String title,
    required String message,
    required String target,
  }) async {
    await _guard(
      () => _client.post(
        '/admin/notifications/send',
        data: {'title': title, 'message': message, 'target': target},
      ),
    );
  }

  Future<void> scheduleNotification({
    required String title,
    required String message,
    required String target,
    required DateTime scheduledAt,
  }) async {
    await _guard(
      () => _client.post(
        '/admin/notifications/schedule',
        data: {
          'title': title,
          'message': message,
          'target': target,
          'scheduledAt': scheduledAt.toIso8601String(),
        },
      ),
    );
  }

  Future<List<dynamic>> getNotificationHistory() async {
    final res = await _guard(() => _client.get('/admin/notifications/history'));
    return (res.data as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> getNotificationStats() async {
    final res = await _guard(() => _client.get('/admin/notifications/stats'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<List<Map<String, dynamic>>> listNotifications({
    String? q,
    String? status,
    String? audience,
    DateTime? from,
    DateTime? to,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/notifications',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (status != null && status.isNotEmpty) 'status': status,
          if (audience != null && audience.isNotEmpty) 'audience': audience,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
        },
      ),
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getNotification(String id) async {
    final res = await _guard(() => _client.get('/admin/notifications/$id'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> deleteNotification(String id) async {
    await _guard(
      () => _client.delete('/admin/notifications/$id', data: const <String, dynamic>{}),
    );
  }

  Future<Map<String, dynamic>> createNotification(
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.post('/admin/notifications', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Sprint 5.x — notification rasm uploadi. MinIO content-thumbs bucket'ga
  /// yuklab signed URL qaytaradi. Frontend qaytgan URL'ni `imageUrl` sifatida
  /// notification create body'siga uzatadi.
  Future<String> uploadNotificationImage(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    final res = await _guard(
      () => _client.post('/admin/notifications/upload-image', data: form),
    );
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    final url = data['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw StateError('Upload returned empty URL');
    }
    return url;
  }

  Future<List<Map<String, dynamic>>> aiGenerateNotifications() async {
    final res = await _guard(
      () => _client.post('/admin/notifications/ai-generate'),
    );
    final data = res.data;
    if (data is Map && data['suggestions'] is List) {
      return (data['suggestions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final res = await _guard(() => _client.get('/admin/analytics'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// GET /admin/analytics/monetization — obuna / to'lov tahlili (6 oy).
  Future<Map<String, dynamic>> getMonetizationAnalytics() async {
    final res = await _guard(
      () => _client.get('/admin/analytics/monetization'),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<AdminOlympiadsPageResult> listOlympiads({
    int page = 1,
    int limit = 20,
    String? q,
    String? status,
    String? subject,
    int? ageFrom,
    int? ageTo,
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/olympiads',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          'ageFrom': ?ageFrom,
          'ageTo': ?ageTo,
          if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        },
      ),
    );
    final m = res.data;
    if (m is! Map) {
      return const AdminOlympiadsPageResult(
        items: [],
        page: 1,
        totalPages: 1,
        total: 0,
      );
    }
    final items = (m['items'] as List?)?.cast<dynamic>() ?? const [];
    final p = m['pagination'] as Map?;
    return AdminOlympiadsPageResult(
      items: items.map((e) => (e as Map).cast<String, dynamic>()).toList(),
      page: (p?['page'] as num?)?.toInt() ?? 1,
      totalPages: (p?['totalPages'] as num?)?.toInt() ?? 1,
      total: (p?['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> getOlympiad(String id) async {
    final res = await _guard(() => _client.get('/admin/olympiads/$id'));
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<List<dynamic>> getOlympiadParticipants(String id) async {
    final res = await _guard(
      () => _client.get('/admin/olympiads/$id/participants'),
    );
    return (res.data as List?)?.cast<dynamic>() ?? [];
  }

  Future<List<dynamic>> getOlympiadLeaderboard(
    String id, {
    int page = 1,
    int limit = 200,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/olympiads/$id/leaderboard',
        queryParameters: {'page': page, 'limit': limit},
      ),
    );
    return (res.data as List?)?.cast<dynamic>() ?? [];
  }

  Future<Map<String, dynamic>> createOlympiad(Map<String, dynamic> body) async {
    final res = await _guard(
      () => _client.post('/admin/olympiads', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> updateOlympiad(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.patch('/admin/olympiads/$id', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> publishOlympiad(String id) async {
    final res = await _guard(
      () => _client.post(
        '/admin/olympiads/$id/publish',
        data: <String, dynamic>{},
      ),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> deleteOlympiad(String id) async {
    await _guard(
      () => _client.delete('/admin/olympiads/$id', data: const <String, dynamic>{}),
    );
  }

  Future<Map<String, dynamic>> unpublishOlympiad(String id) async {
    final res = await _guard(
      () => _client.post(
        '/admin/olympiads/$id/unpublish',
        data: <String, dynamic>{},
      ),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> addOlympiadQuestion(
    String olympiadId,
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.post('/admin/olympiads/$olympiadId/questions', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> updateOlympiadQuestion(
    String olympiadId,
    String questionId,
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.patch(
        '/admin/olympiads/$olympiadId/questions/$questionId',
        data: body,
      ),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> deleteOlympiadQuestion(
    String olympiadId,
    String questionId,
  ) async {
    await _guard(
      () =>
          _client.delete('/admin/olympiads/$olympiadId/questions/$questionId',
              data: const <String, dynamic>{}),
    );
  }

  // ─── Monetization (catalog, promos, payment history) ─────────────

  Future<List<Map<String, dynamic>>> listMonetizationPlans() async {
    final res = await _guard(() => _client.get('/admin/monetization/plans'));
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createMonetizationPlan(
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.post('/admin/monetization/plans', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> updateMonetizationPlan(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.patch('/admin/monetization/plans/$id', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> deleteMonetizationPlan(String id) async {
    final res = await _guard(
      () => _client.delete('/admin/monetization/plans/$id',
          data: const <String, dynamic>{}),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<List<Map<String, dynamic>>> listMonetizationPromocodes({
    String? q,
    String? planId,
    String? status,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/monetization/promocodes',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (planId != null && planId.isNotEmpty) 'planId': planId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      ),
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createMonetizationPromocode(
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.post('/admin/monetization/promocodes', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<Map<String, dynamic>> updateMonetizationPromocode(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _guard(
      () => _client.patch('/admin/monetization/promocodes/$id', data: body),
    );
    return (res.data as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> deleteMonetizationPromocode(String id) async {
    await _guard(
      () => _client.delete('/admin/monetization/promocodes/$id',
          data: const <String, dynamic>{}),
    );
  }

  Future<List<Map<String, dynamic>>> listMonetizationPayments({
    String? q,
    String? planId,
    String? method,
  }) async {
    final res = await _guard(
      () => _client.get(
        '/admin/monetization/payments',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (planId != null && planId.isNotEmpty) 'planId': planId,
          if (method != null && method.isNotEmpty) 'method': method,
        },
      ),
    );
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}
