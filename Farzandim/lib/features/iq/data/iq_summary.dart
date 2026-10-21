// IQ test xulosasi (ota-ona): GET /children/:childId/iq/summary
// (docs/IQ-REJA.md §5). Savollar va bolaning javoblari kelmaydi.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// Natija holati: norma yetarli bo'lguncha — taxminiy (IQ raqamisiz).
enum IqResultStatus { provisional, normed, unknown }

/// WISC-V darajalari (backend kodi bilan bir xil).
const kIqBands = [
  'VERY_HIGH',
  'HIGH',
  'ABOVE_AVERAGE',
  'AVERAGE',
  'BELOW_AVERAGE',
  'LOW',
  'VERY_LOW',
];

@immutable
class IqResult {
  const IqResult({
    required this.correct,
    required this.total,
    required this.status,
    required this.percentile,
    required this.band,
    required this.standardScore,
    required this.ci95,
    required this.completedAt,
  });

  factory IqResult.fromJson(Map<String, dynamic> json) {
    final ci = json.readList('ci95');
    final lo = ci.isNotEmpty ? ci.first : null;
    final hi = ci.length > 1 ? ci[1] : null;
    return IqResult(
      correct: json.readInt('correct'),
      total: json.readInt('total'),
      status: switch (json.readString('status')) {
        'PROVISIONAL' => IqResultStatus.provisional,
        'NORMED' => IqResultStatus.normed,
        _ => IqResultStatus.unknown,
      },
      percentile: json.readIntOrNull('percentile'),
      band: json.readString('band'),
      standardScore: json.readIntOrNull('standardScore'),
      ci95: lo is num && hi is num ? (lo.round(), hi.round()) : null,
      completedAt: json.readDateTime('completedAt'),
    );
  }

  final int correct;
  final int total;
  final IqResultStatus status;

  /// 1..99 (tengdoshlarga nisbatan).
  final int? percentile;
  final String band;

  /// Faqat [IqResultStatus.normed] da (100±15).
  final int? standardScore;
  final (int, int)? ci95;
  final DateTime? completedAt;

  bool get isNormed => status == IqResultStatus.normed;
}

@immutable
class IqSummary {
  const IqSummary({
    required this.ageStatus,
    required this.last,
    required this.previous,
    required this.nextAvailableAt,
  });

  factory IqSummary.fromJson(Map<String, dynamic> json) {
    final lastJson = json.readMapOrNull('last');
    final history = parseListSafely(
      json.readList('history'),
      (Map<String, dynamic> e) =>
          IqResult.fromJson(e.readMapOrNull('result') ?? const {}),
      tag: 'IqHistory',
    );
    final last = lastJson == null ? null : IqResult.fromJson(lastJson);
    // Tarix — yangisi birinchi; oxirgisidan oldingi natija taqqoslash uchun.
    final older = [
      for (final r in history)
        if (last == null || r.completedAt != last.completedAt) r,
    ];
    return IqSummary(
      ageStatus: json.readMapOrNull('age')?.readString('status') ?? '',
      last: last,
      previous: older.isEmpty ? null : older.first,
      nextAvailableAt: json.readDateTime('nextAvailableAt'),
    );
  }

  /// `OK` | `AGE_REQUIRED` | `AGE_OUT_OF_RANGE`.
  final String ageStatus;
  final IqResult? last;
  final IqResult? previous;
  final DateTime? nextAvailableAt;
}
