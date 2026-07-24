// ─────────────────────────────────────────────────────────────────────
// DonHistoryEntry — bolaning DON tarixidagi bitta yozuv (ota-ona ko'radi)
// ─────────────────────────────────────────────────────────────────────
//
// Manba: backend `GET /children/:childId/xp-events` (XpEvent). Faqat
// don > 0 bo'lgan yozuvlar (DON qayerdan yig'ilgani).

import 'package:flutter/material.dart';

/// DON tarixidagi bitta yozuv.
class DonHistoryEntry {
  const DonHistoryEntry({
    required this.type,
    required this.don,
    required this.date,
  });

  factory DonHistoryEntry.fromJson(Map<String, dynamic> j) {
    final raw = j['createdAt'];
    final date = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    return DonHistoryEntry(
      type: (j['type'] as String?) ?? 'OTHER',
      don: (j['donDelta'] as num?)?.toInt() ?? 0,
      date: date ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Backend XpEvent turi (`DAILY_GOAL`, `BOOK_READ`, ...).
  final String type;

  /// Shu yozuvda berilgan DON miqdori (> 0).
  final int don;

  /// Qachon berilgan (lokal vaqt).
  final DateTime date;

  /// Chiroyli manba (yorliq + ikon + rang).
  DonSource get source => DonSource.fromType(type);
}

/// DON manbasi — XpEvent turini foydalanuvchi-friendly ko'rinishga xaritalaydi.
///
/// `DAILY_GOAL` = qadam mukofoti, `BOOK_READ` = audiokitob, `CONTEST_*` =
/// test/konkurs, `OTHER` = video (backend `completeVideo` shu turni beradi).
class DonSource {
  const DonSource(this.label, this.icon, this.color);

  /// XpEvent turini manbaga xaritalaydi (yorliq + ikon + rang).
  factory DonSource.fromType(String type) {
    switch (type) {
      case 'DAILY_GOAL':
        return const DonSource(
          'donHistory.src.steps',
          Icons.directions_walk_rounded,
          Color(0xFF34C759),
        );
      case 'BOOK_READ':
        return const DonSource(
          'donHistory.src.audiobooks',
          Icons.headphones_rounded,
          Color(0xFF216BFF),
        );
      case 'CONTEST_JOIN':
        return const DonSource(
          'donHistory.src.contestJoin',
          Icons.quiz_rounded,
          Color(0xFFAF7BFF),
        );
      case 'CONTEST_WIN':
        return const DonSource(
          'donHistory.src.contestWin',
          Icons.emoji_events_rounded,
          Color(0xFFF2B233),
        );
      case 'CREATIVE_JOIN':
        return const DonSource(
          'donHistory.src.creativeJoin',
          Icons.brush_rounded,
          Color(0xFFFF7A9A),
        );
      case 'CREATIVE_WIN':
        return const DonSource(
          'donHistory.src.creativeWin',
          Icons.emoji_events_rounded,
          Color(0xFFF2B233),
        );
      case 'COURSE_LESSON':
        return const DonSource(
          'donHistory.src.lessons',
          Icons.menu_book_rounded,
          Color(0xFF20C4B8),
        );
      case 'STREAK_WEEKLY':
        return const DonSource(
          'donHistory.src.streak',
          Icons.local_fire_department_rounded,
          Color(0xFFFF7A45),
        );
      case 'CONTENT_POST':
        return const DonSource(
          'donHistory.src.content',
          Icons.auto_awesome_rounded,
          Color(0xFF20C4B8),
        );
      case 'OTHER':
        return const DonSource(
          'donHistory.src.videos',
          Icons.play_circle_fill_rounded,
          Color(0xFFFF5A5D),
        );
      default:
        return const DonSource(
          'donHistory.src.other',
          Icons.star_rounded,
          Color(0xFF8CA0B3),
        );
    }
  }

  final String label;
  final IconData icon;
  final Color color;
}

/// Manba bo'yicha yig'indi (summary kartasi uchun).
class DonSourceTotal {
  const DonSourceTotal({
    required this.source,
    required this.total,
    required this.count,
  });

  final DonSource source;
  final int total;
  final int count;
}

/// Yozuvlarni manba bo'yicha guruhlab, yig'indi (kamayish tartibida) qaytaradi.
List<DonSourceTotal> summarizeByType(List<DonHistoryEntry> entries) {
  final byType = <String, ({int total, int count})>{};
  for (final e in entries) {
    final prev = byType[e.type] ?? (total: 0, count: 0);
    byType[e.type] = (total: prev.total + e.don, count: prev.count + 1);
  }
  final list =
      byType.entries
          .map(
            (m) => DonSourceTotal(
              source: DonSource.fromType(m.key),
              total: m.value.total,
              count: m.value.count,
            ),
          )
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));
  return list;
}
