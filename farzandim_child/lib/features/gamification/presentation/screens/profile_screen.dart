// ─────────────────────────────────────────────────────────────────────
// ProfileScreen — Stitch "Profil (Night)" dizayniga mos, REAL data bilan
// ─────────────────────────────────────────────────────────────────────
//
// Tartib (Stitch): TopBar → katta avatar + "Daraja N" badge → ism + status →
// 2 stat (Kunlik Seriya / Umumiy XP) → Keyingi Darajaga progress + maslahat →
// Yutuqlar (badge'lar). Night asosiy palitra; light — sodda oq versiya.
// Ma'lumotlar: gamificationProfileProvider (xp/streak/level/status/yutuqlar).

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

// ─────────────── Stitch palette (night asosiy + sodda light) ───────────────

class _P {
  _P(this.dark);
  final bool dark;

  Color get bg => dark ? const Color(0xFF0B1C30) : const Color(0xFFF8F9FF);
  Color get clay => dark ? const Color(0xFF112642) : Colors.white;
  Color get text => dark ? Colors.white : const Color(0xFF0B1C30);
  Color get muted => dark ? const Color(0xFFCBDBF5) : const Color(0xFF5A6B66);
  Color get variant => dark ? const Color(0xFFD3E4FE) : const Color(0xFF3D4A3D);

  Color get green => dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490); // aqua brend
  Color get orangeFlame => const Color(0xFFFFB95F);
  Color get badge => const Color(0xFFEF9900);
  Color get badgeText => const Color(0xFF5C3800);
  Color get blueRing => const Color(0xFF2170E4);
  Color get progTrack => dark ? const Color(0xFF08121F) : const Color(0xFFE3EAF6);
  Color get locked => const Color(0xFF6D7B6C);
  Color get border => dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFD3E4FE);
}

TextStyle _jak(_P p, {double size = 14, FontWeight weight = FontWeight.w600, Color? color, double? height, double? spacing}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color ?? p.text, height: height, letterSpacing: spacing);

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
    // Yangi yutuq unlock bo'lsa — confetti + toast.
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

    final p = _P(context.adaptive.isDark);
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
              loading: () => Center(child: CircularProgressIndicator(color: p.green)),
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
              colors: const [Color(0xFF22D3EE), Color(0xFFFFB95F), Color(0xFF2170E4), Color(0xFFEF9900), Color(0xFFADC6FF)],
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 150 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        children: [
          _TopBar(p: p),
          const SizedBox(height: 8),
          _ProfileHeader(p: p, name: childName, status: profile.status.translationKey.tr(), level: level, avatarUrl: avatarUrl),
          const SizedBox(height: 28),
          _StatsRow(p: p, streak: profile.streak, xp: profile.xp),
          const SizedBox(height: 16),
          _ProgressCard(p: p, remaining: remaining, frac: frac, level: level),
          const SizedBox(height: 28),
          _Achievements(p: p, unlockedIds: profile.unlockedAchievements),
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.green, width: 2)),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/icons/child_logo_icon.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: p.clay, child: Icon(Icons.person, color: p.green, size: 20))),
        ),
        const SizedBox(width: 10),
        Text('Parvoz', style: _jak(p, size: 22, weight: FontWeight.w700, color: p.green, spacing: -0.4)),
        const Spacer(),
        _IconBtn(p: p, icon: Icons.notifications_outlined, onTap: () => context.push('/notifications')),
        const SizedBox(width: 4),
        _IconBtn(p: p, icon: Icons.settings_outlined, onTap: () => context.push('/settings')),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.p, required this.icon, required this.onTap});
  final _P p;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: p.variant, size: 24),
      splashRadius: 22,
    );
  }
}

// ─────────────── PROFILE HEADER ───────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.p, required this.name, required this.status, required this.level, required this.avatarUrl});
  final _P p;
  final String name;
  final String status;
  final int level;
  final String? avatarUrl;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 128,
          height: 140,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Glow.
              Positioned(
                top: 8,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: p.blueRing.withValues(alpha: 0.35), blurRadius: 30, spreadRadius: 4)],
                  ),
                ),
              ),
              // Avatar + blue ring.
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.blueRing, width: 4)),
                clipBehavior: Clip.antiAlias,
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(avatarUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarFallback(), loadingBuilder: (_, c, pr) => pr == null ? c : _avatarFallback())
                    : _avatarFallback(),
              ),
              // "Daraja N" badge.
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.badge,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: p.bg, width: 2),
                    boxShadow: [BoxShadow(color: p.badge.withValues(alpha: 0.5), blurRadius: 12)],
                  ),
                  child: Text('Daraja $level', style: _jak(p, size: 13, weight: FontWeight.w700, color: p.badgeText)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _jak(p, size: 26, weight: FontWeight.w700, spacing: -0.4)),
        const SizedBox(height: 2),
        Text(status, style: _jak(p, size: 16, weight: FontWeight.w500, color: p.muted)),
      ],
    );
  }

  Widget _avatarFallback() => Container(
        color: p.clay,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, color: p.muted, size: 56),
      );
}

// ─────────────── STATS (Kunlik Seriya / Umumiy XP) ───────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.p, required this.streak, required this.xp});
  final _P p;
  final int streak;
  final int xp;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _BigStat(p: p, icon: Icons.local_fire_department_rounded, tint: p.orangeFlame, value: '$streak', label: 'Kunlik Seriya')),
        const SizedBox(width: 12),
        Expanded(child: _BigStat(p: p, icon: Icons.star_rounded, tint: p.green, value: '$xp', label: 'Umumiy XP')),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.p, required this.icon, required this.tint, required this.value, required this.label});
  final _P p;
  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: p.clay,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.dark ? 0.2 : 0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Icon(icon, color: tint, size: 36),
          const SizedBox(height: 8),
          FittedBox(child: Text(value, style: _jak(p, size: 44, weight: FontWeight.w800, height: 1.0, spacing: -1))),
          const SizedBox(height: 4),
          Text(label, style: _jak(p, size: 13.5, weight: FontWeight.w600, color: p.variant)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.clay,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: p.dark ? 0.2 : 0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Keyingi Darajaga', style: _jak(p, size: 20, weight: FontWeight.w700)),
              Text('$remaining XP qoldi', style: _jak(p, size: 14, weight: FontWeight.w600, color: p.green)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 12,
            decoration: BoxDecoration(color: p.progTrack, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.green,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [BoxShadow(color: p.green.withValues(alpha: 0.6), blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Yana $remaining XP to\'plab, ${level + 1}-darajaga ko\'taril!',
              textAlign: TextAlign.center,
              style: _jak(p, size: 14, weight: FontWeight.w400, color: p.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── YUTUQLAR ───────────────

class _Achievements extends StatelessWidget {
  const _Achievements({required this.p, required this.unlockedIds});
  final _P p;
  final List<String> unlockedIds;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Yutuqlar', style: _jak(p, size: 20, weight: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: Achievements.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final a = Achievements.all[i];
              return _BadgeCard(p: p, achievement: a, unlocked: unlockedIds.contains(a.id));
            },
          ),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.p, required this.achievement, required this.unlocked});
  final _P p;
  final Achievement achievement;
  final bool unlocked;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.6,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.clay,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked ? achievement.color.withValues(alpha: 0.18) : const Color(0xFF08121F),
                border: unlocked ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                boxShadow: unlocked ? [BoxShadow(color: achievement.color.withValues(alpha: 0.4), blurRadius: 14)] : null,
              ),
              child: Icon(
                unlocked ? achievement.icon : Icons.lock_rounded,
                color: unlocked ? achievement.color : p.locked,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              achievement.titleKey.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _jak(p, size: 13, weight: FontWeight.w600, color: unlocked ? p.text : p.locked),
            ),
          ],
        ),
      ),
    );
  }
}
