// Kutubxona yordamchilari: oxirgi tinglangan audiokitob («Davom ettirish»),
// maqola o'qish vaqti, maqola xatcho'plari va matn o'lchami (qurilmada).
// Oxirgi audiokitob va xatcho'plar — shaxsiy, har bir akkauntniki alohida;
// matn o'lchami — qurilma sozlamasi.

import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asos kalitlar — akkauntga bog'lanadi ([accountKey]).
const _lastAudiobookKey = 'g5_last_audiobook_v1';
const _articleBookmarksKey = 'g5_article_bookmarks_v1';

/// Qurilma sozlamasi (shaxsiy ma'lumot emas).
const _articleTextScaleKey = 'g5_article_text_scale_v1';

/// Audiopleer joyni shu kalit bilan saqlaydi (`audio_player_provider.dart`).
String audiobookPositionKey(String id) => 'audiobook_pos_$id';

/// Daqiqasiga o'qiladigan so'zlar (bolalar uchun sekinroq).
const kReadingWordsPerMinute = 160;

int articleReadingMinutes(ArticleModel article) {
  final words = article.body
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
  return (words / kReadingWordsPerMinute).ceil().clamp(1, 120);
}

@immutable
class LastAudiobook {
  const LastAudiobook({required this.id, required this.position});

  final String id;
  final Duration position;
}

final lastAudiobookProvider =
    AsyncNotifierProvider<LastAudiobookNotifier, LastAudiobook?>(
      LastAudiobookNotifier.new,
    );

class LastAudiobookNotifier extends AsyncNotifier<LastAudiobook?> {
  /// Joriy akkaunt kaliti (`null` — hech kim kirmagan).
  String? _key;

  @override
  Future<LastAudiobook?> build() async {
    _key = ref.watch(currentAccountKeyProvider(_lastAudiobookKey));
    final key = _key;
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(key);
      if (id == null || id.isEmpty) return null;
      final seconds = prefs.getInt(audiobookPositionKey(id)) ?? 0;
      return LastAudiobook(
        id: id,
        position: Duration(seconds: seconds),
      );
    } on Object catch (e) {
      debugPrint('[library] oxirgi audiokitob o\'qilmadi: $e');
      return null;
    }
  }

  Future<void> remember(String id) async {
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, id);
    } on Object catch (e) {
      debugPrint('[library] oxirgi audiokitob saqlanmadi: $e');
    }
    ref.invalidateSelf();
  }
}

/// Saqlangan (xatcho'p qo'yilgan) maqolalar.
final articleBookmarksProvider =
    AsyncNotifierProvider<ArticleBookmarksNotifier, Set<String>>(
      ArticleBookmarksNotifier.new,
    );

class ArticleBookmarksNotifier extends AsyncNotifier<Set<String>> {
  /// Joriy akkaunt kaliti (`null` — hech kim kirmagan).
  String? _key;

  @override
  Future<Set<String>> build() async {
    _key = ref.watch(currentAccountKeyProvider(_articleBookmarksKey));
    final key = _key;
    if (key == null) return const {};
    try {
      final prefs = await SharedPreferences.getInstance();
      return Set.unmodifiable(prefs.getStringList(key) ?? const <String>[]);
    } on Object catch (e) {
      debugPrint('[library] xatcho\'plar o\'qilmadi: $e');
      return const {};
    }
  }

  Future<void> toggle(String id) async {
    final current = state.valueOrNull ?? const <String>{};
    final next = current.contains(id)
        ? ({...current}..remove(id))
        : {...current, id};
    state = AsyncData(Set.unmodifiable(next));
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, next.toList());
    } on Object catch (e) {
      debugPrint('[library] xatcho\'p saqlanmadi: $e');
    }
  }
}

/// Maqola matni masshtabi (A− / A+): 0.85 … 1.6.
const kArticleScaleMin = .85;
const kArticleScaleMax = 1.6;
const kArticleScaleStep = .15;

final articleTextScaleProvider =
    AsyncNotifierProvider<ArticleTextScaleNotifier, double>(
      ArticleTextScaleNotifier.new,
    );

class ArticleTextScaleNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getDouble(_articleTextScaleKey) ?? 1).clamp(
        kArticleScaleMin,
        kArticleScaleMax,
      );
    } on Object {
      return 1;
    }
  }

  Future<void> change(double delta) async {
    final next = ((state.valueOrNull ?? 1) + delta).clamp(
      kArticleScaleMin,
      kArticleScaleMax,
    );
    state = AsyncData(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_articleTextScaleKey, next);
    } on Object catch (e) {
      debugPrint('[library] matn o\'lchami saqlanmadi: $e');
    }
  }
}
