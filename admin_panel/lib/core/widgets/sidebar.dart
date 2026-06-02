import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../layout/sidebar_cubit.dart';
import '../layout/sidebar_rail_cubit.dart';
import '../network/admin_api.dart';
import '../network/admin_session.dart' show AdminSession, SessionClearCause;
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class _Leaf {
  final String title;
  final IconData icon;
  final String route;
  const _Leaf(this.title, this.icon, this.route);
}

class _Group {
  final String title;
  final IconData icon;
  final List<_Leaf> children;
  const _Group(this.title, this.icon, this.children);
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key, this.iconsOnly = false});

  /// Tor sidebar: faqat ikonlar + `PopupMenu` guruhlar uchun.
  final bool iconsOnly;

  static const _top = <_Leaf>[
    _Leaf('Dashboard', Icons.bar_chart_rounded, '/dashboard'),
    _Leaf('Foydalanuvchilar', Icons.people_outline_rounded, '/users'),
  ];

  static const _kontent = _Group(
    'Kontentlar',
    Icons.play_circle_outline_rounded,
    [
      _Leaf('Videolar', Icons.movie_outlined, '/content/videos'),
      _Leaf('Audiokitoblar', Icons.headphones_outlined, '/content/audiobooks'),
      _Leaf('Kitoblar / PDF', Icons.menu_book_outlined, '/content/books'),
    ],
  );

  static const _middle = <Object>[
    _Leaf('Konkurslar', Icons.checklist_rtl_rounded, '/contests'),
    _Leaf('Moderatorlar', Icons.star_outline_rounded, '/moderators'),
    _Group(
      'Monetizatsiya',
      Icons.show_chart_rounded,
      [
        _Leaf('Tariflar', Icons.layers_outlined, '/monetization/plans'),
        _Leaf('Promokodlar', Icons.local_offer_outlined, '/monetization/promocodes'),
        _Leaf('Payment tarixi', Icons.receipt_long_outlined, '/monetization/payments'),
      ],
    ),
  ];

  static const _bottom = <_Leaf>[
    _Leaf('Analitika', Icons.area_chart_outlined, '/analytics'),
    _Leaf('Bildirishnoma', Icons.notifications_outlined, '/notifications'),
    _Leaf('Audit log', Icons.history_rounded, '/settings/audit-log'),
    _Leaf('Sozlamalar', Icons.settings_outlined, '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Container(
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
            child: _Header(iconsOnly: iconsOnly),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
              children: [
                ..._top.map((e) => _SidebarLeaf(item: e, location: location, iconsOnly: iconsOnly)),
                const _SectionDivider(),
                if (iconsOnly) ...[
                  _GroupIconOnly(group: _kontent, location: location),
                ] else ...[
                  _SidebarGroup(group: _kontent, location: location),
                ],
                const _SectionDivider(),
                ..._middle.map((e) {
                  if (e is _Group) {
                    return iconsOnly
                        ? _GroupIconOnly(group: e, location: location)
                        : _SidebarGroup(group: e, location: location);
                  }
                  if (e is _Leaf) {
                    return _SidebarLeaf(item: e, location: location, iconsOnly: iconsOnly);
                  }
                  return const SizedBox.shrink();
                }),
                const _SectionDivider(),
                ..._bottom.map(
                  (e) => _SidebarLeaf(item: e, location: location, iconsOnly: iconsOnly),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            child: iconsOnly
                ? Tooltip(
                    message: 'Chiqish',
                    child: IconButton(
                      onPressed: () async {
                        await AdminApi().logout(); // H7 — serverda sessiyani tugatish
                        await AdminSession.clear(cause: SessionClearCause.userLogout);
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
                    ),
                  )
                : TextButton.icon(
                    onPressed: () async {
                      await AdminApi().logout(); // H7 — serverda sessiyani tugatish
                      await AdminSession.clear(cause: SessionClearCause.userLogout);
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 18),
                    label: const Text(
                      'Chiqish',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.iconsOnly});

  final bool iconsOnly;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: iconsOnly ? 32 : 36,
      height: iconsOnly ? 32 : 36,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
    );

    if (iconsOnly) {
      return Center(child: logo);
    }

    return Row(
      children: [
        logo,
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Text(
            'Farzandim',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: iconsOnly ? 'Kengaytirish' : 'Tor rejim',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () {
            context.read<SidebarRailCubit>().toggle();
            if (MediaQuery.sizeOf(context).width < 900) {
              context.read<SidebarCubit>().collapse();
            }
          },
          icon: const Icon(Icons.menu_rounded, color: Colors.white70, size: 22),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Divider(height: 1, thickness: 1, color: Colors.white10),
    );
  }
}

class _SidebarGroup extends StatelessWidget {
  const _SidebarGroup({required this.group, required this.location});

  final _Group group;
  final String location;

  bool get _open {
    for (final c in group.children) {
      if (location == c.route || location.startsWith('${c.route}/')) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.white10,
          splashColor: Colors.white10,
          hoverColor: Colors.white10,
          listTileTheme: const ListTileThemeData(
            iconColor: Colors.white70,
            textColor: Colors.white70,
          ),
        ),
        child: ExpansionTile(
          key: ValueKey('${group.title}_$_open'),
          initiallyExpanded: _open,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          childrenPadding: const EdgeInsets.only(left: AppSpacing.sm),
          backgroundColor: AppColors.sidebarElevated.withValues(alpha: 0.35),
          collapsedBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          title: Row(
            children: [
              Icon(group.icon, size: 20, color: Colors.white70),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          children: group.children
              .map((c) => _SidebarLeaf(item: c, location: location, nested: true, iconsOnly: false))
              .toList(),
        ),
      ),
    );
  }
}

/// Tor rejimda guruh — bosilganda pastki yo‘nalishlar menyusi.
class _GroupIconOnly extends StatelessWidget {
  const _GroupIconOnly({required this.group, required this.location});

  final _Group group;
  final String location;

  bool _groupActive() {
    for (final c in group.children) {
      if (location == c.route || location.startsWith('${c.route}/')) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final active = _groupActive();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: PopupMenuButton<String>(
        tooltip: group.title,
        offset: const Offset(56, 0),
        color: AppColors.sidebarElevated,
        onSelected: (route) => context.go(route),
        itemBuilder: (ctx) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              group.title,
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          ...group.children.map(
            (e) => PopupMenuItem<String>(
              value: e.route,
              child: Row(
                children: [
                  Icon(e.icon, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(e.title, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
        child: Container(
          width: 48,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.sidebarLime : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(
            group.icon,
            color: active ? const Color(0xFF111827) : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SidebarLeaf extends StatefulWidget {
  const _SidebarLeaf({
    required this.item,
    required this.location,
    this.nested = false,
    this.iconsOnly = false,
  });

  final _Leaf item;
  final String location;
  final bool nested;
  final bool iconsOnly;

  @override
  State<_SidebarLeaf> createState() => _SidebarLeafState();
}

class _SidebarLeafState extends State<_SidebarLeaf> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final active = widget.location == item.route;
    final hovered = _hovered && !active;

    if (widget.iconsOnly) {
      return Tooltip(
        message: item.title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: active
                ? AppColors.sidebarLime
                : (hovered ? AppColors.sidebarElevated.withValues(alpha: 0.6) : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.control),
              onTap: () => context.go(item.route),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Icon(
                    item.icon,
                    size: 22,
                    color: active ? const Color(0xFF111827) : Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        hoverColor: Colors.transparent,
        onTap: () => context.go(item.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            left: widget.nested ? AppSpacing.md : AppSpacing.xs,
            right: AppSpacing.xs,
            bottom: AppSpacing.xxs,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.sidebarLime
                : (hovered ? AppColors.sidebarElevated.withValues(alpha: 0.55) : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: active ? const Color(0xFF111827) : Colors.white70,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: active ? const Color(0xFF111827) : Colors.white70,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
