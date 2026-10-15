// Rivojlanish bo'lim kartasi: sarlavha + izoh + "Barchasini ko‘rish >".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';

const _sectionBg = Color(0xFF09131E);
const _sectionBorder = Color(0xFF121D2A);
const progressLinkColor = Color(0xFF4A94FF);

class ProgressSection extends StatelessWidget {
  const ProgressSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onSeeAll,
    this.contentPadding = const EdgeInsets.fromLTRB(8.5, 0, 7.5, 9.6),
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onSeeAll;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _sectionBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _sectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13.5, 8.5, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          16.3,
                          weight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(10.9, color: HomeColors.textDim),
                      ),
                    ],
                  ),
                ),
                if (onSeeAll != null) _SeeAll(onTap: onSeeAll!),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Padding(padding: contentPadding, child: child),
        ],
      ),
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          // Sarlavha bloki balandligida (≈37pt) — maket oraliqlari buzilmasin.
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'progress.seeAll'.tr(),
                    style: homeText(
                      9.9,
                      weight: FontWeight.w500,
                      color: progressLinkColor,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: progressLinkColor,
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
