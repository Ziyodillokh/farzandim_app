// Kirish manbai. Ochiq yo'llar (login, birinchi sozlash, tiklash) — tokensiz
// alohida Dio bilan: odatiy Dio 401 da tokenni yangilab qayta urinadi, bu
// yerda esa 401 — «login yoki parol noto'g'ri». Maktabga ulanish va profil —
// bolaning o'z tokeni bilan (odatiy Dio).

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Qurilma tavsifi — sessiyalar ro'yxatida («Bu telefon», «Planshet»).
class DeviceDescriptor {
  const DeviceDescriptor({
    required this.id,
    required this.platform,
    this.model,
    this.hostsControl,
  });

  final String id;
  final String platform;
  final String? model;

  /// `false` — qurilmada boshqa bolaning ota-ona nazorati ishlaydi: server
  /// bu sessiyani asosiy (`MAIN`) qilmasin. `null` — yuborilmaydi.
  final bool? hostsControl;

  DeviceDescriptor withHostsControl(bool value) => DeviceDescriptor(
    id: id,
    platform: platform,
    model: model,
    hostsControl: value,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'platform': platform,
    'model': ?model,
    'hostsControl': ?hostsControl,
  };
}

abstract interface class KirishRepository {
  Future<LoginResult> login({
    required String login,
    required String password,
    required DeviceDescriptor device,
  });

  Future<ChildSession> completeSetup({
    required String setupToken,
    required String newPassword,
    required DeviceDescriptor device,
  });

  Future<RecoveryTicket> requestRecovery({
    required String login,
    required RecoveryChannel channel,
  });

  Future<RecoveryStatus> recoveryStatus(RecoveryTicket ticket);

  /// Bola tokeni bilan: ota-ona id'si (qurilmani egasi sifatida ulash uchun).
  Future<String?> parentIdOf(String childId);

  Future<LinkStatus> linkSchool(String code);

  Future<LinkStatus> linkStatus();

  Future<void> requestCorrection({
    required String note,
    required String clientRequestId,
  });

  Future<void> saveProfile({
    required int? age,
    required String gender,
    required EducationLanguage language,
  });

  /// Parolni almashtirish; serverda boshqa login sessiyalar yopiladi.
  /// Login berilmagan akkaunt (oila kodi) — [KirishError.noCredential].
  Future<void> changePassword({required String current, required String next});

  /// Shu qurilmadagi sessiyani yopish (faqat login sessiyasi).
  Future<void> logout();
}

class ApiKirishRepository implements KirishRepository {
  ApiKirishRepository({required Dio authed, Dio? public})
    : _authed = authed,
      _public = public ?? _plainDio();

  final Dio _authed;
  final Dio _public;

  static Dio _plainDio() => Dio(
    BaseOptions(
      baseUrl: EnvConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
    required DeviceDescriptor device,
  }) => _guard(() async {
    final res = await _public.post<Object?>(
      '/auth/child-login',
      data: {
        'login': login.trim().toLowerCase(),
        'password': password,
        'device': device.toJson(),
      },
    );
    return LoginResult.tryFromJson(res.data) ??
        (throw const KirishException(KirishError.unknown));
  });

  @override
  Future<ChildSession> completeSetup({
    required String setupToken,
    required String newPassword,
    required DeviceDescriptor device,
  }) => _guard(() async {
    final res = await _public.post<Object?>(
      '/auth/child-setup',
      data: {
        'setupToken': setupToken,
        'newPassword': newPassword,
        'device': device.toJson(),
      },
    );
    return ChildSession.tryFromJson(res.data) ??
        (throw const KirishException(KirishError.unknown));
  }, setup: true);

  @override
  Future<RecoveryTicket> requestRecovery({
    required String login,
    required RecoveryChannel channel,
  }) => _guard(() async {
    final res = await _public.post<Object?>(
      '/auth/child-recovery',
      data: {
        'login': login.trim().toLowerCase(),
        'channel': channel == RecoveryChannel.school ? 'SCHOOL' : 'PARENT',
      },
    );
    final data = res.data;
    final ticket = RecoveryTicket.tryFromJson(
      data is Map
          ? {
              ...data,
              'channel': channel == RecoveryChannel.school
                  ? 'SCHOOL'
                  : 'PARENT',
              'createdAt': DateTime.now().toIso8601String(),
            }
          : null,
    );
    return ticket ?? (throw const KirishException(KirishError.unknown));
  });

  @override
  Future<RecoveryStatus> recoveryStatus(RecoveryTicket ticket) =>
      _guard(() async {
        final res = await _public.get<Object?>(
          '/auth/child-recovery/${Uri.encodeComponent(ticket.requestId)}',
          queryParameters: {'token': ticket.pollToken},
        );
        return RecoveryStatus.tryFromJson(res.data) ??
            (throw const KirishException(KirishError.unknown));
      });

  @override
  Future<String?> parentIdOf(String childId) => _guard(() async {
    final res = await _authed.get<Object?>(
      '/children/${Uri.encodeComponent(childId)}',
    );
    final data = res.data;
    return data is Map ? jsonNonEmpty(data['parentId']) : null;
  });

  @override
  Future<LinkStatus> linkSchool(String code) => _guard(() async {
    final res = await _authed.post<Object?>(
      '/child/school/link',
      data: {'code': code},
    );
    return LinkStatus.fromJson(res.data);
  });

  @override
  Future<LinkStatus> linkStatus() => _guard(() async {
    final res = await _authed.get<Object?>('/child/school/link-status');
    return LinkStatus.fromJson(res.data);
  });

  @override
  Future<void> requestCorrection({
    required String note,
    required String clientRequestId,
  }) => _guard(() async {
    await _authed.post<Object?>(
      '/child/school/correction',
      data: {
        'reason': 'WRONG_SCHOOL_OR_CLASS',
        'note': note.trim(),
        'clientRequestId': clientRequestId,
      },
    );
  });

  @override
  Future<void> saveProfile({
    required int? age,
    required String gender,
    required EducationLanguage language,
  }) => _guard(() async {
    await _authed.put<Object?>(
      '/children/me',
      data: {'age': ?age, 'gender': gender, 'educationLanguage': language.name},
    );
  });

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) => _guard(() async {
    await _authed.post<Object?>(
      '/auth/child/password',
      data: {'currentPassword': current, 'newPassword': next},
    );
  });

  @override
  Future<void> logout() => _guard(() async {
    await _authed.post<Object?>('/auth/logout');
  });

  Future<T> _guard<T>(Future<T> Function() body, {bool setup = false}) async {
    try {
      return await body();
    } on DioException catch (e) {
      // Login/parol/kod hech qachon logga yozilmaydi — faqat yo'l va kod.
      debugPrint(
        '[kirish] ${e.requestOptions.path}: ${e.response?.statusCode}',
      );
      final data = e.response?.data;
      final code = data is Map ? data['code'] : null;
      final retry = data is Map ? jsonInt(data['retryAfterSeconds']) : null;
      final error = switch (e.response?.statusCode) {
        null => KirishError.network,
        401 when setup => KirishError.setupExpired,
        401 when code == 'TEMP_PASSWORD_EXPIRED' => KirishError.tempExpired,
        401 => KirishError.invalidCredentials,
        429 when code == 'LOCKED' => KirishError.locked,
        429 => KirishError.rateLimited,
        404 when code == 'CODE_INVALID' => KirishError.codeInvalid,
        // Tiklash holati: noto'g'ri id / token yoki o'chirilgan so'rov.
        404 when code == 'NOT_FOUND' => KirishError.notFound,
        404 when code == 'NO_CREDENTIAL' => KirishError.noCredential,
        409 when code == 'ALREADY_ENROLLED' => KirishError.alreadyEnrolled,
        // Faqat parol siyosati — boshqa 400 «zaif parol» emas.
        400 when code == 'WEAK_PASSWORD' => KirishError.weakPassword,
        // Parolni almashtirish: joriy parol noto'g'ri.
        400 when code == 'WRONG_PASSWORD' => KirishError.invalidCredentials,
        400 || 422 => KirishError.validation,
        _ => KirishError.unknown,
      };
      throw KirishException(
        error,
        retryAfter: retry == null || retry <= 0
            ? null
            : Duration(seconds: retry),
        passwordIssue: error == KirishError.weakPassword && data is Map
            ? PasswordIssue.fromWire(data['reason'])
            : null,
      );
    }
  }
}

final kirishRepositoryProvider = Provider<KirishRepository>(
  (ref) => ApiKirishRepository(authed: ref.watch(dioClientProvider)),
);
