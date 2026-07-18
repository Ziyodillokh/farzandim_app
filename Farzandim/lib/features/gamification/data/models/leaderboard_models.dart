// Reyting modellari — GET /api/leaderboard javobining typed ko'rinishi.

import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter/foundation.dart';

/// Reytingdagi bitta qator (bola).
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.childId,
    required this.name,
    required this.region,
    required this.don,
    this.age,
    this.gender,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) {
    return LeaderboardEntry(
      rank: (j['rank'] as num?)?.toInt() ?? 0,
      childId: j['childId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      region: j['region'] as String? ?? '',
      age: (j['age'] as num?)?.toInt(),
      gender: _parseGender(j['gender'] as String?),
      don: (j['don'] as num?)?.toInt() ?? 0,
    );
  }

  /// Backend 'male'/'female' → `Gender`. Noma'lum/yo'q (eski javob) → `null`
  /// (default avatar neytral SVG'ga qaytadi).
  static Gender? _parseGender(String? raw) {
    switch (raw) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      default:
        return null;
    }
  }

  final int rank;
  final String childId;
  final String name;
  final String region;
  final int? age;

  /// Bola jinsi — default avatar (jinsi+yosh) uchun. Eski backend javobida
  /// yo'q bo'lsa `null` → neytral fallback.
  final Gender? gender;

  /// Reyting soni — DON. Panel'dagi "DON balansi" bilan AYNAN bir xil manba
  /// (`ChildProfile.donBalance`). Avval bu yerda `xp` o'qilardi va ekranda
  /// "DON" deb yozilardi → bitta bola panelda 210, reytingda 260 ko'rinardi.
  final int don;
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
