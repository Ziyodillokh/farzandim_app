// ─────────────────────────────────────────────────────────────────────
// ChildDashboardScreen — Stitch "Bosh sahifa (Night)" dizayni, REAL data
// ─────────────────────────────────────────────────────────────────────
//
// UI Stitch dizayniga ko'chirildi; backendlar (Riverpod provayderlar) o'zi
// ulanib turadi. Night asosiy palitra; light — sodda oq versiya. Nav o'zgarmadi
// (mavjud ChildBottomNavigation). App-usage = mavjud AppUsageList (real),
// SOS = mavjud SosButton (real, xavfsiz hold-to-send).

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/analytics/presentation/widgets/app_usage_list.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/gamification/data/models/gamification_status.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/ranking/data/models/ranking_user.dart';
import 'package:farzandim_child/features/ranking/presentation/providers/ranking_providers.dart';
import 'package:farzandim_child/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim_child/features/sos/presentation/providers/sos_provider.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────── Stitch palette (night asosiy + sodda light) ───────────────

class _P {
  _P(this.dark);
  final bool dark;

  Color get bg => dark ? const Color(0xFF0B1C30) : const Color(0xFFF8F9FF);
  // Solid toza kartalar — bir xil fon, gradient/aurora YO'Q.
  Color get card => dark ? const Color(0xFF213145) : const Color(0xFFE5EEFF);
  Color get cardSolid => dark ? const Color(0xFF213145) : Colors.white;
  Color get cardGradTo => dark ? const Color(0xFF1A2636) : const Color(0xFFDCE9FF);
  Color get text => dark ? const Color(0xFFF8F9FF) : const Color(0xFF0B1C30);
  Color get muted => dark ? const Color(0xFFCBDBF5) : const Color(0xFF5A6B66);
  Color get variant => dark ? const Color(0xFFD3E4FE) : const Color(0xFF3D4A3D);

  // Aqua brend (avval yashil edi).
  Color get green => dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490);
  Color get greenBtn => const Color(0xFF0E8DA3); // chuqurroq — oq ikonka uchun
  Color get greenBorder => const Color(0xFF16B5C9);
  Color get orange => const Color(0xFFEF9900);
  Color get blueIcon => dark ? const Color(0xFFADC6FF) : const Color(0xFF2170E4);
  Color get blue => const Color(0xFF2170E4);
  Color get blueDeep => dark ? const Color(0xFF0058BE) : const Color(0xFF2170E4);

  Color get progTrack => dark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFD3E4FE);
  // Nozik border — soft definition (soyasiz, dog'siz).
  Color get border => dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD3E4FE);
  Color get divider => dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFD3E4FE);

  // Toza karta — solid fon + nozik border. Soya YO'Q (qora dog' bo'lmasin).
  BoxDecoration glass({double radius = 16}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
      );
}

TextStyle _jak(_P p, {double size = 14, FontWeight weight = FontWeight.w600, Color? color, double? height, double? spacing}) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color ?? p.text, height: height, letterSpacing: spacing);

// ─────────────── SCREEN ───────────────

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});
  @override
  ConsumerState<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen> with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_guardPermissions);
    Future.microtask(_updateStreak);
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshAnalytics());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAnalytics();
  }

  void _refreshAnalytics() {
    if (!mounted) return;
    ref
      ..invalidate(dailyUsageProvider)
      ..invalidate(weeklyUsageProvider)
      ..invalidate(childAppLimitsProvider);
    final pairing = ref.read(pairingStateProvider);
    final childId = pairing.childId;
    if (childId != null) {
      ref
        ..invalidate(childAvatarUrlProvider(childId))
        ..invalidate(childDataStreamProvider((parentUid: pairing.parentUid!, childId: childId)));
    }
  }

  Future<void> _updateStreak() async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;
    try {
      await ref.read(xpServiceProvider).updateStreakOnDailyOpen(parentUid: parentUid, childId: childId);
    } catch (_) {}
  }

  Future<void> _guardPermissions() async {
    if (kIsWeb) return;
    final usageService = UsageStatsService();
    // FAQAT eng zarur 3 ta (permission_setup_screen bilan mos): ilova nazorati,
    // bloklash overlay'i, quvvat optimizatsiyasi. Geolokatsiya/mikrofon endi
    // majburiy emas — ixtiyoriy, keyin Sozlamalar → Ruxsatlardan beriladi.
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final usageGranted = await usageService.hasPermission();
    final overlayGranted = await usageService.hasOverlayPermission();
    final allGranted =
        batteryStatus.isGranted && usageGranted && overlayGranted;
    if (!allGranted && mounted) context.go('/permission-setup');
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);
    final p = _P(context.adaptive.isDark);

    if (!pairing.isPaired || pairing.parentUid == null || pairing.childId == null) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Center(child: CircularProgressIndicator(color: p.green)),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: p.bg,
      extendBody: true,
      body: Stack(
        children: [
          // Skroll kontent (glass header ostidan o'tadi). Fon — bir xil p.bg.
          Positioned.fill(
            child: RefreshIndicator(
              color: p.green,
              backgroundColor: p.cardSolid,
              // Yangilash doirasi glass header OSTIDA chiqsin (aks holda
              // header ortida qolib yarmi kesilib ko'rinadi).
              edgeOffset: topInset + 72,
              onRefresh: () async {
                _refreshAnalytics();
                await Future<void>.delayed(const Duration(milliseconds: 600));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, topInset + 88, 20, 130 + bottomInset),
                children: [
                  UpdateBanner(),
                  _StatsSection(p: p),
                  const SizedBox(height: 26),
                  _VideosSection(p: p),
                  _ScheduleSection(p: p),
                  _FamilySection(p: p),
                  const SizedBox(height: 24),
                  _AdviceCard(p: p),
                  const SizedBox(height: 26),
                  _AudiobookSection(p: p),
                  _AppUsageSection(p: p),
                  const SizedBox(height: 26),
                  _SosCard(p: p),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // 3. Sticky glass header (blur) — status-bar'dan pastda, qulay masofada.
          Positioned(top: 0, left: 0, right: 0, child: _GlassHeader(p: p)),
        ],
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

// ─────────────── GLASS HEADER (sticky, blur) ───────────────

class _GlassHeader extends ConsumerWidget {
  const _GlassHeader({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: p.bg.withValues(alpha: p.dark ? 0.55 : 0.70),
            border: Border(bottom: BorderSide(color: p.border, width: 1)),
          ),
          // status-bar + 22px qulay masofa (avval 8px edi — juda tepada turardi).
          padding: EdgeInsets.fromLTRB(20, topInset + 22, 20, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.green, width: 2)),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/icons/child_logo_icon.png', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: p.cardSolid, child: Icon(Icons.person, color: p.green, size: 20))),
              ),
              const SizedBox(width: 10),
              Text('Parvoz', style: _jak(p, size: 24, weight: FontWeight.w700, color: p.green, spacing: -0.4)),
              const Spacer(),
              _IconBtn(p: p, icon: Icons.notifications_outlined, badge: unread, onTap: () => context.push('/notifications')),
              const SizedBox(width: 10),
              _IconBtn(p: p, icon: Icons.settings_outlined, onTap: () => context.push('/settings')),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.p, required this.icon, required this.onTap, this.badge = 0});
  final _P p;
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) {
    // Stitch: w-10 h-10 rounded-full bg-inverse-surface (dark) / surface-container.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.card, border: Border.all(color: p.border, width: 1)),
            child: Icon(icon, color: p.variant, size: 22),
          ),
          if (badge > 0)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB7185),
                  shape: BoxShape.circle,
                  border: Border.all(color: p.bg, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 9, minHeight: 9),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────── SECTION HEADER ───────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.p, required this.title, this.action, this.onAction});
  final _P p;
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: _jak(p, size: 20, weight: FontWeight.w700, spacing: -0.3)),
        const Spacer(),
        if (action != null)
          GestureDetector(onTap: onAction, child: Text(action!, style: _jak(p, size: 14, weight: FontWeight.w600, color: p.green))),
      ],
    );
  }
}

// ─────────────── STATS ───────────────

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingStateProvider);
    final gamification = ref.watch(gamificationProfileProvider).valueOrNull;
    final users = ref.watch(allUsersProvider);
    // dart2js'da `cast<RankingUser?>().firstWhere(orElse: () => null)` startup'da
    // bo'sh/loading ro'yxatda `null as RankingUser` type-xato berardi (crash).
    // Null-xavfsiz qidiruv — cast yo'q. `me` FINAL (closure'da promote bo'lsin).
    RankingUser? currentUser;
    for (final u in users) {
      if (u.isCurrentUser) {
        currentUser = u;
        break;
      }
    }
    final me = currentUser;
    final xp = gamification?.xp ?? me?.totalScore ?? 0;
    final level = levelForXp(xp);

    String region = me?.region ?? '—';
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid != null && childId != null) {
      final data = ref.watch(childDataStreamProvider((parentUid: parentUid, childId: childId))).valueOrNull;
      final r = data?['region'] as String?;
      if (r != null && r.isNotEmpty) region = r;
    }

    int? regionRank;
    if (me != null) {
      final regional = users.where((u) => u.region == me.region).toList()..sort((a, b) => b.totalScore.compareTo(a.totalScore));
      final idx = regional.indexWhere((u) => u.isCurrentUser);
      if (idx >= 0) regionRank = idx + 1;
    } else if (region != '—' && users.isNotEmpty) {
      regionRank = users.where((u) => u.region == region && u.totalScore > xp).length + 1;
    }

    return Row(
      children: [
        Expanded(child: _StatCard(p: p, icon: Icons.local_fire_department_rounded, tint: p.green, accent: p.greenBorder, value: '${_fmt(xp)} XP')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(p: p, icon: Icons.star_rounded, tint: p.orange, accent: p.orange, value: '$level-Daraja')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(p: p, icon: Icons.emoji_events_rounded, tint: p.blueIcon, accent: p.blue, value: regionRank != null ? '#$regionRank' : '—')),
      ],
    );
  }

  static String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.p, required this.icon, required this.tint, required this.accent, required this.value});
  final _P p;
  final IconData icon;
  final Color tint;
  final Color accent;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: p.card,
        // Uniform border → radius ishlaydi (avval noykbir xil border to'rtburchak qilgan edi).
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 24),
          const SizedBox(height: 6),
          FittedBox(child: Text(value, maxLines: 1, style: _jak(p, size: 13.5, weight: FontWeight.w600, color: p.variant, spacing: 0.1))),
        ],
      ),
    );
  }
}

// ─────────────── VIDEOS ───────────────

class _VideosSection extends ConsumerWidget {
  const _VideosSection({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(topVideosProvider);
    if (videos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(p: p, title: 'Videolar', action: 'Barchasi', onAction: () => context.push('/content')),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => _VideoCard(p: p, video: videos[i]),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.p, required this.video});
  final _P p;
  final VideoModel video;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        width: 240,
        decoration: p.glass(radius: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 128,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.thumbnailUrl.isNotEmpty)
                    Image.network(video.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbFallback())
                  else
                    _thumbFallback(),
                  Container(color: Colors.black.withValues(alpha: 0.30)),
                  const Center(child: Icon(Icons.play_circle_rounded, color: Colors.white, size: 44)),
                  if (video.duration.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                        child: Text(video.duration, style: _jak(p, size: 11, weight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 38,
                child: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _jak(p, size: 14, weight: FontWeight.w600, height: 1.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() => const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B2942), Color(0xFF0E4D57)])),
      );
}

// ─────────────── JADVAL ───────────────

class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todaySchedulesProvider);
    final count = today.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(p: p, title: 'Jadval'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/schedules'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: p.glass(radius: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.blueDeep),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bugungi darslar', style: _jak(p, size: 14, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(count > 0 ? '$count ta dars rejalashtirilgan' : 'Bugun rejalashtirilgan dars yo\'q',
                          style: _jak(p, size: 13, weight: FontWeight.w400, color: p.muted)),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.dark ? const Color(0xFF2A3C54) : const Color(0xFFD3E4FE)),
                  child: Icon(Icons.arrow_forward_rounded, color: p.text, size: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

// ─────────────── MENING OILAM ───────────────

class _FamilySection extends ConsumerWidget {
  const _FamilySection({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final parentInfo = parentUid != null ? ref.watch(parentInfoProvider(parentUid)).valueOrNull : null;
    final parentName = (parentInfo?['displayName'] as String?) ?? 'Ota-onangiz';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(p: p, title: 'Mening oilam'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: p.glass(radius: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.blue, p.green])),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(parentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _jak(p, size: 14, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: p.green, size: 16),
                        const SizedBox(width: 5),
                        Text('Ota-ona ulangan', style: _jak(p, size: 13, weight: FontWeight.w600, color: p.green)),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/voice-chat'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.blueDeep),
                  child: const Icon(Icons.chat_rounded, color: Colors.white, size: 19),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────── BUGUNGI MASLAHAT ───────────────

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: p.glass(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.orange.withValues(alpha: 0.2)),
            child: Icon(Icons.lightbulb_rounded, color: p.orange, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bugungi maslahat', style: _jak(p, size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('Internetda xavfsizlikni ta\'minlash uchun parollaringizni hech kimga aytmang.',
                    style: _jak(p, size: 13, weight: FontWeight.w400, color: p.muted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── AUDIO KITOBLAR ───────────────

class _AudiobookSection extends ConsumerWidget {
  const _AudiobookSection({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(forYouAudiobooksProvider);
    if (books.isEmpty) return const SizedBox.shrink();
    final book = books.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(p: p, title: 'Audio kitoblar', action: 'Barchasi', onAction: () => context.push('/content')),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            ref.read(audioPlayerProvider.notifier).play(book);
            context.push('/audio-player');
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: p.glass(radius: 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: book.coverUrl.isNotEmpty
                        ? Image.network(book.coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _coverFallback())
                        : _coverFallback(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _jak(p, size: 14, weight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: _jak(p, size: 12.5, weight: FontWeight.w500, color: p.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.greenBtn),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }

  Widget _coverFallback() => const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C3AED), Color(0xFF2563EB)])),
        child: Icon(Icons.headphones_rounded, color: Colors.white, size: 26),
      );
}

// ─────────────── SOS — "Biz doim yoningizdamiz!" (Stitch qizil karta + real hold-to-send) ───────────────

class _SosCard extends ConsumerStatefulWidget {
  const _SosCard({required this.p});
  final _P p;
  @override
  ConsumerState<_SosCard> createState() => _SosCardState();
}

class _SosCardState extends ConsumerState<_SosCard> with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);
  late final AnimationController _progress;
  Timer? _holdTimer;
  bool _holding = false;
  Offset? _downPos;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _holdDuration);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  // Tasodifan bosishni oldini olish — barmoqni 3 sekund ushlab turish kerak.
  // Xom Listener (pointer) ishlatamiz: ListView ichida gesture arena tap'ni
  // scroll'ga yutqazib yubormaydi, shuning uchun hold ishonchli ishlaydi.
  void _startHold(Offset pos) {
    if (_holding) return;
    _downPos = pos;
    HapticFeedback.lightImpact();
    _progress.forward(from: 0);
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDuration, _send);
    setState(() => _holding = true);
  }

  // Barmoq sezilarli siljisa — bu scroll, hold emas → bekor qilamiz.
  void _onMove(Offset pos) {
    if (!_holding || _downPos == null) return;
    if ((pos - _downPos!).distance > 16) _cancelHold();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _downPos = null;
    _progress.reverse();
    if (mounted) setState(() => _holding = false);
  }

  Future<void> _send() async {
    _holdTimer = null;
    _downPos = null;
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _holding = false);
    await ref.read(sosStateProvider.notifier).send();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        ref.read(sosStateProvider.notifier).reset();
        _progress.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final dark = p.dark;
    // Solid qizil karta + nozik oq border.
    final cardBg = dark ? const Color(0xFF310002) : const Color(0xFFFFDAD6);
    final glow = dark ? const Color(0xFF93000A) : const Color(0xFFFF897D);
    final accent = dark ? const Color(0xFFFFB4AB) : const Color(0xFF93000A);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.12 : 0.06), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Yuqori-o'ng burchakdagi yumshoq glow (Stitch blur-3xl).
          Positioned(
            top: -52,
            right: -52,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: glow.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.20)),
                child: Icon(Icons.verified_user_rounded, color: accent, size: 30),
              ),
              const SizedBox(height: 12),
              Text('Biz doim yoningizdamiz!',
                  textAlign: TextAlign.center,
                  style: _jak(p, size: 20, weight: FontWeight.w700, color: accent, spacing: -0.2)),
              const SizedBox(height: 8),
              Text(
                'Agar o\'zingizni noqulay yoki xavf ostida his qilsangiz, zudlik bilan SOS tugmasini bosing.',
                textAlign: TextAlign.center,
                style: _jak(p, size: 13.5, weight: FontWeight.w400, color: accent.withValues(alpha: 0.80), height: 1.45),
              ),
              const SizedBox(height: 18),
              _button(dark),
              if (ref.watch(sosStateProvider).status == SosStatus.idle) ...[
                const SizedBox(height: 10),
                Text('Yuborish uchun 3 soniya bosib turing',
                    textAlign: TextAlign.center,
                    style: _jak(p, size: 11.5, weight: FontWeight.w500, color: accent.withValues(alpha: 0.65))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(bool dark) {
    final p = widget.p;
    final sos = ref.watch(sosStateProvider);
    const deepRed = Color(0xFF93000A);

    final sending = sos.status == SosStatus.sending;
    final sent = sos.status == SosStatus.sent;
    final isError = sos.status == SosStatus.error;
    final disabled = sending || sent;

    Color btnBg = dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);
    Color btnText = dark ? const Color(0xFF310002) : Colors.white;
    if (sent) {
      btnBg = const Color(0xFF22C55E);
      btnText = Colors.white;
    } else if (isError) {
      btnBg = const Color(0xFFEF9900);
      btnText = Colors.white;
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: disabled ? null : (e) => _startHold(e.position),
      onPointerMove: disabled ? null : (e) => _onMove(e.position),
      onPointerUp: disabled ? null : (_) => _cancelHold(),
      onPointerCancel: disabled ? null : (_) => _cancelHold(),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final pressed = _holding;
          final fill = _progress.value;

          IconData? icon;
          String label;
          var spinner = false;
          if (sending) {
            spinner = true;
            label = 'Yuborilmoqda…';
          } else if (sent) {
            icon = Icons.check_circle_rounded;
            label = 'Yuborildi';
          } else if (isError) {
            icon = Icons.error_outline_rounded;
            label = 'Qayta urining';
          } else if (pressed) {
            icon = Icons.campaign_rounded;
            final remaining = (_holdDuration.inSeconds * (1 - fill)).ceil().clamp(1, 3);
            label = 'Ushlab turing… ${remaining}s';
          } else {
            icon = Icons.campaign_rounded;
            label = 'Yordam chaqirish';
          }

          return Transform.translate(
            offset: Offset(0, pressed ? 2 : 0),
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(color: deepRed, offset: Offset(0, pressed ? 2 : 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 3 sekund hold progress — chap → o'ng to'ladi.
                  if (pressed && fill > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: ColoredBox(color: deepRed.withValues(alpha: 0.55)),
                      ),
                    ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (spinner)
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: btnText))
                        else if (icon != null)
                          Icon(icon, color: btnText, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _jak(p, size: 15.5, weight: FontWeight.w700, color: btnText, spacing: 0.2)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────── ILOVADAN FOYDALANISH (mavjud AppUsageList, Stitch karta) ───────────────

class _AppUsageSection extends ConsumerWidget {
  const _AppUsageSection({required this.p});
  final _P p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(dailyUsageProvider).valueOrNull?.apps.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(p: p, title: 'Ilovadan foydalanish'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: p.glass(radius: 14),
          child: Column(
            children: [
              const AppUsageList(limit: 5),
              if (total > 5) ...[
                Divider(color: p.divider, height: 1),
                GestureDetector(
                  onTap: () => context.push('/analytics'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('Hammasini ko\'rish ($total)', style: _jak(p, size: 13.5, weight: FontWeight.w700, color: p.green))),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
