// ─────────────────────────────────────────────────────────────────────
// AppRestrictionsList — Parent qo'ygan cheklovlar (Sprint 4.4.33+34)
//                       (Parvoz NIGHT/GLASS redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// 2 ta alohida expandable section:
//   - "Bloklangan ilovalar" (dailyLimitMs == 0) — qizil aksent
//   - "Vaqt cheklovi" (dailyLimitMs > 0) — sariq aksent + "X daq/kun"
//
// Header tap → list ochiladi/yopiladi (chevron rotate animation +
// AnimatedSize content). Default: ikkalasi yopiq (kam joy egallaydi).
//
// LOGIKA SAQLANGAN — faqat ko'rinish parvoz night/glass tokenlar

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/analytics/data/repositories/backend_analytics_repository.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/shared/widgets/app_icon_memory.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppRestrictionsList extends ConsumerStatefulWidget {
  const AppRestrictionsList({super.key});

  @override
  ConsumerState<AppRestrictionsList> createState() =>
      _AppRestrictionsListState();
}

class _AppRestrictionsListState extends ConsumerState<AppRestrictionsList> {
  bool _blockedExpanded = false;
  bool _limitedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final limitsAsync = ref.watch(childAppLimitsProvider);
    final installedAsync = ref.watch(installedAppsMapProvider);

    return limitsAsync.when(
      loading: () => const _Skeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (limits) {
        if (limits.isEmpty) return const SizedBox.shrink();
        final installed =
            installedAsync.valueOrNull ?? const <String, InstalledAppMeta>{};

        final blocked = limits
            .where((l) => l.isActive && l.isFullBlock)
            .toList();
        final limited =
            limits
                .where(
                  (l) => l.isActive && !l.isFullBlock && l.dailyLimitMs > 0,
                )
                .toList()
              ..sort((a, b) => a.dailyLimitMs.compareTo(b.dailyLimitMs));

        if (blocked.isEmpty && limited.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (blocked.isNotEmpty) ...[
              _ExpandableSection(
                title: 'analytics.blockedSection'.tr(),
                count: blocked.length,
                icon: AppIcons.block,
                color: AppColors.error,
                expanded: _blockedExpanded,
                onTap: () =>
                    setState(() => _blockedExpanded = !_blockedExpanded),
                body: _RestrictionCard(
                  accent: AppColors.error,
                  children: [
                    for (var i = 0; i < blocked.length; i++) ...[
                      _BlockedTile(
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
              if (limited.isNotEmpty) const SizedBox(height: 12),
            ],
            if (limited.isNotEmpty)
              _ExpandableSection(
                title: 'analytics.limitedSection'.tr(),
                count: limited.length,
                icon: AppIcons.hourglass,
                color: AppColors.warning,
                expanded: _limitedExpanded,
                onTap: () =>
                    setState(() => _limitedExpanded = !_limitedExpanded),
                body: _RestrictionCard(
                  accent: AppColors.warning,
                  children: [
                    for (var i = 0; i < limited.length; i++) ...[
                      _LimitedTile(
                        limit: limited[i],
                        meta: installed[limited[i].packageName],
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
          ],
        );
      },
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.expanded,
    required this.onTap,
    required this.body,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          count: count,
          icon: icon,
          color: color,
          expanded: expanded,
          onTap: onTap,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: expanded
                  ? Padding(
                      key: const ValueKey('expanded'),
                      padding: const EdgeInsets.only(top: 8),
                      child: body,
                    )
                  : const SizedBox(
                      key: ValueKey('collapsed'),
                      width: double.infinity,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.parvozBorderStrong,
        highlightColor: AppColors.parvozBorderStrong,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.parvozText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  AppIcons.expandMore,
                  color: AppColors.parvozTextDim,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestrictionCard extends StatelessWidget {
  const _RestrictionCard({required this.children, required this.accent});

  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: parvozGlassFlat(
        radius: 16,
      ).copyWith(border: Border.all(color: accent.withValues(alpha: 0.28))),
      child: Column(children: children),
    );
  }
}

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({required this.limit, required this.meta});

  final AppLimit limit;
  final InstalledAppMeta? meta;

  @override
  Widget build(BuildContext context) {
    final appName = meta?.appName ?? limit.packageName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _Icon(
            packageName: limit.packageName,
            iconBase64: meta?.iconBase64,
            iconUrl: meta?.iconUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.parvozText,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.block, color: AppColors.error, size: 13),
                SizedBox(width: 4),
                Text(
                  'analytics.blockedBadge'.tr(),
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

class _LimitedTile extends StatelessWidget {
  const _LimitedTile({required this.limit, required this.meta});

  final AppLimit limit;
  final InstalledAppMeta? meta;

  @override
  Widget build(BuildContext context) {
    final appName = meta?.appName ?? limit.packageName;
    final minutes = limit.dailyLimitMinutes;
    final hours = minutes ~/ 60;
    final mm = minutes % 60;
    final label = hours == 0
        ? 'analytics.limitPerDayMinutes'.tr(namedArgs: {'minutes': '$minutes'})
        : (mm == 0 ? '$hours soat/kun' : '${hours}s ${mm}m/kun');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _Icon(
            packageName: limit.packageName,
            iconBase64: meta?.iconBase64,
            iconUrl: meta?.iconUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.parvozText,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  AppIcons.scheduleActive,
                  color: AppColors.warning,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.warning,
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

class _Icon extends StatelessWidget {
  const _Icon({required this.packageName, this.iconBase64, this.iconUrl});

  final String packageName;
  final String? iconBase64;
  final String? iconUrl;

  static const double _size = 40;

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
    final initials = packageName
        .split('.')
        .last
        .padRight(2)
        .substring(0, 2)
        .toUpperCase();
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
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.parvozGreen),
      ),
    );
  }
}
