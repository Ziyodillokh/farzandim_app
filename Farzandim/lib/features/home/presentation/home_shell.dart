// ─────────────────────────────────────────────────────────────────────
// HomeShell — Parvoz Parents asosiy karkasi: 4 tab
// ─────────────────────────────────────────────────────────────────────
//
// Maktab · Nazorat · Profil. Maktab — farzandsiz ham ishlaydi (maktab kodi
// bilan); Nazorat — farzand telefonidagi Parvoz Growth bilan. Har tab o'z
// navigatsiya holatini saqlaydi (`StatefulShellRoute`). Pastki panel —
// suzuvchi shisha (dashboard dizayni bilan bir xil); Maktab tabida o'qilmagan
// e'lonlar soni. Chatlar va bildirishnomalar — tab emas (kam ishlatiladi):
// Nazorat sarlavhasidagi tugmalar, Maktab sarlavhasidagi qo'ng'iroqcha.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/school/presentation/providers/pending_invite.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Tab tartibi (`StatefulShellRoute` tarmoqlari bilan bir xil).
enum HomeTab { school, control, profile }

/// Pastki panel balandligi + chekka — tab sahifalari pastki bo'shlig'i.
const double kHomeNavReserve = 108;

/// Farzandlardan kelgan, hali o'qilmagan chat xabarlari (hammasi).
final chatUnreadTotalProvider = Provider<int>((ref) {
  var total = 0;
  for (final child in ref.watch(childrenListProvider)) {
    total += ref.watch(unreadChatCountProvider(child.id)).valueOrNull ?? 0;
  }
  return total;
});

/// Maktab tabidagi o'qilmagan e'lonlar (yuklanmagan / xato — 0).
final schoolTabUnreadProvider = Provider.autoDispose<int>(
  (ref) =>
      (ref.watch(schoolUnreadCountProvider).valueOrNull ?? 0) +
      ref.watch(schoolThreadsUnreadProvider),
);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    // Taklif havolasidan kelgan kod (kirishdan oldin ham eslab qolingan) —
    // kirgan ota-onaga ulanish sahifasi bir marta ochiladi.
    ref.listenManual<String?>(
      pendingInviteCodeProvider,
      (_, code) => _openPendingInvite(code),
      fireImmediately: true,
    );
  }

  void _openPendingInvite(String? code) {
    if (code == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(pendingInviteCodeProvider) != code) return;
      ref.read(pendingInviteCodeProvider.notifier).state = null;
      context.push(AppRoutes.schoolLinkPath(code: code));
    });
  }

  void _select(int index) {
    HapticFeedback.selectionClick();
    // Faol tabni qayta bosish — shu tabning boshiga qaytadi.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = {HomeTab.school: ref.watch(schoolTabUnreadProvider)};
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _NavBar(
        current: HomeTab.values[navigationShell.currentIndex],
        badges: badges,
        onSelect: (tab) => _select(tab.index),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.current,
    required this.badges,
    required this.onSelect,
  });

  final HomeTab current;
  final Map<HomeTab, int> badges;
  final ValueChanged<HomeTab> onSelect;

  static const _items = [
    (
      tab: HomeTab.school,
      icon: SolarIconsOutline.squareAcademicCap,
      active: SolarIconsBold.squareAcademicCap,
      label: 'home.tabs.school',
    ),
    (
      tab: HomeTab.control,
      icon: SolarIconsOutline.smartphone,
      active: SolarIconsBold.smartphone,
      label: 'home.tabs.control',
    ),
    (
      tab: HomeTab.profile,
      icon: SolarIconsOutline.userCircle,
      active: SolarIconsBold.userCircle,
      label: 'home.tabs.profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      // Kontent panel ortida yumshoq fonga so'nadi.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0002060D), ParvozColors.bg, ParvozColors.bg],
          stops: [0, 0.5, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 22, 14, bottom > 0 ? bottom : 14),
        child: ParvozGlass(
          height: 70,
          radius: 35,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final item in _items)
                  Expanded(
                    child: _NavItem(
                      icon: current == item.tab ? item.active : item.icon,
                      label: item.label.tr(),
                      selected: current == item.tab,
                      badge: badges[item.tab] ?? 0,
                      onTap: () => onSelect(item.tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: .55);
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge' : label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 52,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: selected ? ParvozColors.blue : Colors.transparent,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: ParvozColors.blue.withValues(alpha: .5),
                                blurRadius: 14,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(icon, size: 21, color: color),
                  ),
                  if (badge > 0)
                    Positioned(right: 2, top: -5, child: _Badge(count: badge)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B5C),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ParvozColors.bg, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
