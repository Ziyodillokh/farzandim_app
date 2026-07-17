// ─────────────────────────────────────────────────────────────────────
// PairRequest — Bola re-pair so'rovi (Backend 0.6.0)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

enum PairRequestStatus { pending, approved, rejected, expired, unknown }

@immutable
class PairRequest {
  const PairRequest({
    required this.id,
    required this.childId,
    required this.childName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.ipAddress,
    this.deviceModel,
    this.androidVersion,
    this.appVersion,
  });

  factory PairRequest.fromBackendJson(Map<String, dynamic> json) {
    return PairRequest(
      id: json['id'] as String? ?? '',
      childId: json['childId'] as String? ?? '',
      childName:
          (json['childName'] as String?) ??
          (json['child'] as Map?)?['name'] as String? ??
          'pairRequests.fallbackChildName'.tr(),
      status: _parseStatus(json['status'] as String?),
      createdAt: _parseIso(json['createdAt']) ?? DateTime.now(),
      expiresAt:
          _parseIso(json['expiresAt']) ??
          DateTime.now().add(const Duration(minutes: 5)),
      ipAddress: json['ipAddress'] as String?,
      deviceModel: json['deviceModel'] as String?,
      androidVersion: json['androidVersion'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }

  static PairRequestStatus _parseStatus(String? s) {
    switch (s) {
      case 'PENDING':
        return PairRequestStatus.pending;
      case 'APPROVED':
        return PairRequestStatus.approved;
      case 'REJECTED':
        return PairRequestStatus.rejected;
      case 'EXPIRED':
        return PairRequestStatus.expired;
      default:
        return PairRequestStatus.unknown;
    }
  }

  static DateTime? _parseIso(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  final String id;
  final String childId;
  final String childName;
  final PairRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? ipAddress;
  final String? deviceModel;
  final String? androidVersion;
  final String? appVersion;

  Duration get timeLeft {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isPending => status == PairRequestStatus.pending;

  String get deviceLabel {
    final parts = <String>[
      if (deviceModel != null && deviceModel!.isNotEmpty) deviceModel!,
      if (androidVersion != null && androidVersion!.isNotEmpty) androidVersion!,
    ];
    return parts.isEmpty
        ? 'pairRequests.deviceUnknown'.tr()
        : parts.join(' • ');
  }
}
