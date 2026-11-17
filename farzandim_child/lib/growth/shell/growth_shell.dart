// Growth v5 karkasi: to'rt tab (Bugun · O'qish · Maktab · Men) va suzuvchi menyu.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class GrowthShell extends StatelessWidget {
  const GrowthShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final _tabs = [
    (key: 'g5.tab.today', icon: GIcons.house),
    (key: 'g5.tab.learn', icon: GIcons.bookOpen),
    (key: 'g5.tab.school', icon: GIcons.backpack),
    (key: 'g5.tab.me', icon: GIcons.user),
  ];

  void _select(int index) {
    // Faol tab qayta bosilsa — shu tabning ildiz ekraniga qaytadi.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Klaviatura ochiq bo'lsa menyu yashiriladi (u klaviatura ustiga chiqmasin).
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: GColors.bg,
      ),
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: GTabInset(
                height: keyboardOpen ? 0 : kGTabBarHeight,
                child: navigationShell,
              ),
            ),
            if (!keyboardOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GTabBar(
                  items: [
                    for (final tab in _tabs)
                      GTabItem(label: tab.key.tr(), icon: tab.icon),
                  ],
                  currentIndex: navigationShell.currentIndex,
                  onSelect: _select,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
