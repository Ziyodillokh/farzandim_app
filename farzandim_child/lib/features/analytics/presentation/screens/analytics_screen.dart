// ─────────────────────────────────────────────────────────────────────
// AnalyticsScreen — "Ilovalar" 3 tab (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// 3 ta tab swipe bilan navigatsiya:
//   0. Barchasi — foydalanish vaqti DESC (AppUsageList)
//   1. Vaqt cheklovi — Parent limit qo'ygan ilovalar + qolgan vaqt
//   2. Bloklangan — Parent block qo'ygan ilovalar
//
// LOGIKA SAQLANGAN: provider'lar, navigatsiya, cheklov/bloklash mantiq
// FAQAT KO'RINISH o'zgargan: parvoz night/glass tokenlar

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/analytics/data/repositories/backend_analytics_repository.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/analytics/presentation/widgets/app_usage_list.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/shared/widgets/app_icon_memory.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: AppColors.parvozBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            AppIcons.back,
            color: AppColors.parvozText,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text(
          'Ilovalar',
          style: TextStyle(
            color: AppColors.parvozText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.parvozSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.parvozBorderStrong),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.parvozGreen,
                borderRadius: BorderRadius.circular(11),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: AppColors.parvozOnGreen,
              unselectedLabelColor: AppColors.parvozTextDim,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Barchasi'),
                Tab(text: 'Vaqt cheklovi'),
                Tab(text: 'Bloklangan'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: TabBarView(
          controller: _tabController,
          children: const [
            _AllAppsTab(),
            _LimitedAppsTab(),
            _BlockedAppsTab(),
          ],
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

// ─── Tab 0: All apps ─────────────────────────────────────────────────

class _AllAppsTab extends StatelessWidget {
  const _AllAppsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: AppUsageList(),
    );
  }
}

// ─── Tab 1: Limited apps (with usage progress) ───────────────────────

class _LimitedAppsTab extends ConsumerWidget {
  const _LimitedAppsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitsAsync = ref.watch(childAppLimitsProvider);
    final installedAsync = ref.watch(installedAppsMapProvider);
    final usageAsync = ref.watch(dailyUsageProvider);

    return limitsAsync.when(
      loading: () => const _Loading(),
      error: (_, __) => const _Empty(text: "Cheklovlar yuklanmadi"),
      data: (limits) {
        final limited = limits
            .where((l) => l.isActive && !l.isFullBlock && l.dailyLimitMs > 0)
            .toList()
          ..sort((a, b) => a.dailyLimitMs.compareTo(b.dailyLimitMs));

        if (limited.isEmpty) {
          return const _Empty(
            text: "Vaqt cheklovi qo'yilmagan",
            icon: AppIcons.hourglass,
            color: AppColors.warning,
          );
        }

        final installed =
            installedAsync.valueOrNull ?? const <String, InstalledAppMeta>{};
        final usageByPkg = <String, int>{};
        for (final app in usageAsync.valueOrNull?.apps ?? const []) {
          usageByPkg[app.packageName] = app.totalTimeMs;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Container(
            decoration: parvozGlassFlat(radius: 16).copyWith(
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < limited.length; i++) ...[
                  _LimitTile(
                    limit: limited[i],
                    meta: installed[limited[i].packageName],
                    usedMs: usageByPkg[limited[i].packageName] ?? 0,
                  ),
                  if (i < limited.length - 1)
                    const Divider(
                      color: AppColors.parvozBorderStrong,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Tab 2: Blocked apps ─────────────────────────────────────────────

class _BlockedAppsTab extends ConsumerWidget {
  const _BlockedAppsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitsAsync = ref.watch(childAppLimitsProvider);
    final installedAsync = ref.watch(installedAppsMapProvider);

    return limitsAsync.when(
      loading: () => const _Loading(),
      error: (_, __) => const _Empty(text: "Cheklovlar yuklanmadi"),
      data: (limits) {
        final blocked = limits
            .where((l) => l.isActive && l.isFullBlock)
            .toList();

        if (blocked.isEmpty) {
          return const _Empty(
            text: "Bloklangan ilova yo'q",
            icon: AppIcons.block,
            color: AppColors.error,
          );
        }

        final installed =
            installedAsync.valueOrNull ?? const <String, InstalledAppMeta>{};

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Container(
            decoration: parvozGlassFlat(radius: 16).copyWith(
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < blocked.length; i++) ...[
                  _BlockTile(
                    limit: blocked[i],
                    meta: installed[blocked[i].packageName],
                  ),
                  if (i < blocked.length - 1)
                    const Divider(
                      color: AppColors.parvozBorderStrong,
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Tile widgets ────────────────────────────────────────────────────

class _LimitTile extends StatelessWidget {
  const _LimitTile({
    required this.limit,
    required this.meta,
    required this.usedMs,
  });

  final AppLimit limit;
  final InstalledAppMeta? meta;
  final int usedMs;

  @override
  Widget build(BuildContext context) {
    final appName = meta?.appName ?? limit.packageName;
    final limitMs = limit.dailyLimitMs;
    final remainingMs = limitMs - usedMs;
    final percent = limitMs == 0 ? 0.0 : (usedMs / limitMs).clamp(0.0, 1.0);
    final overLimit = remainingMs <= 0;
    final accent = overLimit ? AppColors.error : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _Icon(
            packageName: limit.packageName,
            iconBase64: meta?.iconBase64,
            iconUrl: meta?.iconUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.parvozText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatMs(usedMs)} / ${_formatMs(limitMs)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: accent,
                    fontWeight: overLimit ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent.toDouble(),
                    minHeight: 4,
                    backgroundColor: AppColors.parvozBorderStrong,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                overLimit ? 'Tugadi' : 'Qoldi',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.parvozTextDim,
                ),
              ),
              Text(
                overLimit ? '—' : _formatMs(remainingMs),
                style: TextStyle(
                  fontSize: 13,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatMs(int ms) {
    if (ms <= 0) return '0m';
    final m = ms ~/ 60000;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h == 0) return '${mm}m';
    if (mm == 0) return '${h}s';
    return '${h}s ${mm}m';
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.limit, required this.meta});

  final AppLimit limit;
  final InstalledAppMeta? meta;

  @override
  Widget build(BuildContext context) {
    final appName = meta?.appName ?? limit.packageName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _Icon(
            packageName: limit.packageName,
            iconBase64: meta?.iconBase64,
            iconUrl: meta?.iconUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.parvozText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  limit.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.parvozTextDim,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.block, color: AppColors.error, size: 13),
                SizedBox(width: 4),
                Text(
                  'Bloklangan',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

// ─── App icon ────────────────────────────────────────────────────────

class _Icon extends StatelessWidget {
  const _Icon({
    required this.packageName,
    this.iconBase64,
    this.iconUrl,
  });

  final String packageName;
  final String? iconBase64;
  final String? iconUrl;

  static const double _size = 40;
  static const _palette = [
    AppColors.catIndigo,
    AppColors.catPurple,
    AppColors.catPink,
    AppColors.danger,
    AppColors.warning,
    AppColors.catEmerald,
    AppColors.catBlue,
    AppColors.catTeal,
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          iconUrl!,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    if (iconBase64 != null && iconBase64!.isNotEmpty) {
      return AppIconMemory(
        base64: iconBase64,
        size: _size,
        borderRadius: radius,
        fallback: _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final color =
        _palette[packageName.codeUnits.fold<int>(0, (a, b) => a + b) %
            _palette.length];
    final initials =
        packageName.split('.').last.padRight(2).substring(0, 2).toUpperCase();
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.trim().isEmpty ? '?' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Placeholders ────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.parvozGreen),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.text,
    this.icon = Icons.inbox_rounded,
    this.color = AppColors.parvozTextDim,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
