// ─────────────────────────────────────────────────────────────────────
// LibraryScreen — "Kutubxona" (pastki nav tabi)
// ─────────────────────────────────────────────────────────────────────
//
// Tepada Growth uslubidagi 2 qismli tanlagich: Videolar | Audiokitoblar.
// Ostida esa mavjud Videolar va Audiokitoblar sahifalarining tarkibi
// O'ZGARISHSIZ (`VideosFeedView`, `AudiobooksFeedView`) — ular alohida
// sahifada qanday bo'lsa, bu yerda ham aynan shunday.
//
// Tanlangan bo'lim eslab qolinadi (`libraryTabProvider`); ikkala bo'lim
// ham holatini (aylantirish, qidiruv, filtr) saqlaydi — IndexedStack.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/audiobooks/presentation/screens/audiobooks_feed_screen.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/videos/presentation/screens/videos_feed_screen.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Kutubxona bo'limlari.
enum LibraryTab { videos, audiobooks }

/// Tanlangan bo'lim (sahifadan chiqib qaytganda ham saqlanadi).
final libraryTabProvider = StateProvider<LibraryTab>(
  (ref) => LibraryTab.videos,
);

const _segmentBg = Color(0xFF0C1116);
const _segmentBorder = Color(0x1FFFFFFF);
const _segmentActive = Color(0xFF1B6FDD);
const _segmentHeight = 46.0;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialTab});

  /// Berilsa — shu bo'lim ochiladi (masalan `/videos`, `/audiobooks`).
  final LibraryTab? initialTab;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late LibraryTab _tab = widget.initialTab ?? ref.read(libraryTabProvider);

  void _select(LibraryTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
    ref.read(libraryTabProvider.notifier).state = tab;
  }

  @override
  Widget build(BuildContext context) {
    // Har bo'lim o'z fonida (eski sahifalardagidek); tanlagich ham shu fonda.
    final bg = _tab == LibraryTab.videos ? vBg : audiobooksPageBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const ChildBottomNavigation(),
        body: Column(
          children: [
            SizedBox(height: growthTopInset(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LibrarySegment(selected: _tab, onChanged: _select),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: IndexedStack(
                  index: _tab.index,
                  children: const [
                    VideosFeedView(headerTop: 14),
                    AudiobooksFeedView(titleTop: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Videolar | Audiokitoblar — Growth uslubidagi 2 qismli tanlagich.
class LibrarySegment extends StatelessWidget {
  const LibrarySegment({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final LibraryTab selected;
  final ValueChanged<LibraryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _segmentHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _segmentBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _segmentBorder),
      ),
      child: Row(
        // Faol fon tugmaning butun balandligini egallasin.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SegmentButton(
              icon: SolarIconsBold.play,
              label: 'nav.videos'.tr(),
              active: selected == LibraryTab.videos,
              onTap: () => onChanged(LibraryTab.videos),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentButton(
              icon: SolarIconsBold.headphonesRound,
              label: 'nav.audiobooks'.tr(),
              active: selected == LibraryTab.audiobooks,
              onTap: () => onChanged(LibraryTab.audiobooks),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : HomeColors.textDim;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active ? _segmentActive : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _segmentActive.withValues(alpha: 0.4),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: FitText(
                  label,
                  style: homeText(
                    13.5,
                    weight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
