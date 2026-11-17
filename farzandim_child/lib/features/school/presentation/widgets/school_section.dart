// "Maktabim" bo'laklari: bo'lim kartasi (belgi + sarlavha + mazmun), sanoq
// nishoni, izoh (ko'k fonli) va bo'lim yuklanmagandagi qisqa xato qatori.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bo'limlar orasidagi bo'shliq (har bo'lim o'z ustida — yashirin bo'lim
/// joy egallamaydi).
const kSchoolSectionGap = 12.0;

/// Bo'lim kartasi: rangli belgi, sarlavha, ixtiyoriy o'ng element va mazmun.
class SchoolSectionCard extends StatelessWidget {
  const SchoolSectionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Container(
      decoration: homeCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SchoolIconSquare(icon: icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(18, weight: FontWeight.w800, height: 1.25),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Rangli fonli kvadrat belgi.
class SchoolIconSquare extends StatelessWidget {
  const SchoolIconSquare({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(icon, size: size * 0.53, color: color),
    );
  }
}

/// Sanoq nishoni (masalan, ochiq testlar soni).
class SchoolCountBadge extends StatelessWidget {
  const SchoolCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HomeColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: homeText(13, weight: FontWeight.w800, height: 1.2),
      ),
    );
  }
}

/// Izoh — ko'k (yoki berilgan rangli) fonli, belgili matn.
class SchoolNote extends StatelessWidget {
  const SchoolNote({
    super.key,
    required this.text,
    this.icon = SolarIconsOutline.infoCircle,
    this.color = HomeColors.primary,
    this.iconColor = HomeColors.blue,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: homeText(13, color: HomeColors.textDim, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bo'lim yuklanmadi — qisqa xabar va "Qayta urinish".
class SchoolSectionError extends StatelessWidget {
  const SchoolSectionError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: homeCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          const Icon(
            SolarIconsOutline.dangerCircle,
            size: 18,
            color: HomeColors.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'school.hub.sectionError'.tr(),
              style: homeText(13.5, color: HomeColors.textDim, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'common.retry'.tr(),
              style: homeText(
                13.5,
                weight: FontWeight.w700,
                color: HomeColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sahifa pastidagi asosiy tugma qatori (ingichka chiziq ustida).
class SchoolBottomBar extends StatelessWidget {
  const SchoolBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 14),
      decoration: const BoxDecoration(
        color: HomeColors.bg,
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Kartadagi tugma: asosiy (ko'k) yoki ikkilamchi (plitka rangida).
class SchoolPillButton extends StatelessWidget {
  const SchoolPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = true,
    this.height = 44,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Material(
      color: isPrimary ? HomeColors.primary : HomeColors.tile,
      shape: StadiumBorder(
        side: isPrimary
            ? BorderSide.none
            : const BorderSide(color: HomeColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FitText(
                    label,
                    style: homeText(14, weight: FontWeight.w700, height: 1.2),
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
