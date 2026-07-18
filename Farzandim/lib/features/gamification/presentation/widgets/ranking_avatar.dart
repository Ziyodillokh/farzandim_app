// Reyting avatari — faqat childId bo'lgan joyda (dashboard mini-reyting va
// to'liq reyting ekrani). Bola rasmi bo'lsa network'dan, bo'lmasa DEFAULT
// AVATAR (jingalak-ko'zoynak SVG) — HARF EMAS.
//
// NEGA: reyting qatorlari LeaderboardEntry (childId + name) beradi, to'liq
// Child obyekti emas — shuning uchun ChildAvatar'ni ishlatib bo'lmaydi. Avval
// dashboard mini-reyting boshqa bolalar uchun avatar o'rniga HARF ko'rsatardi
// (joriy bola esa ChildAvatar orqali rasm/default olardi) — nomuvofiq edi.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/gamification/data/repositories/leaderboard_repository.dart';
import 'package:farzandim/shared/widgets/default_avatar_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bola avatari (childId bo'yicha): rasm (proxy) → jinsi+yoshga mos default.
///
/// [gender] berilsa (reyting javobidan) — default avatar jinsi+yoshga mos
/// PNG bo'ladi. Berilmasa (eski javob) — neytral SVG'ga qaytadi.
class RankingAvatar extends ConsumerWidget {
  const RankingAvatar({
    required this.childId,
    required this.size,
    this.gender,
    this.age,
    super.key,
  });

  /// Qaysi bolaning avatarи.
  final String childId;

  /// Diametri (kenglik = balandlik).
  final double size;

  /// Bola jinsi (default avatar tanlash uchun). `null` → neytral fallback.
  final Gender? gender;

  /// Bola yoshi (default avatar guruhini tanlash uchun).
  final int? age;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.read(leaderboardRepositoryProvider).avatarUrl(childId);
    return Container(
      width: size,
      height: size,
      // Fon transparent — surface rangi orqada (ChildAvatar'dek).
      // AppColors.surface temaga bog'liq (runtime) — const bo'lmaydi.
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          // Rasm yo'q/yuklanmagan bo'lsa — default avatar (HARF emas).
          placeholder: (_, __) => defaultAvatarImage(gender: gender, age: age),
          errorWidget: (_, __, ___) =>
              defaultAvatarImage(gender: gender, age: age),
        ),
      ),
    );
  }
}
