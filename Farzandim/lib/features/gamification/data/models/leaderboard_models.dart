// Reyting modellari — GET /api/leaderboard javobining typed ko'rinishi.

import 'package:flutter/foundation.dart';

/// Reytingdagi bitta qator (bola).
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.childId,
    required this.name,
    required this.region,
    required this.xp,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) {
    return LeaderboardEntry(
      rank: (j['rank'] as num?)?.toInt() ?? 0,
      childId: j['childId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      region: j['region'] as String? ?? '',
      xp: (j['xp'] as num?)?.toInt() ?? 0,
    );
  }

  final int rank;
  final String childId;
  final String name;
  final String region;
  final int xp;
}

/// Reyting sahifasi (pagination).
@immutable
class LeaderboardPage {
  const LeaderboardPage({
    required this.entries,
    required this.total,
    required this.hasMore,
    required this.currentChild,
  });

  factory LeaderboardPage.fromJson(Map<String, dynamic> j) {
    final list = (j['entries'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
    final cur = j['currentChild'];
    return LeaderboardPage(
      entries: list,
      total: (j['total'] as num?)?.toInt() ?? list.length,
      hasMore: j['hasMore'] as bool? ?? false,
      currentChild: cur is Map<String, dynamic>
          ? LeaderboardEntry.fromJson(cur)
          : null,
    );
  }

  final List<LeaderboardEntry> entries;
  final int total;
  final bool hasMore;
  final LeaderboardEntry? currentChild;
}
