// ─────────────────────────────────────────────────────────────────────
// SchoolAnnouncementsScreen — maktab e'lonlari
// ─────────────────────────────────────────────────────────────────────
//
// Yangisi oldin, 20 tadan sahifa (oxiriga yaqinlashganda keyingisi
// yuklanadi). E'lon bosilsa ochiladi va "o'qildi" deb belgilanadi
// (optimistik — server rad etsa qaytariladi). Pull-to-refresh.
//
// Push'dan (`SCHOOL_ANNOUNCEMENT`): `?focus=<id>` — e'lon ochiladi,
// belgilanadi va unga aylantiriladi. Yuklangan sahifalarda topilmasa —
// push matni (`title`, `body`) alohida kartada ko'rsatiladi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/announcement_tile.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

/// Ro'yxat oxiriga shuncha piksel qolganda keyingi sahifa so'raladi.
const double _loadMoreExtent = 480;

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

TextStyle _pop(double size, {Color c = Colors.white}) =>
    GoogleFonts.poppins(fontSize: size, color: c, height: 1.5);

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
  final _focusKey = GlobalKey();
  Set<String> _expanded = const {};
  bool _focusHandled = false;

  String? get _focus {
    final focus = widget.focusId?.trim();
    return focus == null || focus.isEmpty ? null : focus;
  }

  @override
  void initState() {
    super.initState();
    final focus = _focus;
    if (focus == null) return;
    _expanded = {focus};
    ref.listenManual<SchoolAnnouncementsState>(
      schoolAnnouncementsProvider,
      (_, next) => _handleFocus(next),
      fireImmediately: true,
    );
  }

  /// Birinchi sahifa kelgach bir marta: e'lon "o'qildi" (ro'yxatda
  /// bo'lmasa ham — server idempotent) va unga aylantirish.
  void _handleFocus(SchoolAnnouncementsState state) {
    final focus = _focus;
    if (_focusHandled || focus == null || state.loading || state.page == 0) {
      return;
    }
    _focusHandled = true;
    unawaited(ref.read(schoolAnnouncementsProvider.notifier).markRead(focus));
    if (!state.items.any((item) => item.id == focus)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusKey.currentContext;
      if (target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  void _toggle(SchoolAnnouncement announcement) {
    final id = announcement.id;
    final opening = !_expanded.contains(id);
    setState(() {
      _expanded = opening
          ? {..._expanded, id}
          : _expanded.where((e) => e != id).toSet();
    });
    if (opening && !announcement.isRead) {
      unawaited(ref.read(schoolAnnouncementsProvider.notifier).markRead(id));
    }
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
        color: _blue,
        backgroundColor: _card,
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

  Widget _list(
    SchoolAnnouncementsState state,
    SchoolAnnouncementsNotifier n,
    SchoolAnnouncement? fallback,
  ) {
    final focus = _focus;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < _loadMoreExtent) {
          unawaited(n.loadMore());
        }
        return false;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          if (state.unread > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'school.announcements.unreadCount'.tr(
                  namedArgs: {'count': '${state.unread}'},
                ),
                style: _pop(13, c: _dim),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (fallback != null) ...[
            AnnouncementTile(
              announcement: fallback,
              expanded: true,
              caption: 'school.announcements.fromPush'.tr(),
            ),
            const SizedBox(height: 8),
          ],
          for (final item in state.items) ...[
            AnnouncementTile(
              key: item.id == focus ? _focusKey : ValueKey(item.id),
              announcement: item,
              expanded: _expanded.contains(item.id),
              onTap: () => _toggle(item),
            ),
            const SizedBox(height: 8),
          ],
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
            child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
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
