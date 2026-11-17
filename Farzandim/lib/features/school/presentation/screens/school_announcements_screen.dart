// ─────────────────────────────────────────────────────────────────────
// SchoolAnnouncementsScreen — maktab e'lonlari
// ─────────────────────────────────────────────────────────────────────
//
// Yangisi oldin, 20 tadan sahifa (oxiriga yaqinlashganda keyingisi
// yuklanadi). Filtrlar: barchasi / o'qilmagan / muhim; kun bo'yicha
// guruhlar (bugun, kecha, shu hafta, oldinroq). E'lon bosilsa batafsil
// sahifasi ochiladi va "o'qildi" deb belgilanadi. "Hammasini o'qildi" —
// yuklangan o'qilmaganlar. Pull-to-refresh.
//
// Push'dan (`SCHOOL_ANNOUNCEMENT`): `?focus=<id>` — birinchi sahifa
// kelgach e'lon batafsil ochiladi. Yuklangan sahifalarda topilmasa —
// push matni (`title`, `body`) alohida kartada ko'rsatiladi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/announcement_card.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ro'yxat oxiriga shuncha piksel qolganda keyingi sahifa so'raladi.
const double _loadMoreExtent = 480;

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

enum AnnouncementFilter { all, unread, important }

enum _Bucket { today, yesterday, week, earlier }

/// Kun guruhi ([now] — testlar uchun).
_Bucket _bucketOf(DateTime? at, DateTime now) {
  if (at == null) return _Bucket.earlier;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return _Bucket.today;
  if (diff == 1) return _Bucket.yesterday;
  if (diff < 7) return _Bucket.week;
  return _Bucket.earlier;
}

class SchoolAnnouncementsScreen extends ConsumerStatefulWidget {
  const SchoolAnnouncementsScreen({
    this.focusId,
    this.focusTitle,
    this.focusBody,
    super.key,
  });

  /// Push'dagi e'lon id'si (`?focus=`).
  final String? focusId;

  /// Push sarlavhasi va matni — e'lon ro'yxatda topilmasa ko'rsatiladi.
  final String? focusTitle;
  final String? focusBody;

  @override
  ConsumerState<SchoolAnnouncementsScreen> createState() =>
      _SchoolAnnouncementsScreenState();
}

class _SchoolAnnouncementsScreenState
    extends ConsumerState<SchoolAnnouncementsScreen> {
  AnnouncementFilter _filter = AnnouncementFilter.all;
  bool _focusHandled = false;

  String? get _focus {
    final focus = widget.focusId?.trim();
    return focus == null || focus.isEmpty ? null : focus;
  }

  @override
  void initState() {
    super.initState();
    if (_focus == null) return;
    ref.listenManual<SchoolAnnouncementsState>(
      schoolAnnouncementsProvider,
      (_, next) => _handleFocus(next),
      fireImmediately: true,
    );
  }

  /// Birinchi sahifa kelgach bir marta: e'lon "o'qildi" (ro'yxatda
  /// bo'lmasa ham — server idempotent) va (topilsa) batafsil ochiladi.
  void _handleFocus(SchoolAnnouncementsState state) {
    final focus = _focus;
    if (_focusHandled || focus == null || state.loading || state.page == 0) {
      return;
    }
    _focusHandled = true;
    unawaited(ref.read(schoolAnnouncementsProvider.notifier).markRead(focus));
    final item = state.items.where((i) => i.id == focus).firstOrNull;
    if (item == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(item);
    });
  }

  void _open(SchoolAnnouncement announcement) {
    if (!announcement.isRead) {
      unawaited(
        ref
            .read(schoolAnnouncementsProvider.notifier)
            .markRead(announcement.id),
      );
    }
    unawaited(
      context.push(
        AppRoutes.schoolAnnouncementPath(announcement.id),
        extra: announcement,
      ),
    );
  }

  Future<void> _markAll(List<SchoolAnnouncement> items) async {
    final notifier = ref.read(schoolAnnouncementsProvider.notifier);
    await Future.wait([
      for (final item in items.where((i) => !i.isRead))
        notifier.markRead(item.id),
    ]);
    ref.invalidate(schoolUnreadCountProvider);
  }

  Future<void> _refresh() async {
    final notifier = ref.read(schoolAnnouncementsProvider.notifier);
    // Dashboard va maktab sahifasidagi belgi ham yangilansin.
    ref.invalidate(schoolUnreadCountProvider);
    try {
      await notifier.refresh().timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ro'yxat o'zi yangilanadi.
      return;
    }
    if (!mounted) return;
    final state = ref.read(schoolAnnouncementsProvider);
    final failure = state.failure;
    // Ro'yxat bo'sh bo'lsa xato ekranning o'zida ko'rinadi.
    if (failure != null && state.items.isNotEmpty) {
      AppToast.error(context, failure.messageKey.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schoolAnnouncementsProvider);
    final notifier = ref.read(schoolAnnouncementsProvider.notifier);
    final failure = state.failure;

    final fallback = _fallbackFor(state);

    final Widget body;
    if (state.items.isEmpty && state.loading) {
      body = const SchoolLoadingView();
    } else if (state.items.isEmpty && failure != null) {
      body = SchoolErrorView(
        error: failure,
        onRetry: () => unawaited(notifier.refresh()),
      );
    } else {
      body = RefreshIndicator(
        color: SK.blue,
        backgroundColor: SK.card,
        onRefresh: _refresh,
        child: state.items.isEmpty && fallback == null
            ? SchoolMessageView(
                icon: SolarIconsBold.letterUnread,
                title: 'school.announcements.emptyTitle'.tr(),
                message: 'school.announcements.emptyBody'.tr(),
              )
            : _list(state, notifier, fallback),
      );
    }
    return SchoolScaffold(title: 'school.announcements.title'.tr(), body: body);
  }

  /// Push matni kartasi — e'lon yuklangan sahifalarda yo'q bo'lsa.
  SchoolAnnouncement? _fallbackFor(SchoolAnnouncementsState state) {
    final focus = _focus;
    final title = widget.focusTitle?.trim() ?? '';
    final body = widget.focusBody?.trim() ?? '';
    if (focus == null || (title.isEmpty && body.isEmpty)) return null;
    if (state.page == 0 || state.items.any((item) => item.id == focus)) {
      return null;
    }
    return SchoolAnnouncement(
      id: focus,
      schoolId: '',
      schoolName: '',
      title: title,
      body: body,
      priority: AnnouncementPriority.normal,
      readAt: DateTime.now(),
    );
  }

  bool _matches(SchoolAnnouncement a) => switch (_filter) {
    AnnouncementFilter.all => true,
    AnnouncementFilter.unread => !a.isRead,
    AnnouncementFilter.important => a.isImportant,
  };

  Widget _list(
    SchoolAnnouncementsState state,
    SchoolAnnouncementsNotifier n,
    SchoolAnnouncement? fallback,
  ) {
    final now = DateTime.now();
    final visible = state.items.where(_matches).toList(growable: false);
    final importantCount = state.items.where((a) => a.isImportant).length;
    final rows = <Widget>[];
    _Bucket? bucket;
    for (final item in visible) {
      final b = _bucketOf(item.sentAt, now);
      if (b != bucket) {
        rows.add(SkSectionLabel('school.announcements.group.${b.name}'.tr()));
        bucket = b;
      }
      rows
        ..add(
          AnnouncementCard(
            key: ValueKey(item.id),
            announcement: item,
            onTap: () => _open(item),
          ),
        )
        ..add(const SizedBox(height: 10));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < _loadMoreExtent) {
          unawaited(n.loadMore());
        }
        return false;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SkChip(
                  label: 'school.announcements.filter.all'.tr(),
                  selected: _filter == AnnouncementFilter.all,
                  onTap: () => setState(() => _filter = AnnouncementFilter.all),
                ),
                const SizedBox(width: 8),
                SkChip(
                  label: 'school.announcements.filter.unread'.tr(),
                  count: state.unread,
                  selected: _filter == AnnouncementFilter.unread,
                  onTap: () =>
                      setState(() => _filter = AnnouncementFilter.unread),
                ),
                const SizedBox(width: 8),
                SkChip(
                  label: 'school.announcements.filter.important'.tr(),
                  count: importantCount,
                  selected: _filter == AnnouncementFilter.important,
                  onTap: () =>
                      setState(() => _filter = AnnouncementFilter.important),
                ),
              ],
            ),
          ),
          if (state.unread > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'school.announcements.unreadCount'.tr(
                      namedArgs: {'count': '${state.unread}'},
                    ),
                    style: skText(13, c: SK.dim),
                  ),
                ),
                SchoolTextButton(
                  label: 'school.announcements.markAll'.tr(),
                  onTap: () => unawaited(_markAll(state.items)),
                ),
              ],
            ),
          ],
          if (fallback != null) ...[
            const SizedBox(height: 10),
            AnnouncementCard(
              announcement: fallback,
              caption: 'school.announcements.fromPush'.tr(),
              onTap: () => unawaited(
                context.push(
                  AppRoutes.schoolAnnouncementPath(fallback.id),
                  extra: fallback,
                ),
              ),
            ),
          ],
          if (visible.isEmpty && fallback == null) ...[
            const SizedBox(height: 40),
            Center(
              child: Text(
                'school.announcements.emptyFilter'.tr(),
                style: skText(14, c: SK.dim),
              ),
            ),
          ],
          ...rows,
          _Footer(state: state, onRetry: n.retryMore, onMore: n.loadMore),
        ],
      ),
    );
  }
}

/// Ro'yxat oxiri: yuklanmoqda / sahifa xatosi / "Yana yuklash".
class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.onRetry,
    required this.onMore,
  });

  final SchoolAnnouncementsState state;
  final Future<void> Function() onRetry;
  final Future<void> Function() onMore;

  @override
  Widget build(BuildContext context) {
    final moreFailure = state.moreFailure;
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: SK.blue),
          ),
        ),
      );
    }
    if (moreFailure != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchoolInlineError(message: moreFailure.messageKey.tr()),
            const SizedBox(height: 10),
            ParvozSecondaryButton(
              label: 'common.retry'.tr(),
              onPressed: () => unawaited(onRetry()),
            ),
          ],
        ),
      );
    }
    if (!state.hasMore) return const SizedBox.shrink();
    return ParvozSecondaryButton(
      label: 'school.announcements.loadMore'.tr(),
      onPressed: () => unawaited(onMore()),
    );
  }
}
