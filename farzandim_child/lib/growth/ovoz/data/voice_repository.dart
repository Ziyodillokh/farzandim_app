// Bola ovozi manbai (`/api/child/school/care/*`, CHILD token): anonim so'rov,
// mas'ul psixolog, murojaatlar va yozishma. Xatolar mavjud `SchoolException`
// ga aylanadi (404 → `unavailable`: endpoint yo'q yoki bola maktabga
// bog'lanmagan; 409 → `alreadyAnswered`: so'rovga javob berilgan yoki
// murojaat yopilgan).

import 'package:dio/dio.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/school_json.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:flutter/foundation.dart';
import 'package:farzandim_child/features/account/presentation/providers/language_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class VoiceRepository {
  Future<VoiceSurveyState> loadSurvey();

  /// [answers]: savol id → 1..5; o'tkazilgan savollar yuborilmaydi.
  Future<void> submitSurvey(String surveyId, Map<String, int> answers);

  Future<VoiceContact> loadContact();

  Future<List<VoiceRequestSummary>> loadRequests();

  Future<VoiceRequest> loadRequest(String id);

  /// [clientRequestId] bilan takroriy yuborish yangi murojaat ochmaydi.
  Future<VoiceRequest> createRequest({
    required String message,
    required bool urgent,
    required String clientRequestId,
  });

  Future<VoiceMessage> sendMessage({
    required String requestId,
    required String text,
    required String clientMessageId,
  });
}

class ApiVoiceRepository implements VoiceRepository {
  ApiVoiceRepository(this._dio);

  final Dio _dio;

  static const _base = '/child/school/care';

  @override
  Future<VoiceSurveyState> loadSurvey() => _guard(() async {
    final res = await _dio.get<Object?>('$_base/survey');
    return VoiceSurveyState.fromJson(res.data);
  });

  @override
  Future<void> submitSurvey(String surveyId, Map<String, int> answers) =>
      _guard(() async {
        await _dio.post<Object?>(
          '$_base/survey/${Uri.encodeComponent(surveyId)}/responses',
          data: {'answers': answers},
        );
      });

  @override
  Future<VoiceContact> loadContact() => _guard(() async {
    final res = await _dio.get<Object?>('$_base/contact');
    return VoiceContact.fromJson(res.data);
  });

  @override
  Future<List<VoiceRequestSummary>> loadRequests() => _guard(() async {
    final res = await _dio.get<Object?>('$_base/requests');
    final data = res.data;
    final items = data is Map ? data['items'] : data;
    return jsonList(items, VoiceRequestSummary.tryFromJson);
  });

  @override
  Future<VoiceRequest> loadRequest(String id) => _guard(() async {
    final res = await _dio.get<Object?>(
      '$_base/requests/${Uri.encodeComponent(id)}',
    );
    return VoiceRequest.tryFromJson(res.data) ??
        (throw const FormatException('care request'));
  });

  @override
  Future<VoiceRequest> createRequest({
    required String message,
    required bool urgent,
    required String clientRequestId,
  }) => _guard(() async {
    final res = await _dio.post<Object?>(
      '$_base/requests',
      data: {
        'message': message,
        'urgency': urgent ? 'URGENT' : 'NORMAL',
        'clientRequestId': clientRequestId,
      },
    );
    return VoiceRequest.tryFromJson(res.data) ??
        (throw const FormatException('care request'));
  });

  @override
  Future<VoiceMessage> sendMessage({
    required String requestId,
    required String text,
    required String clientMessageId,
  }) => _guard(() async {
    final res = await _dio.post<Object?>(
      '$_base/requests/${Uri.encodeComponent(requestId)}/messages',
      data: {'text': text, 'clientMessageId': clientMessageId},
    );
    return VoiceMessage.tryFromJson(res.data) ??
        (throw const FormatException('care message'));
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      // Matn (murojaat mazmuni) logga yozilmaydi — faqat yo'l va kod.
      debugPrint('[voice] ${e.requestOptions.path}: ${e.response?.statusCode}');
      throw SchoolException(switch (e.response?.statusCode) {
        null => SchoolErrorCode.network,
        404 => SchoolErrorCode.unavailable,
        409 => SchoolErrorCode.alreadyAnswered,
        400 || 422 => SchoolErrorCode.validation,
        429 => SchoolErrorCode.tooManyRequests,
        _ => SchoolErrorCode.unknown,
      }, e.message);
    } on FormatException catch (e) {
      throw SchoolException(SchoolErrorCode.unknown, e.message);
    }
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => ApiVoiceRepository(ref.watch(dioClientProvider)),
);

final voiceSurveyProvider = FutureProvider.autoDispose<VoiceSurveyState>((ref) {
  ref.watch(schoolAccountProvider);
  // Savollar bola tilida keladi — til serverga yozilgach qayta yuklanadi.
  ref.watch(syncedLanguageRevisionProvider);
  return ref.watch(voiceRepositoryProvider).loadSurvey();
});

/// Mas'ul psixolog. Sozlanmagan yoki server hali bilmasa — [VoiceContact.unknown]
/// (ekranlar ism/ish vaqtisiz umumiy matn ko'rsatadi).
final voiceContactProvider = FutureProvider.autoDispose<VoiceContact>((
  ref,
) async {
  ref.watch(schoolAccountProvider);
  try {
    return await ref.watch(voiceRepositoryProvider).loadContact();
  } on SchoolException catch (e) {
    if (e.code == SchoolErrorCode.unavailable) return VoiceContact.unknown;
    rethrow;
  }
});

final voiceRequestsProvider =
    FutureProvider.autoDispose<List<VoiceRequestSummary>>((ref) {
      ref.watch(schoolAccountProvider);
      return ref.watch(voiceRepositoryProvider).loadRequests();
    });

final voiceRequestProvider = FutureProvider.autoDispose
    .family<VoiceRequest, String>((ref, id) {
      ref.watch(schoolAccountProvider);
      return ref.watch(voiceRepositoryProvider).loadRequest(id);
    });
