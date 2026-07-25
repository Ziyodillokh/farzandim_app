// ─────────────────────────────────────────────────────────────────────
// Ko'rishlar tarixi + Yoqtirilgan videolar sahifalari (deyarli bir xil)
// ─────────────────────────────────────────────────────────────────────
//
// Feed header'idagi ⟲ (tarix) va ♡ (yoqtirilgan) tugmalari shu sahifalarga
// olib boradi. Ikkalasi bir xil kun-bo'yicha-guruhlangan ro'yxat (Bugun /
// Kecha / sana) — faqat manba provider va yoqtirilgan-toggle bilan farq qiladi.
//
// Ma'lumot backend'dan (VideoEngagementRepository, offline kesh bilan).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/videos/data/repositories/video_engagement_repository.dart';
import 'package:farzandim_child/features/videos/presentation/providers/video_engagement_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Ko'rishlar tarixi — feed header ⟲.
class WatchHistoryScreen extends ConsumerWidget {
  /// `WatchHistoryScreen` konstruktor.
  const WatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EngagementListView(
      title: 'videos.history.title'.tr(),
      value: ref.watch(watchHistoryPageProvider),
      onRefresh: () => ref.read(watchHistoryPageProvider.notifier).refresh(),
      emptyIcon: Icons.history_rounded,
      emptyText: 'videos.history.emptyTitle'.tr(),
      emptySubtext: 'videos.history.emptySubtitle'.tr(),
    );
  }
}

/// "Yoqtirilgan videolar" — feed header ♡.
class LikedVideosScreen extends ConsumerWidget {
  /// `LikedVideosScreen` konstruktor.
  const LikedVideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EngagementListView(
      title: 'videos.liked.title'.tr(),
      value: ref.watch(likedVideosPageProvider),
      onRefresh: () => ref.read(likedVideosPageProvider.notifier).refresh(),
      onUnfavorite: (id) =>
          ref.read(likedVideosPageProvider.notifier).unfavorite(id),
      emptyIcon: Icons.favorite_border_rounded,
      emptyText: 'videos.liked.emptyTitle'.tr(),
      emptySubtext: 'videos.liked.emptySubtitle'.tr(),
    );
  }
}

// ════════════ Umumiy ro'yxat ko'rinishi ════════════

class _EngagementListView extends StatelessWidget {
  const _EngagementListView({
    required this.title,
    required this.value,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyText,
    required this.emptySubtext,
    this.onUnfavorite,
  });

  final String title;
  final AsyncValue<List<VideoEngagementEntry>> value;
  final Future<void> Function() onRefresh;
  final void Function(String id)? onUnfavorite;
  final IconData emptyIcon;
  final String emptyText;
  final String emptySubtext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _TopBar(title: title),
            ),
            Expanded(
              child: RefreshIndicator(
                color: vBlue,
                backgroundColor: vVideoBg,
                onRefresh: onRefresh,
                child: value.when(
                  data: (entries) => entries.isEmpty
                      ? _ScrollCenter(
                          child: _Empty(
                            icon: emptyIcon,
                            text: emptyText,
                            subtext: emptySubtext,
                          ),
                        )
                      : _GroupedList(
                          entries: entries,
                          onUnfavorite: onUnfavorite,
                        ),
                  loading: () => const _ScrollCenter(
                    child: CircularProgressIndicator(color: vBlue),
                  ),
                  error: (_, __) => _ScrollCenter(
                    child: _Empty(
                      icon: Icons.wifi_off_rounded,
                      text: 'videos.engagement.loadFailed'.tr(),
                      subtext: 'videos.engagement.loadFailedSubtitle'.tr(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: vGlass,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: vUnb(20, w: FontWeight.w600, ls: -0.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.entries, this.onUnfavorite});

  final List<VideoEngagementEntry> entries;
  final void Function(String id)? onUnfavorite;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final children = <Widget>[];
    String? lastLabel;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final label = _dayLabel(e.at, now);
      if (label != lastLabel) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 20, bottom: 12),
            child: _DayHeader(label: label),
          ),
        );
        lastLabel = label;
      }
      children
        ..add(
          VideoFeedCard(
            video: e.video,
            onTap: () => context.push('/video-player', extra: e.video),
            trailing: onUnfavorite != null
                ? _HeartToggle(onTap: () => onUnfavorite!(e.video.id))
                : null,
          ),
        )
        ..add(const SizedBox(height: 20));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
      children: children,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: vPop(13, w: FontWeight.w500, c: vMuted),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: vGlassBorder)),
      ],
    );
  }
}

class _HeartToggle extends StatelessWidget {
  const _HeartToggle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.favorite, size: 26, color: vFav),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, required this.subtext});

  final IconData icon;
  final String text;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ilova uslubiga mos dumaloq ikon-badge (mascot o'rniga).
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  vBlue.withValues(alpha: 0.22),
                  vBlue.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: vBlue.withValues(alpha: 0.30)),
            ),
            child: Icon(icon, size: 40, color: vBlue),
          ),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: vUnb(18, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 8),
          Text(
            subtext,
            textAlign: TextAlign.center,
            style: vPop(14, c: vDim),
          ),
        ],
      ),
    );
  }
}

/// Bo'sh/loading/xatoni RefreshIndicator ichida markazda + scroll qilinadigan.
class _ScrollCenter extends StatelessWidget {
  const _ScrollCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

const List<String> _months = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];

/// Kun yorlig'i — Bugun / Kecha / "N kun oldin" / "12-iyul".
String _dayLabel(DateTime at, DateTime now) {
  final d = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff <= 0) return 'common.today'.tr();
  if (diff == 1) return 'common.yesterday'.tr();
  if (diff < 7) return 'common.daysAgo'.tr(namedArgs: {'days': '$diff'});
  return '${at.day}-${_months[at.month - 1]}';
}
