// DON tarixi manbalari: Growth kunlik testlari (`DAILY_LEARNING`) o'z
// yorlig'i bilan ("Boshqa" emas); noma'lum tur — "Boshqa".

import 'package:farzandim_child/features/don_history/data/models/don_history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DAILY_LEARNING — "Kunlik testlar"', () {
    final entry = DonHistoryEntry.fromJson({
      'type': 'DAILY_LEARNING',
      'donDelta': 12,
      'createdAt': '2026-10-20T06:30:00.000Z',
    });

    expect(entry.don, 12);
    expect(entry.source.labelKey, 'donHistory.source.dailyLearning');
  });

  test('noma\'lum tur — "Boshqa"', () {
    expect(
      DonSource.fromType('SOMETHING_NEW').labelKey,
      'donHistory.source.other',
    );
  });

  test('yig\'indi: kunlik testlar alohida guruh', () {
    final entries = [
      for (final (type, don) in [
        ('DAILY_LEARNING', 10),
        ('DAILY_GOAL', 5),
        ('DAILY_LEARNING', 8),
      ])
        DonHistoryEntry.fromJson({'type': type, 'donDelta': don}),
    ];

    final totals = summarizeByType(entries);
    expect(totals.first.source.labelKey, 'donHistory.source.dailyLearning');
    expect((totals.first.total, totals.first.count), (18, 2));
  });
}
