// ─────────────────────────────────────────────────────────────────────
// AudiobookSeries — bir kitobning qismlarini BITTA karta ostida yig'ish
// ─────────────────────────────────────────────────────────────────────
//
// Admin panel har qismni alohida audiokitob sifatida yuklaydi:
//   "Mehrobdan chayon 11", "Mehrobdan chayon 12", ...
// Bola ilovasida ular BITTA "Mehrobdan chayon" kartasi bo'lib ko'rinadi,
// qismlar esa detail sahifada ro'yxat bo'ladi (har qism o'z audio URL va
// REAL davomiyligi bilan).
//
// Guruhlash qoidasi: sarlavha oxiridagi raqam qism raqami hisoblanadi.
// Raqamsiz sarlavha — yakka (bir qismli) kitob.

import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';

/// Sarlavhani (asos, qism raqami) ga ajratadi.
/// "Mehrobdan chayon 14" → ("Mehrobdan chayon", 14); "Shum bola" → (.., null)
(String, int?) splitSeriesTitle(String title) {
  final m = RegExp(r'^(.*?)[\s\-–—]+(\d{1,3})$').firstMatch(title.trim());
  if (m == null || m.group(1)!.trim().isEmpty) return (title.trim(), null);
  return (m.group(1)!.trim(), int.parse(m.group(2)!));
}

/// Bitta kitob (seriya) — 1 yoki bir nechta qism.
class AudiobookSeries {
  const AudiobookSeries({
    required this.title,
    required this.parts,
    required this.partNumbers,
  });

  /// Kitob nomi (qism raqamisiz).
  final String title;

  /// Qismlar — raqam bo'yicha o'sish tartibida.
  final List<AudiobookModel> parts;

  /// Har qismning haqiqiy raqami (sarlavhadan). Yakka kitobda [1].
  final List<int> partNumbers;

  AudiobookModel get cover => parts.first;
  String get author => cover.author;
  bool get isSeries => parts.length > 1;

  /// Ma'lum davomiyliklar yig'indisi (sekund). 0 — hali aniqlanmagan.
  int get totalDurationSeconds => parts.fold(
    0,
    (s, p) => s + (p.durationSeconds > 0 ? p.durationSeconds : 0),
  );

  /// Kartadagi vaqt yorlig'i: real bo'lsa "H:MM:SS/MM:SS", bo'lmasa "—".
  String get durationLabel => formatDuration(totalDurationSeconds);
}

/// Sekundni "MM:SS" yoki "H:MM:SS" ga o'giradi; 0/manfiy → "—".
String formatDuration(int seconds) {
  if (seconds <= 0) return '—';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Kitoblarni seriyalarga yig'adi — feed'dagi birinchi uchrash tartibida.
List<AudiobookSeries> groupIntoSeries(List<AudiobookModel> books) {
  final order = <String>[];
  final buckets = <String, List<(int, AudiobookModel)>>{};
  final baseTitles = <String, String>{};

  for (final b in books) {
    final (base, part) = splitSeriesTitle(b.title);
    // Raqamsiz kitob o'zi alohida guruh (nomi to'liq sarlavha).
    final key = (part == null ? b.title : base).toLowerCase();
    if (!buckets.containsKey(key)) {
      buckets[key] = [];
      order.add(key);
      baseTitles[key] = part == null ? b.title : base;
    }
    buckets[key]!.add((part ?? 1, b));
  }

  return [
    for (final key in order)
      () {
        final list = buckets[key]!..sort((a, b) => a.$1.compareTo(b.$1));
        return AudiobookSeries(
          title: baseTitles[key]!,
          parts: [for (final e in list) e.$2],
          partNumbers: [for (final e in list) e.$1],
        );
      }(),
  ];
}
