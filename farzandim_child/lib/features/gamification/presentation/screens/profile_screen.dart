// ─────────────────────────────────────────────────────────────────────
// ProfileScreen — Parvoz "Profil" (aqua night, boshqa sahifalar bilan kogerent)
// ─────────────────────────────────────────────────────────────────────
//
// Hero (avatar + aqua ring + Daraja badge + ism/status) → 3 stat
// (Daraja / Umumiy XP / Kunlik Seriya) → Keyingi Darajaga progress →
// Yutuqlar grid'i. Night asosiy; light — sodda. Ma'lumotlar:
// gamificationProfileProvider (xp/streak/level/status/yutuqlar) — LOGIKA SAQLANGAN.

import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_profile.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────── Palette (Parvoz NIGHT — barcha sahifalar bilan izchil) ───────────────

class _P {
  _P();

  Color get bg => AppColors.parvozBg;
  Color get card => AppColors.parvozSurface;
  Color get cardHigh => AppColors.parvozSurfaceHigh;
  Color get text => AppColors.parvozText;
  Color get muted => AppColors.parvozTextDim;
  Color get border => AppColors.parvozBorder;
  Color get track => AppColors.parvozBg;

  Color get aqua => AppColors.parvozGreen;
  Color get onAqua => AppColors.parvozOnGreen;
  Color get gold => const Color(0xFFFFC83D);
  Color get fire => const Color(0xFFFF7A45);
  Color get locked => const Color(0xFF5C6B78);
}

TextStyle _jak(_P p, {double size = 14, FontWeight weight = FontWeight.w600, Color? color, double? height, double? spacing}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color ?? p.text, height: height, letterSpacing: spacing);

String _fmtXp(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k' : '$n';

// ─────────────── SCREEN ───────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<String> _previousAchievementIds = const [];
  bool _initialLoaded = false;
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yangi yutuq unlock bo'lsa — confetti + toast (LOGIKA SAQLANGAN).
    ref.listen(gamificationProfileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile == null) return;
      if (!_initialLoaded) {
        _previousAchievementIds = profile.unlockedAchievements;
        _initialLoaded = true;
        return;
      }
      final newIds = profile.unlockedAchievements.where((id) => !_previousAchievementIds.contains(id)).toList();
      if (newIds.isNotEmpty) {
        _previousAchievementIds = profile.unlockedAchievements;
        _confetti.play();
        HapticFeedback.heavyImpact();
        for (final id in newIds) {
          final a = Achievements.byId(id);
          if (a != null) _showAchievementToast(context, a);
        }
      }
    });

    final p = _P();
    final pairing = ref.watch(pairingStateProvider);
    final profileAsync = ref.watch(gamificationProfileProvider);
    final childName = pairing.childName ?? 'common.fallbackChildName'.tr();

    return Scaffold(
      backgroundColor: p.bg,
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: profileAsync.when(
              data: (profile) => _buildContent(context, p, profile, childName, pairing.childId),
              loading: () => Center(child: CircularProgressIndicator(color: p.aqua)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('common.errorPrefix'.tr(namedArgs: {'error': '$e'}),
                      textAlign: TextAlign.center, style: _jak(p, color: const Color(0xFFFF4B4B))),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: 1.5708,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [Color(0xFF22D3EE), Color(0xFFFFC83D), Color(0xFFFF7A45), Color(0xFF2170E4), Color(0xFFADC6FF)],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  Widget _buildContent(BuildContext context, _P p, GamificationProfile profile, String childName, String? childId) {
    final avatarUrl = (childId != null && childId.isNotEmpty)
        ? ref.watch(childAvatarUrlProvider(childId)).valueOrNull
        : null;
    final level = profile.level;
    final xpInLevel = profile.xp % 100;
    final remaining = 100 - xpInLevel;
    final frac = xpInLevel / 100.0;
    final unlocked = profile.unlockedAchievements;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 6, 20, 150 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        children: [
          _TopBar(p: p),
          const SizedBox(height: 6),
          _Hero(
            p: p,
            name: childName,
            status: profile.status.translationKey.tr(),
            level: level,
            avatarUrl: avatarUrl,
            onEdit: () => context.push('/account-edit'),
          ),
          const SizedBox(height: 26),
          _StatsRow(p: p, level: level, xp: profile.xp, streak: profile.streak),
          const SizedBox(height: 14),
          _ProgressCard(p: p, remaining: remaining, frac: frac, level: level),
          const SizedBox(height: 26),
          _Achievements(p: p, unlockedIds: unlocked),
        ],
      ),
    );
  }

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
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(achievement.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('gamification.achievementUnlockedTitle'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────── TOP BAR ───────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Profil', style: _jak(p, size: 17, weight: FontWeight.w700)),
        const Spacer(),
        GestureDetector(
          onTap: () => context.push('/settings'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.card, border: Border.all(color: p.border, width: 1)),
            child: Icon(Icons.settings_outlined, color: p.muted, size: 21),
          ),
        ),
      ],
    );
  }
}

// ─────────────── HERO (avatar + ism + daraja) ───────────────

class _Hero extends StatelessWidget {
  const _Hero({
    required this.p,
    required this.name,
    required this.status,
    required this.level,
    required this.avatarUrl,
    required this.onEdit,
  });
  final _P p;
  final String name;
  final String status;
  final int level;
  final String? avatarUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onEdit,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 130,
            height: 138,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Aqua glow.
                Positioned(
                  top: 6,
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: p.aqua.withValues(alpha: 0.35), blurRadius: 34, spreadRadius: 2)],
                    ),
                  ),
                ),
                // Avatar + aqua ring.
                Container(
                  width: 116,
                  height: 116,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.aqua, width: 3.5)),
                  clipBehavior: Clip.antiAlias,
                  child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? Image.network(avatarUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(), loadingBuilder: (_, c, pr) => pr == null ? c : _fallback())
                      : _fallback(),
                ),
                // Edit camera badge.
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.aqua,
                      border: Border.all(color: p.bg, width: 2.5),
                    ),
                    child: Icon(Icons.photo_camera_rounded, color: p.onAqua, size: 16),
                  ),
                ),
                // "Daraja N" badge.
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.aqua,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: p.bg, width: 2.5),
                      boxShadow: [BoxShadow(color: p.aqua.withValues(alpha: 0.45), blurRadius: 14)],
                    ),
                    child: Text('Daraja $level', style: _jak(p, size: 13, weight: FontWeight.w800, color: p.onAqua, spacing: -0.2)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _jak(p, size: 25, weight: FontWeight.w800, spacing: -0.5)),
        const SizedBox(height: 3),
        Text(status, style: _jak(p, size: 15, weight: FontWeight.w500, color: p.muted)),
      ],
    );
  }

  Widget _fallback() => Container(
        color: p.cardHigh,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, color: p.muted, size: 54),
      );
}

// ─────────────── STATS (Daraja / Umumiy XP / Kunlik Seriya) ───────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.p, required this.level, required this.xp, required this.streak});
  final _P p;
  final int level;
  final int xp;
  final int streak;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(p: p, icon: Icons.workspace_premium_rounded, tint: p.aqua, value: '$level', label: 'Daraja')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(p: p, icon: Icons.star_rounded, tint: p.gold, value: _fmtXp(xp), label: 'Umumiy XP')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(p: p, icon: Icons.local_fire_department_rounded, tint: p.fire, value: '$streak', label: 'Kunlik Seriya')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.p, required this.icon, required this.tint, required this.value, required this.label});
  final _P p;
  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withValues(alpha: 0.15)),
            child: Icon(icon, color: tint, size: 23),
          ),
          const SizedBox(height: 10),
          FittedBox(child: Text(value, maxLines: 1, style: _jak(p, size: 22, weight: FontWeight.w800, spacing: -0.5))),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _jak(p, size: 11.5, weight: FontWeight.w600, color: p.muted)),
        ],
      ),
    );
  }
}

// ─────────────── KEYINGI DARAJAGA ───────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.p, required this.remaining, required this.frac, required this.level});
  final _P p;
  final int remaining;
  final double frac;
  final int level;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Keyingi darajaga', style: _jak(p, size: 16, weight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: p.aqua.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                child: Text('$remaining XP qoldi', style: _jak(p, size: 12.5, weight: FontWeight.w700, color: p.aqua)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: p.track,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac.clamp(0.03, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [p.aqua.withValues(alpha: 0.85), p.aqua]),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [BoxShadow(color: p.aqua.withValues(alpha: 0.55), blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Yana $remaining XP to\'plab, ${level + 1}-darajaga ko\'taril!',
            style: _jak(p, size: 13, weight: FontWeight.w400, color: p.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─────────────── YUTUQLAR (grid) ───────────────

class _Achievements extends StatelessWidget {
  const _Achievements({required this.p, required this.unlockedIds});
  final _P p;
  final List<String> unlockedIds;
  @override
  Widget build(BuildContext context) {
    final all = Achievements.all;
    final unlockedCount = all.where((a) => unlockedIds.contains(a.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Yutuqlar', style: _jak(p, size: 18, weight: FontWeight.w700)),
            Text('$unlockedCount / ${all.length}', style: _jak(p, size: 13.5, weight: FontWeight.w700, color: p.aqua)),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: all.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.84,
          ),
          itemBuilder: (_, i) {
            final a = all[i];
            return _BadgeTile(p: p, achievement: a, unlocked: unlockedIds.contains(a.id));
          },
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.p, required this.achievement, required this.unlocked});
  final _P p;
  final Achievement achievement;
  final bool unlocked;
  @override
  Widget build(BuildContext context) {
    final color = achievement.color;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unlocked ? color.withValues(alpha: 0.30) : p.border, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? color.withValues(alpha: 0.16) : p.track,
              border: unlocked ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: unlocked ? [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 14)] : null,
            ),
            child: Icon(unlocked ? achievement.icon : Icons.lock_rounded, color: unlocked ? color : p.locked, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.titleKey.tr(),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: _jak(p, size: 11, weight: FontWeight.w600, color: unlocked ? p.text : p.muted, height: 1.2),
          ),
        ],
      ),
    );
  }
}
