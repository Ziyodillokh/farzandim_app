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
    this.contentPadding = const EdgeInsets.fromLTRB(10, 0, 10, 12),
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
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: FitText(
                    title,
                    style: homeText(19, weight: FontWeight.w800, height: 1.25),
                  ),
                ),
                if (onSeeAll != null) _SeeAll(onTap: onSeeAll!),
              ],
            ),
          ),
          // Izoh butun kenglikda — "Barchasini ko'rish" bilan to'qnashmaydi.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: homeText(13, color: HomeColors.textDim, height: 1.3),
            ),
          ),
          const SizedBox(height: 12),
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
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    'progress.seeAll'.tr(),
                    style: homeText(
                      13,
                      weight: FontWeight.w600,
                      color: progressLinkColor,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Padding(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
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
