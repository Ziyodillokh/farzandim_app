// ─────────────────────────────────────────────────────────────────────
// ProfileScreen — bola o'zining gamifikatsiya progress'ini ko'radi
// ─────────────────────────────────────────────────────────────────────
//
// Tartib (yuqoridan pastga):
//   1. Avatar + ism + StatusBadge
//   2. LevelProgressCard (Lv + XP progress)
//   3. DonWalletCard + StreakIndicator (yon)
//   4. AchievementsGrid (6 nishon)
//   5. Oxirgi XP events (tarix, 5 ta)

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_profile.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';
import 'package:farzandim_child/features/gamification/data/models/xp_event.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/achievements_grid.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/don_wallet_card.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/level_progress_card.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile_skeleton.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/status_badge.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/streak_indicator.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Achievement diff kuzatish — yangi unlock bo'lganlar uchun snackbar.
  List<String> _previousAchievementIds = const [];
  bool _initialLoaded = false;

  /// Confetti — achievement unlock paytida fonda otiladi.
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    // Profile stream'ga listen — yangi achievement unlock bo'lsa snackbar.
    ref.listen(gamificationProfileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile == null) return;

      if (!_initialLoaded) {
        _previousAchievementIds = profile.unlockedAchievements;
        _initialLoaded = true;
        return;
      }

      final newIds = profile.unlockedAchievements
          .where((id) => !_previousAchievementIds.contains(id))
          .toList();

      if (newIds.isNotEmpty) {
        _previousAchievementIds = profile.unlockedAchievements;
        // Bayram — confetti + heavy haptic + toast'lar.
        _confetti.play();
        HapticFeedback.heavyImpact();
        for (final id in newIds) {
          final achievement = Achievements.byId(id);
          if (achievement != null) {
            _showAchievementToast(context, achievement);
          }
        }
      }
    });
    final pairing = ref.watch(pairingStateProvider);
    final profileAsync = ref.watch(gamificationProfileProvider);
    final eventsAsync = ref.watch(recentXpEventsProvider);

    final childName = pairing.childName ??
        'common.fallbackChildName'.tr();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          GradientBackground(
            child: SafeArea(
              bottom: false,
              child: profileAsync.when(
                data: (profile) => _buildContent(
                  context,
                  ref,
                  profile,
                  eventsAsync.valueOrNull ?? const [],
                  childName,
                ),
                loading: _buildSkeleton,
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'common.errorPrefix'
                          .tr(namedArgs: {'error': '$e'}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Confetti — yutuq unlock paytida ekran tepasidan otiladi.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: 1.5708, // 90° pastga
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                AppColors.primary,
                AppColors.catGold,
                AppColors.catOrange,
                AppColors.catBlue,
                AppColors.catViolet,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  /// Shimmer skeleton — yuklash paytidagi platzhalder.
  Widget _buildSkeleton() => const ProfileSkeleton();

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    GamificationProfile profile,
    List<XpEvent> events,
    String childName,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
        bottom: 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardTopHeader(
            onAvatarTap: () => context.push('/account-edit'),
          ),
          const SizedBox(height: 16),

          // === Header: avatar + ism + status ===
          // Bola foto tap → /account-edit (yangi rasm yuklash). Foto
          // bo'lmasa fallback person ikoni. Avatar atrofida status rangi
          // bilan ring + pastki-o'ng tomonda kamera tugma.
          Row(
            children: [
              _ProfileAvatar(profile: profile, ref: ref),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      childName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adaptive.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StatusBadge(status: profile.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // === Level + XP progress ===
          LevelProgressCard(profile: profile)
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),

          // === XP + Streak (yon — ikkalasi bir xil balandlikda) ===
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: DonWalletCard(xp: profile.xp)),
                const SizedBox(width: 12),
                Expanded(child: StreakIndicator(streak: profile.streak)),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 24),

          // === Yutuqlar ===
          Text(
            'gamification.achievementsTitle'.tr(),
            style: TextStyle(
              color: context.adaptive.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          AchievementsGrid(unlockedIds: profile.unlockedAchievements),
          const SizedBox(height: 24),

          // === XP tarix ===
          Text(
            'gamification.recentActivityTitle'.tr(),
            style: TextStyle(
              color: context.adaptive.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            _EmptyHistory()
          else
            Column(
              children: events.take(5).map((e) => _XpEventTile(event: e)).toList(),
            ),
        ],
      ),
    );
  }

  /// Yangi yutuq unlock bo'lganda toast.
  void _showAchievementToast(BuildContext context, Achievement achievement) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: achievement.color,
        content: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(achievement.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'gamification.achievementUnlockedTitle'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.titleKey.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.adaptive.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.adaptive.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.history,
              color: context.adaptive.textSecondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'gamification.recentActivityEmpty'.tr(),
              style: TextStyle(
                color: context.adaptive.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XpEventTile extends StatelessWidget {
  const _XpEventTile({required this.event});

  final XpEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.adaptive.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.adaptive.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bolt,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.type.translationKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.adaptive.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '+${event.xpDelta} XP',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (event.donDelta > 0) ...[
            const SizedBox(width: 8),
            Text(
              '+${event.donDelta} DON',
              style: const TextStyle(
                color: AppColors.catGold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Profile avatar — bola rasmi + tahrir overlay ────────────────────
// Foto bo'lsa: dumaloq foto + status rangli ring + kamera badge.
// Foto bo'lmasa: fallback person ikoni + status rangli ring + kamera badge.
// Tap → /account-edit (yangi rasm yuklash).
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile, required this.ref});

  final GamificationProfile profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);
    final childId = pairing.childId;
    final photoUrl = (childId != null && childId.isNotEmpty)
        ? ref.watch(childAvatarUrlProvider(childId)).valueOrNull
        : null;

    return GestureDetector(
      onTap: () => context.push('/account-edit'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Status rangli ring
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    profile.status.color,
                    // ignore: deprecated_member_use
                    profile.status.color.withOpacity(0.6),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: context.adaptive.bgPrimary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PhotoFallback(profile: profile),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : _PhotoFallback(profile: profile),
                        )
                      : _PhotoFallback(profile: profile),
                ),
              ),
            ),
            // Kamera tugma — pastki o'ng burchakda
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.adaptive.bgPrimary,
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.profile});

  final GamificationProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      // ignore: deprecated_member_use
      color: profile.status.color.withOpacity(0.18),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: profile.status.color,
        size: 36,
      ),
    );
  }
}
