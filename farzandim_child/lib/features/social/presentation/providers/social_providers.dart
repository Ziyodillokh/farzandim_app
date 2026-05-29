// ─────────────────────────────────────────────────────────────────────
// social_providers — Riverpod state
// ─────────────────────────────────────────────────────────────────────
//
// Hozir mock data + local state (StateProvider). Kelajakda Firestore
// `users/{uid}/follows/` collection bilan sinx.

import 'package:farzandim_child/features/social/data/mock_social_posts.dart';
import 'package:farzandim_child/features/social/data/models/social_post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SocialFeedTab { following, forYou }

/// Joriy tab — "Following" yoki "Siz uchun".
final socialFeedTabProvider = StateProvider<SocialFeedTab>(
  (_) => SocialFeedTab.following,
);

/// Bola kuzatadigan author ID'lari (Set — qo'shish/o'chirish tez).
final followingAuthorIdsProvider = StateProvider<Set<String>>(
  (_) => Set<String>.from(MockSocialPosts.defaultFollowing),
);

/// Bola yoqtirgan post ID'lari.
final likedPostIdsProvider = StateProvider<Set<String>>(
  (_) => <String>{},
);

/// Barcha postlar (mock).
final allSocialPostsProvider = Provider<List<SocialPost>>((_) {
  return MockSocialPosts.all;
});

/// Filtered postlar — joriy tab'ga ko'ra.
final filteredSocialPostsProvider = Provider<List<SocialPost>>((ref) {
  final tab = ref.watch(socialFeedTabProvider);
  final all = ref.watch(allSocialPostsProvider);

  switch (tab) {
    case SocialFeedTab.following:
      final following = ref.watch(followingAuthorIdsProvider);
      return all.where((p) => following.contains(p.author.id)).toList();
    case SocialFeedTab.forYou:
      return all; // hozircha barchasi
  }
});
