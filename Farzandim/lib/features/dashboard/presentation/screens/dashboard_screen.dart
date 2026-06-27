import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/providers/selected_child_index_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:farzandim/features/gamification/presentation/providers/leaderboard_provider.dart';
import 'package:farzandim/features/location/presentation/providers/child_location_provider.dart';
import 'package:farzandim/features/location/presentation/providers/child_place_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

part 'dashboard_sections.dart';

/// Bir ota-ona maksimal nechta farzand qo'sha oladi (backend ham cheklaydi).
const int _kMaxChildren = 3;

// ─── Parvoz dashboard dizayn tokenlari (onboarding bilan bir xil til) ───
const Color _bg = Color(0xFF00060A);
const Color _blue = Color(0xFF216BFF);
const Color _cardBg = Color(0x12FFFFFF); // oq ~7%
const Color _cardBorder = Color(0x1AFFFFFF); // oq ~10%
const Color _dim = Color(0x8CFFFFFF); // oq 55%
const Color _online = Color(0xFF87FF46); // Telegram uslubidagi yashil
const double _radius = 24;

/// Unbounded sarlavha stili.
TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double? ls,
}) {
  return GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: w,
    color: c,
    letterSpacing: ls,
    height: 1.4,
  );
}

/// Poppins body stili.
TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) {
  return GoogleFonts.poppins(
    fontSize: size,
    fontWeight: w,
    color: c,
    height: 1.5,
  );
}

/// Asosiy ekran — Parvoz dizayni, dinamik bola monitoringi (real ma'lumotlar).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(
      backendAuthProvider.select((s) => s is AuthAuthenticated),
    );
    final childrenAsync = ref.watch(childrenProvider);
    final children = childrenAsync.valueOrNull;

    final Widget body;
    if (!isAuthed) {
      body = const _Loading();
    } else if (children == null) {
      body = childrenAsync.hasError
          ? _ErrorState(
              onRetry: () =>
                  ref.read(childrenRefreshTickProvider.notifier).state++,
            )
          : const _Loading();
    } else if (children.isEmpty) {
      body = childrenAsync.isLoading ? const _Loading() : const _EmptyState();
    } else {
      body = _DashboardBody(children: children);
    }

    return Scaffold(backgroundColor: _bg, body: SafeArea(child: body));
  }
}

// ════════════════════════ HOLATLAR ════════════════════════

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: _blue));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: _dim),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'errors.loadFailedNetwork'.tr(),
              textAlign: TextAlign.center,
              style: _pop(15, c: _dim),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: _blue),
            label: Text(
              'common.retry'.tr(),
              style: _pop(15, w: FontWeight.w600, c: _blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _cardBg,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'dashboard.emptyState.message'.tr(),
            textAlign: TextAlign.center,
            style: _pop(15, c: _dim),
          ),
          const SizedBox(height: 24),
          const _AddChildButton(),
          const Spacer(),
        ],
      ),
    );
  }
}

// ════════════════════════ DASHBOARD BODY ════════════════════════

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.children});

  final List<Child> children;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ilovaga qaytganda bolalar ro'yxatini darhol yangilaymiz — eski
    // snapshot'dagi lastSeenAt bilan noto'g'ri "Aloqa uzildi" ko'rsatmaslik.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(childrenRefreshTickProvider.notifier).state++;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Tepadan tortilganda tanlangan bolaning provayderlarini qayta o'qiydi.
  Future<void> _onRefresh(String childId) async {
    ref.read(childrenRefreshTickProvider.notifier).state++;
    ref
      ..invalidate(todayUsageProvider(childId))
      ..invalidate(weeklyChildUsageProvider(childId))
      ..invalidate(childProfileProvider(childId))
      ..invalidate(childLocationProvider(childId));
    try {
      await Future.wait([
        ref.read(childrenProvider.future),
        ref.read(todayUsageProvider(childId).future),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Tarmoq xatosi/timeout — spinner baribir yopiladi.
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    final selectedIndex = ref
        .watch(selectedChildIndexProvider)
        .clamp(0, children.length - 1);
    final child = children[selectedIndex];

    return Stack(
      children: [
        RefreshIndicator(
          color: _blue,
          backgroundColor: _cardBg,
          onRefresh: () => _onRefresh(child.id),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Pastki padding = bottom bar (≈92) + bo'shliq, oxirgi karta
            // suzuvchi nav ostida qolmaydi.
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                _Header(child: child),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      _LocationCard(child: child),
                      const SizedBox(height: 4),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _ScreenTimeCard(childId: child.id)),
                            const SizedBox(width: 4),
                            Expanded(child: _XpCard(child: child)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const _ScheduleCard(),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.lock_clock_rounded,
                              label: 'dashboard.quickActions.appRestrictions'
                                  .tr(),
                              onTap: () => context.push(
                                AppRoutes.appLimitsPath(child.id),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.insights_rounded,
                              label: 'dashboard.quickActions.weeklyReport'.tr(),
                              comingSoon: true,
                            ),
                          ),
                        ],
                      ),
                      if (children.length < _kMaxChildren) ...[
                        const SizedBox(height: 4),
                        const _AddChildButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Pastki suzuvchi nav — bolalar almashtirgich + sozlamalar.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            children: children,
            selectedIndex: selectedIndex,
            onSelect: (i) =>
                ref.read(selectedChildIndexProvider.notifier).state = i,
          ),
        ),
      ],
    );
  }
}
