// Kutubxona kartasi — to'liq rasm, tur belgisi, saqlash, sarlavha, mukofot.

import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_stat_cards.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

enum LibraryKind { video, audiobook }

/// Kutubxona lentasi elementi (video yoki audiokitob).
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackColor,
    required this.reward,
    required this.saved,
    required this.onTap,
    required this.onToggleSave,
  });

  final String id;
  final LibraryKind kind;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Color fallbackColor;

  /// Tugatganda beriladigan DON (0 — ko'rsatilmaydi).
  final int reward;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;
}

class LibraryCard extends StatelessWidget {
  const LibraryCard({super.key, required this.item});

  static const width = 115.0;
  static const height = 145.0;

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0x2E7FA8D8)),
        ),
        decoration: BoxDecoration(
          color: item.fallbackColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl.isNotEmpty)
              Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Pastdan qoraytirish — matn o'qilishi uchun.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.25, 0.55, 1],
                  colors: [
                    Color(0x00060B12),
                    Color(0xB3060B12),
                    Color(0xF2060B12),
                  ],
                ),
              ),
            ),
            Positioned(left: 4, top: 4, child: _KindBadge(kind: item.kind)),
            Positioned(
              right: 0,
              top: 0,
              child: _SaveButton(saved: item.saved, onTap: item.onToggleSave),
            ),
            Positioned(
              left: 10,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: homeText(11.4, weight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: homeText(
                      9.8,
                      color: HomeColors.textDim,
                      height: 1.25,
                    ),
                  ),
                  if (item.reward > 0) ...[
                    const SizedBox(height: 5),
                    _RewardRow(reward: item.reward),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shishali kichik plashka (tur belgisi / saqlash tugmasi foni).
class _Frosted extends StatelessWidget {
  const _Frosted({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x66141A22),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final LibraryKind kind;

  @override
  Widget build(BuildContext context) {
    final isVideo = kind == LibraryKind.video;
    return _Frosted(
      padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isVideo
                  ? const Color(0xFF2F6BD0)
                  : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isVideo ? SolarIconsBold.play : SolarIconsBold.headphonesRound,
              size: isVideo ? 10 : 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            (isVideo ? 'home.video' : 'home.audiobook').tr(),
            style: homeText(9.5, weight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: saved,
      label: 'home.save'.tr(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Ko'rinishi kichik (maket), bosish maydoni 44×44 — karta o'zi
        // ham bosiladi, yonidan tegib ketish kontentni ochib yubormasin.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: _Frosted(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Icon(
                  saved ? SolarIconsBold.bookmark : SolarIconsOutline.bookmark,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.reward});

  final int reward;

  @override
  Widget build(BuildContext context) {
    // Katta shrift masshtabida ham kesilmasin — tor joyda kichrayadi.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SolarIconsBold.starCircle,
            size: 17,
            color: HomeColors.green,
          ),
          const SizedBox(width: 4),
          Text(
            '+$reward',
            style: homeText(
              13.5,
              weight: FontWeight.w600,
              color: HomeColors.green,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 5),
          const DonBadge(fontSize: 8.6),
        ],
      ),
    );
  }
}
