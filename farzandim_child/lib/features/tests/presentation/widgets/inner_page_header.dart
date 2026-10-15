// Ichki sahifa header'i (Growth uslubi): ← orqaga + sarlavha (+ izoh).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InnerPageHeader extends StatelessWidget {
  const InnerPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.fallbackRoute = '/contests',
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Orqaga qaytib bo'lmasa (deep-link) ochiladigan sahifa.
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HeaderIconButton(
          semanticLabel: 'common.back'.tr(),
          onTap: () =>
              context.canPop() ? context.pop() : context.go(fallbackRoute),
          child: const HomeSvgIcon(homeBackSvg, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeDisplay(21, letterSpacing: -0.3),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(13, color: HomeColors.textDim),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
