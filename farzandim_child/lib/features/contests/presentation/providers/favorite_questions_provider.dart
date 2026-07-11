// ─────────────────────────────────────────────────────────────────────
// favorite_questions_provider — "Tanlangan savollar" (lokal bookmark)
// ─────────────────────────────────────────────────────────────────────
//
// Quiz ichida ♡ bosilsa joriy savol saqlanadi (id + matn). "Tanlangan
// savollar" sahifasi shu ro'yxatni ko'rsatadi — eng oxirgi tanlangani
// birinchi (newest-first). Lokal (SharedPreferences JSON), backend shart emas.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _favQuestionsKey = 'favorite_questions_v1';

/// Saqlangan savol — matni bilan (sahifada ko'rsatish uchun).
class FavQuestion {
  const FavQuestion({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};

  factory FavQuestion.fromJson(Map<String, dynamic> j) => FavQuestion(
    id: j['id']?.toString() ?? '',
    text: j['text']?.toString() ?? '',
  );
}

final favoriteQuestionsProvider =
    NotifierProvider<FavoriteQuestionsNotifier, List<FavQuestion>>(
      FavoriteQuestionsNotifier.new,
    );

class FavoriteQuestionsNotifier extends Notifier<List<FavQuestion>> {
  Future<void>? _ready;

  @override
  List<FavQuestion> build() {
    _ready = _restore();
    return const [];
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favQuestionsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(FavQuestion.fromJson)
          .where((q) => q.id.isNotEmpty)
          .toList();
      state = list;
    } catch (_) {
      // Buzuq JSON — bo'sh qoladi.
    }
  }

  bool contains(String id) => state.any((q) => q.id == id);

  /// Toggle — qo'shilsa `true`. Qo'shilganda RO'YXAT BOSHIGA (newest-first).
  Future<bool> toggle(String id, String text) async {
    await _ready;
    final exists = state.any((q) => q.id == id);
    final next = exists
        ? state.where((q) => q.id != id).toList()
        : [FavQuestion(id: id, text: text), ...state];
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _favQuestionsKey,
        jsonEncode(next.map((q) => q.toJson()).toList()),
      );
    } catch (_) {
      // Saqlash xatosi — state sessiya davomida baribir o'zgardi.
    }
    return !exists;
  }
}
