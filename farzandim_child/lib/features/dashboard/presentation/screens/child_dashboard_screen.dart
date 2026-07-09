// ─────────────────────────────────────────────────────────────────────
// ChildDashboardScreen — "Asosiy" (Figma redizayn, Parvoz ko'k)
// ─────────────────────────────────────────────────────────────────────
//
// Tuzilishi (Figma 1:1):
//   • Header: "Asosiy" + chat + bildirishnoma (qizil nuqta)
//   • 3 stat chip: 🔥 streak | 👟 qadamlar | 💎 DON balans
//   • "Yangi testlar" ko'k banner → /contests
//   • "Yangi kitoblar" karta (3 muqova) → /books
//   • "Trend videolar" gorizontal lenta → /video-player
//
// Real ma'lumot: gamificationProfileProvider (don/streak), todayStepsProvider,
// recommendedBooksProvider, topVideosProvider, activeContestsProvider,
// unreadNotificationsCountProvider. Router/permission guard'lar saqlangan.

import 'dart:async';

import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/providers/books_providers.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

// ════════════ Parvoz tokenlar (ko'k, pairing/onboarding bilan mos) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF10161F);
const _chipBg = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF);
const _dim = Color(0x99FFFFFF);
const _amber = Color(0xFFFF9F1C);
const _green = Color(0xFF34C759);

TextStyle _unb(
  double s, {
  FontWeight w = FontWeight.w700,
  Color c = Colors.white,
}) => GoogleFonts.unbounded(
  fontSize: s,
  fontWeight: w,
  color: c,
  letterSpacing: -0.4,
  height: 1.2,
);

TextStyle _pop(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: s, fontWeight: w, color: c, height: 1.35);

String _fmtNum(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String _fmtViews(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return '$v';
}

/// Bola bosh ekrani — "Asosiy".
class ChildDashboardScreen extends ConsumerStatefulWidget {
  /// `ChildDashboardScreen` konstruktor.
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_guardPermissions);
    Future.microtask(_updateStreak);
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    ref
      ..invalidate(todayStepsProvider)
      ..invalidate(backendContestsProvider);
  }

  Future<void> _updateStreak() async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;
    try {
      await ref
          .read(xpServiceProvider)
          .updateStreakOnDailyOpen(parentUid: parentUid, childId: childId);
    } catch (_) {}
  }

  Future<void> _guardPermissions() async {
    if (kIsWeb) return;
    final usageService = UsageStatsService();
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
    if (!pairing.isPaired) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: const ChildBottomNavigation(),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _card,
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 120 + bottomInset),
            children: const [
              UpdateBanner(),
              _Header(),
              SizedBox(height: 18),
              _StatChipsRow(),
              SizedBox(height: 14),
              _TestsBanner(),
              SizedBox(height: 18),
              _BooksSection(),
              SizedBox(height: 22),
              _VideosSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Header: "Asosiy" + chat + bell ════════════

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return Row(
      children: [
        Expanded(child: Text('Asosiy', style: _unb(26))),
        _RoundIconButton(
          icon: Icons.chat_bubble_rounded,
          onTap: () => context.push('/voice-chat'),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: Icons.notifications_rounded,
          showDot: unread > 0,
          onTap: () => context.push('/notifications'),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          if (showDot)
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4F),
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════ 3 stat chip (streak / qadamlar / DON) ════════════

class _StatChipsRow extends ConsumerWidget {
  const _StatChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    // PREVIEW: real qiymat 0 bo'lsa Figma'dagi namuna ko'rsatiladi
    // (bola faollik boshlagach realga avtomatik almashadi).
    final rawStreak = profile?.streak ?? 0;
    final rawDon = profile?.don ?? 0;
    final rawSteps = ref.watch(todayStepsProvider).valueOrNull ?? 0;
    final streak = rawStreak > 0 ? rawStreak : 7;
    final don = rawDon > 0 ? rawDon : 1250;
    final steps = rawSteps > 0 ? rawSteps : 10000;
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            tint: _amber,
            icon: const Icon(
              Icons.local_fire_department_rounded,
              size: 22,
              color: _amber,
            ),
            value: '$streak kun',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            tint: _blue,
            icon: Image.asset(
              'assets/icons/ic_steps.png',
              width: 22,
              height: 22,
            ),
            value: _fmtNum(steps),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            tint: _green,
            icon: const Icon(Icons.token_rounded, size: 22, color: _green),
            value: _fmtNum(don),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: _DonLabel(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DonLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('DON', style: _pop(9, w: FontWeight.w700));
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.tint,
    required this.icon,
    required this.value,
    this.trailing,
  });

  final Color tint;
  final Widget icon;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.10), _card),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(15, w: FontWeight.w700),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 5),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════ "Yangi testlar" banner ════════════

class _TestsBanner extends ConsumerWidget {
  const _TestsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeContestsProvider);
    final subtitle = active.isEmpty
        ? 'Tez orada yangi testlar'
        : '${active.length} ta faol test';
    return GestureDetector(
      onTap: () => context.push('/contests'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E4FBF), Color(0xFF12294F)],
          ),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // O'ngdagi olti burchakli test belgisi.
            Positioned(
              right: 14,
              top: 18,
              child: _HexBadge(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 130, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yangi testlar', style: _unb(20)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: _pop(13, c: _dim)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x40FFFFFF)),
                    ),
                    child: Text('Batafsil', style: _pop(13, w: FontWeight.w500)),
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

/// Olti burchakli ko'k nishon + test-qalam ikoni (banner bezagi).
class _HexBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: _HexClipper(),
            child: Container(
              width: 108,
              height: 116,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4D8DFF), Color(0xFF1B54D9)],
                ),
              ),
            ),
          ),
          Image.asset('assets/icons/ic_tests.png', width: 46, height: 46),
        ],
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ════════════ "Yangi kitoblar" ════════════

class _BooksSection extends ConsumerWidget {
  const _BooksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(recommendedBooksProvider).take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Yangi kitoblar',
            onTap: () => context.push('/books'),
          ),
          const SizedBox(height: 14),
          if (books.isEmpty)
            // PREVIEW: backend'da kitob yo'q — namunaviy muqovalar.
            const Row(
              children: [
                Expanded(
                  child: _MockBookCard(
                    title: 'Buyuk\nsarguzasht',
                    color: Color(0xFFD96C2C),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MockBookCard(
                    title: 'Oy sari\nparvoz',
                    color: Color(0xFF1F3A5F),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _MockBookCard(
                    title: 'Oltin\nertaklar',
                    color: Color(0xFFF2C21B),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                for (var i = 0; i < books.length; i++) ...[
                  Expanded(child: _BookCard(book: books[i])),
                  if (i < books.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final BookModel book;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/books/pdf', extra: book),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: book.hasCover
                  ? Image.network(
                      book.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _CoverFallback(book: book),
                    )
                  : _CoverFallback(book: book),
            ),
          ),
          const SizedBox(height: 8),
          // TODO(backend): kitob narxi backend'dan kelganda shu yerga ulanadi.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('250 DON', style: _pop(10, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.book});

  final BookModel book;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: book.coverColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        book.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: _pop(11, w: FontWeight.w600),
      ),
    );
  }
}

// ════════════ "Trend videolar" ════════════

class _VideosSection extends ConsumerWidget {
  const _VideosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(topVideosProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Trend videolar',
          onTap: () => context.push('/videos'),
        ),
        const SizedBox(height: 12),
        if (videos.isEmpty)
          // PREVIEW: backend'da video yo'q — namunaviy kartalar.
          SizedBox(
            height: 236,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: const [
                _MockVideoCard(
                  title: 'Jump challenge',
                  views: '169K',
                  color: Color(0xFFD64B12),
                ),
                SizedBox(width: 12),
                _MockVideoCard(
                  title: 'Multfilm olami',
                  views: '96K',
                  color: Color(0xFF2E7D5B),
                ),
                SizedBox(width: 12),
                _MockVideoCard(
                  title: 'Qiziq tajribalar',
                  views: '54K',
                  color: Color(0xFF5B4B8A),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _VideoCard(video: videos[i]),
            ),
          ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 300,
                height: 168,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.thumbnailUrl.isNotEmpty)
                      Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            ColoredBox(color: video.thumbnailColor),
                      )
                    else
                      ColoredBox(color: video.thumbnailColor),
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    video.title.isNotEmpty ? video.title[0].toUpperCase() : '?',
                    style: _pop(16, w: FontWeight.w700, c: _bg),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _unb(14, w: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: _dim,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _fmtViews(video.views),
                            style: _pop(12, c: _dim),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ PREVIEW kartalar (backend bo'sh bo'lganda) ════════════

/// Namunaviy kitob muqovasi — rangli fon + nom + "250 DON" pill.
class _MockBookCard extends StatelessWidget {
  const _MockBookCard({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.72,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, Color.lerp(color, Colors.black, 0.35)!],
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: _unb(12, w: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('250 DON', style: _pop(10, w: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Namunaviy video kartasi — rangli thumbnail + play + avatar + ko'rishlar.
class _MockVideoCard extends StatelessWidget {
  const _MockVideoCard({
    required this.title,
    required this.views,
    required this.color,
  });

  final String title;
  final String views;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 300,
              height: 168,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, Colors.black, 0.4)!],
                ),
              ),
              child: Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  title[0].toUpperCase(),
                  style: _pop(16, w: FontWeight.w700, c: _bg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(14, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: _dim,
                        ),
                        const SizedBox(width: 4),
                        Text(views, style: _pop(12, c: _dim)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════ Bo'lim sarlavhasi (title + chevron) ════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(child: Text(title, style: _unb(19))),
          const Icon(Icons.chevron_right_rounded, size: 26, color: Colors.white),
        ],
      ),
    );
  }
}
