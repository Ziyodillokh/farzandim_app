// Sahifa header'i (Growth uslubi): katta sarlavha + o'ngda kvadrat tugmalar.
// Bosh sahifa: "Asosiy" + chat + bildirishnomalar; Testlar: qidiruv + ♡.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return PageHeader(
      title: 'nav.home'.tr(),
      actions: [
        HeaderIconButton(
          semanticLabel: 'chats.title'.tr(),
          onTap: () => context.push('/chats'),
          child: const HomeSvgIcon(homeChatSvg, size: 20),
        ),
        HeaderIconButton(
          semanticLabel: 'notifications.title'.tr(),
          showDot: unread > 0,
          onTap: () => showNotificationsSheet(context),
          child: const HomeSvgIcon(homeBellSvg, size: 20),
        ),
      ],
    );
  }
}

/// Katta sarlavha + o'ng tomonda 12pt oraliqli tugmalar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.titleSize = 28.5,
  });

  final String title;
  final List<Widget> actions;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeDisplay(titleSize, letterSpacing: -0.2),
          ),
        ),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          actions[i],
        ],
      ],
    );
  }
}

/// Header tugmasi — ko'rinishi 43×38 (maket), bosish maydoni 44×44.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.child,
    required this.semanticLabel,
    required this.onTap,
    this.showDot = false,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 43,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.iconButton,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: child,
                ),
                if (showDot)
                  Positioned(
                    right: 9,
                    top: 6,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: HomeColors.iconButton,
                          width: 1.5,
                        ),
                      ),
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
