// ─────────────────────────────────────────────────────────────────────
// CertificateRepository — olimpiada sertifikati (#56)
// ─────────────────────────────────────────────────────────────────────
//
//   GET /api/content/olympiads/attempts/:id/certificate
//     → { certificateId, childNick, olympiadTitle, subject, score, percent, date }
//   Chegaradan past / certificateEnabled=false / boshqa bola → 403/404.

// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/network/dio_client.dart';

final certificateRepositoryProvider = Provider<CertificateRepository>((ref) {
  return CertificateRepository(dio: ref.watch(dioClientProvider));
});

class CertificateRepository {
  CertificateRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  /// Sertifikat ma'lumotini oladi. Bola haqli bo'lmasa (chegaradan past yoki
  /// o'chirilgan) `null` qaytadi.
  Future<CertificateData?> fetch(String attemptId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/content/olympiads/attempts/$attemptId/certificate',
      );
      final data = res.data;
      if (data == null) return null;
      return CertificateData.fromJson(data);
    } on DioException catch (e) {
      debugPrint('CertificateRepository.fetch: ${e.response?.statusCode}');
      return null;
    }
  }
}

@immutable
class CertificateData {
  const CertificateData({
    required this.certificateId,
    required this.childNick,
    required this.olympiadTitle,
    required this.subject,
    required this.score,
    required this.percent,
    required this.date,
  });

  factory CertificateData.fromJson(Map<String, dynamic> json) {
    return CertificateData(
      certificateId: json['certificateId'] as String? ?? '',
      childNick: json['childNick'] as String? ?? 'Parvoz yulduzi',
      olympiadTitle: json['olympiadTitle'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      date:
          DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  final String certificateId;
  final String childNick;
  final String olympiadTitle;
  final String subject;
  final int score;
  final int percent;
  final DateTime date;
}
