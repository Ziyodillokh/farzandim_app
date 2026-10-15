// Profil — bo'limlar menyusi: rangli ikon kvadrat + nom + chevron,
// qatorlar orasida ingichka chiziq.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _pink = Color(0xFFFF5C7A);
const _divider = Color(0x0FFFFFFF);

const _iconBox = 40.0;
const _rowPadding = 14.0;
const _iconGap = 13.0;

class _MenuEntry {
  const _MenuEntry(this.labelKey, this.icon, this.tint, this.path);

  final String labelKey;
  final IconData icon;
  final Color tint;
  final String path;
}

const _entries = <_MenuEntry>[
  _MenuEntry(
    'profile.resultsCalendar',
    SolarIconsBold.calendarMark,
    HomeColors.blue,
    '/learn/calendar',
  ),
  _MenuEntry(
    'donHistory.title',
    SolarIconsBold.walletMoney,
    HomeColors.green,
    '/don-history',
  ),
  _MenuEntry(
    'ranking.title',
    SolarIconsBold.cupStar,
    HomeColors.amber,
    '/ranking',
  ),
  _MenuEntry('tests.favorites', SolarIconsBold.heart, _pink, '/liked-tests'),
  _MenuEntry(
    'profile.savedVideos',
    SolarIconsBold.videoLibrary,
    HomeColors.orange,
    '/liked-videos',
  ),
  _MenuEntry(
    'settings.title',
    SolarIconsBold.settings,
    HomeColors.textDim,
    '/settings',
  ),
];

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: homeCardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < _entries.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(
                    left: _rowPadding + _iconBox + _iconGap,
                  ),
                  color: _divider,
                ),
              _MenuRow(entry: _entries[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(entry.path),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_rowPadding, 9, 10, 9),
          child: Row(
            children: [
              Container(
                width: _iconBox,
                height: _iconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, size: 20, color: entry.tint),
              ),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Text(
                  entry.labelKey.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(15, weight: FontWeight.w600, height: 1.25),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: HomeColors.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
