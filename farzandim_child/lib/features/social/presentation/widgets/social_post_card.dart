// ─────────────────────────────────────────────────────────────────────
// SocialPostCard — bitta post (PDF p18, 24) — Parvoz NIGHT/GLASS
// ─────────────────────────────────────────────────────────────────────
//
// Tarkib:
//   1. Author header: avatar + ism + "Kuzatish" tugma (agar follow emas)
//   2. Matn (max 4 qator)
//   3. Media preview (image/video) — agar bor bo'lsa
//   4. Footer: like icon + count + tag chips

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/social/data/models/social_post.dart';
import 'package:farzandim_child/features/social/presentation/providers/social_providers.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialPostCard extends ConsumerWidget {
  const SocialPostCard({required this.post, super.key});

  final SocialPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingAuthorIdsProvider);
    final liked = ref.watch(likedPostIdsProvider);
    final isFollowing = following.contains(post.author.id);
    final isLiked = liked.contains(post.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: parvozGlass(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Author header ===
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 10),
            child: Row(
              children: [
                _Avatar(author: post.author),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.parvozText,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (post.author.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: AppColors.parvozGreen,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                          color: AppColors.parvozTextDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Follow tugma
                _FollowButton(
                  isFollowing: isFollowing,
                  onPressed: () => _toggleFollow(ref, post.author.id),
                ),
              ],
            ),
          ),

          // === Matn ===
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              post.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.parvozText,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

          // === Media preview (image/video) ===
          if (post.mediaType != SocialMediaType.text)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: post.thumbnailColor ?? AppColors.parvozSurfaceHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    post.mediaType.icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),

          // === Footer: like + tags ===
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(ref, post.id),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    scale: isLiked ? 1.1 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked
                              ? Icons.favorite
                              : Icons.favorite_outline,
                          color: isLiked
                              ? AppColors.error
                              : AppColors.parvozTextDim,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.likes + (isLiked ? 1 : 0)}',
                          style: const TextStyle(
                            color: AppColors.parvozTextDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in post.tags) _TagChip(tag: tag),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFollow(WidgetRef ref, String authorId) {
    HapticFeedback.selectionClick();
    final current = ref.read(followingAuthorIdsProvider);
    final updated = Set<String>.from(current);
    if (updated.contains(authorId)) {
      updated.remove(authorId);
    } else {
      updated.add(authorId);
    }
    ref.read(followingAuthorIdsProvider.notifier).state = updated;
  }

  void _toggleLike(WidgetRef ref, String postId) {
    HapticFeedback.lightImpact();
    final current = ref.read(likedPostIdsProvider);
    final updated = Set<String>.from(current);
    if (updated.contains(postId)) {
      updated.remove(postId);
    } else {
      updated.add(postId);
    }
    ref.read(likedPostIdsProvider.notifier).state = updated;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return 'notifications.minutesAgo'
          .tr(namedArgs: {'min': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'notifications.hoursAgo'
          .tr(namedArgs: {'h': '${diff.inHours}'});
    }
    return 'notifications.daysAgo'
        .tr(namedArgs: {'d': '${diff.inDays}'});
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final SocialAuthor author;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: author.avatarColor ?? AppColors.parvozSurfaceHigh,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.onPressed,
  });

  final bool isFollowing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.transparent : AppColors.parvozGreen,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isFollowing
                ? AppColors.parvozBorderStrong
                : AppColors.parvozGreen,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowing ? AppIcons.check : AppIcons.profile,
              color: isFollowing ? AppColors.parvozTextDim : AppColors.parvozOnGreen,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              isFollowing
                  ? 'social.following'.tr()
                  : 'social.follow'.tr(),
              style: TextStyle(
                color: isFollowing ? AppColors.parvozTextDim : AppColors.parvozOnGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.parvozGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: AppColors.parvozGreen,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
