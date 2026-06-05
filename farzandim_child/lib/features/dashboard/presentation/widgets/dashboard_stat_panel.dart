// ─────────────────────────────────────────────────────────────────────
// DashboardStatPanel — yuqori header tagidagi 3 ta xulosa karta
// ─────────────────────────────────────────────────────────────────────
//
// XP (jami ball) • Level • Viloyat reytingi (n-o'rin).
// Foydalanuvchi talabiga ko'ra dashboard yuqorisida — logo tagida.
//
// Ma'lumot manbalari:
//   • XP — `gamificationProfileProvider.xp` (Firestore) yoki ranking
//     ma'lumotidagi `totalScore`. Ikkalasi ham yo'q bo'lsa 0.
//   • Level — XP'dan `levelForXp()`.
//   • Region — `pairing.childId` orqali `childDataStreamProvider` JSON
//     ichidan `region`. Ranking'dagi viloyat foydalanuvchilari ichida
//     joriy bola o'rni — yo'q bo'lsa "—" ko'rsatiladi.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardStatPanel extends ConsumerWidget {
  const DashboardStatPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;

    // ─── XP — gamification provider ustun, keyin ranking ─────────────
    final gamification =
        ref.watch(gamificationProfileProvider).valueOrNull;
    final users = ref.watch(allUsersProvider);
    final meInRanking = users
        .cast<RankingUser?>()
        .firstWhere((u) => u?.isCurrentUser ?? false, orElse: () => null);

    final xp = gamification?.xp ?? meInRanking?.totalScore ?? 0;
    final level = levelForXp(xp);

    // ─── Region — childData (Backend REST) ───────────────────────────
    String region = meInRanking?.region ?? '—';
    if (parentUid != null && childId != null) {
      final childData = ref.watch(
        childDataStreamProvider((parentUid: parentUid, childId: childId)),
      );
      final data = childData.valueOrNull;
      final dataRegion = data?['region'] as String?;
      if (dataRegion != null && dataRegion.isNotEmpty) {
        region = dataRegion;
      }
    }

    // ─── Viloyatdagi o'rin ───────────────────────────────────────────
    // 1) Bola backend ranking'ida bo'lsa — uning aniq pozitsiyasi.
    // 2) Bola ranking'da yo'q (hali olympiad'da ishtirok etmagan), lekin
    //    region bilinadi — viloyat foydalanuvchilari soni + 1 (eng oxiri).
    int? regionRank;
    if (meInRanking != null) {
      final regional =
          users.where((u) => u.region == meInRanking.region).toList()
            ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
      final idx = regional.indexWhere((u) => u.isCurrentUser);
      if (idx >= 0) regionRank = idx + 1;
    } else if (region != '—' && users.isNotEmpty) {
      // Bola ranking'da yo'q, lekin region childData'dan bilinadi.
      // XP bo'yicha solishtirib o'rinni hisoblaymiz: bola xp'sidan
      // baland totalScore'ga ega bo'lganlar soni + 1.
      final regional = users.where((u) => u.region == region).toList();
      final higherCount =
          regional.where((u) => u.totalScore > xp).length;
      regionRank = higherCount + 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: AppIcons.trophy,
              iconColor: const Color(0xFFFFB627),
              value: _formatScore(xp),
              label: 'XP',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.bolt_rounded,
              iconColor: AppColors.primary,
              value: '$level',
              label: 'Level',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF1CB0F6),
              value: regionRank != null ? '$regionRank-o\'rin' : '—',
              label: region,
              tightLabel: true,
            ),
          ),
        ],
      ),
    );
  }

  String _formatScore(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.tightLabel = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool tightLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.adaptive.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.adaptive.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: iconColor.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.adaptive.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tightLabel ? 10 : 11,
                    color: context.adaptive.textSecondary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
