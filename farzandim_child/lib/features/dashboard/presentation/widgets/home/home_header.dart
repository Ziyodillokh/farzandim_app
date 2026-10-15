// Bosh sahifa header'i: "Asosiy" + chat + bildirishnomalar.

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
    return Row(
      children: [
        Expanded(
          child: Text(
            'nav.home'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: homeDisplay(28.5, letterSpacing: -0.2),
          ),
        ),
        _HeaderButton(
          svg: homeChatSvg,
          iconSize: 20,
          semanticLabel: 'chats.title'.tr(),
          onTap: () => context.push('/chats'),
        ),
        const SizedBox(width: 12),
        _HeaderButton(
          svg: homeBellSvg,
          iconSize: 20,
          semanticLabel: 'notifications.title'.tr(),
          showDot: unread > 0,
          onTap: () => showNotificationsSheet(context),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.svg,
    required this.iconSize,
    required this.semanticLabel,
    required this.onTap,
    this.showDot = false,
  });

  final String svg;
  final double iconSize;
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
        // Ko'rinishi 43×38 (maket), bosish maydoni 44×44 (HIG minimum).
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
                  child: HomeSvgIcon(svg, size: iconSize),
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
