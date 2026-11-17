// B02 · Bildirishnomalar: «Bugun» va «Avvalroq», turlari plita rangi bilan
// ajratiladi, o'qilmaganlarida nuqta va «Yangi» yozuvi (faqat rang emas).
// Havolasi bor xabar o'sha ekranni ochadi, yo'q bo'lsa — to'liq matn varaqda.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Shu ekranda o'qilgan deb belgilanganlar (keyingi yuklashgacha).
  final _readNow = <String>{};

  bool _isUnread(AppNotification n) => !n.isRead && !_readNow.contains(n.id);

  Future<void> _open(AppNotification n) async {
    if (_isUnread(n)) {
      setState(() => _readNow.add(n.id));
      ref.read(backendNotificationRepositoryProvider).markAsRead(n.id);
    }
    final route = n.relatedRoute?.trim();
    if (route != null && route.isNotEmpty && route != '/') {
      context.push(route);
      return;
    }
    await showGSheet<void>(context, builder: (_) => _Detail(notification: n));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final items = async.valueOrNull ?? const <AppNotification>[];
    final now = ref.watch(learningClockProvider)();
    final unread = items.where(_isUnread).length;
    final today = [
      for (final n in items)
        if (_sameDay(n.createdAt, now)) n,
    ];
    final earlier = [
      for (final n in items)
        if (!_sameDay(n.createdAt, now)) n,
    ];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.notifications.title'.tr(),
          subtitle: items.isEmpty
              ? null
              : unread > 0
              ? 'g5.notifications.newCount'.tr(namedArgs: {'count': '$unread'})
              : 'g5.notifications.allRead'.tr(),
        ),
        onRefresh: () async => ref.invalidate(notificationsProvider),
        children: [
          if (async.isLoading && !async.hasValue)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              ),
            )
          else if (items.isEmpty)
            GNote(
              text: 'g5.notifications.empty'.tr(),
              icon: GIcons.bell,
              kind: GNoteKind.plain,
            )
          else ...[
            if (today.isNotEmpty)
              GSection(
                title: 'g5.notifications.today'.tr(),
                trailing: Text(
                  localizedDayMonth(now),
                  style: GText.onest(
                    12.5,
                    weight: FontWeight.w600,
                    color: GColors.textMuted,
                  ),
                ),
                child: _List(
                  items: today,
                  now: now,
                  isUnread: _isUnread,
                  onOpen: _open,
                ),
              ),
            if (earlier.isNotEmpty)
              GSection(
                title: 'g5.notifications.earlier'.tr(),
                child: _List(
                  items: earlier,
                  now: now,
                  isUnread: _isUnread,
                  onOpen: _open,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _timeLabel(DateTime at, DateTime now) {
  if (_sameDay(at, now)) {
    return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }
  if (_sameDay(at, now.subtract(const Duration(days: 1)))) {
    return 'g5.notifications.yesterday'.tr();
  }
  return localizedDayMonth(at);
}

/// Tur → plita ikoni va rangi.
(GIconData, GHue) _lookOf(NotificationType type) => switch (type) {
  NotificationType.achievement => (GIcons.medal, GHue.gold),
  NotificationType.contest => (GIcons.trophy, GHue.orange),
  NotificationType.schedule => (GIcons.calendarDots, GHue.sky),
  NotificationType.parentRequest => (GIcons.camera, GHue.rose),
  NotificationType.voice => (GIcons.usersThree, GHue.rose),
  NotificationType.geoZone => (GIcons.mapPin, GHue.teal),
  NotificationType.system => (GIcons.sparkle, GHue.blue),
  NotificationType.studyNudge => (GIcons.bookOpen, GHue.blue),
  NotificationType.healthNudge => (GIcons.personSimpleRun, GHue.green),
  NotificationType.contentReminder => (GIcons.playCircle, GHue.sky),
};

class _List extends StatelessWidget {
  const _List({
    required this.items,
    required this.now,
    required this.isUnread,
    required this.onOpen,
  });

  final List<AppNotification> items;
  final DateTime now;
  final bool Function(AppNotification) isUnread;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    return GList(
      children: [
        for (final n in items)
          _Row(
            notification: n,
            time: _timeLabel(n.createdAt, now),
            unread: isUnread(n),
            onTap: () => onOpen(n),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.notification,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final AppNotification notification;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, hue) = _lookOf(notification.type);
    final title = notification.title.isNotEmpty
        ? notification.title
        : 'g5.notifications.title'.tr();
    return GListItem(
      title: title,
      subtitle: 'g5.notifications.kind.${notification.type.name}'.tr(),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          GTile(icon: icon, hue: hue, size: 40),
          if (unread)
            Positioned(
              top: -3,
              right: -3,
              child: Semantics(
                label: 'g5.notifications.unreadA11y'.tr(),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8),
                    border: Border.all(
                      color: const Color(0xFF0B1226),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: GText.onest(
              12,
              weight: FontWeight.w600,
              color: GColors.textMuted,
            ),
          ),
          if (unread) ...[
            const SizedBox(height: 6),
            GChip(label: 'g5.notifications.newChip'.tr(), kind: GChipKind.info),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final (icon, hue) = _lookOf(notification.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GTile(icon: icon, hue: hue, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'g5.notifications.kind.${notification.type.name}'.tr(),
                style: GText.onest(
                  13,
                  weight: FontWeight.w600,
                  color: GColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(notification.title, style: GText.h2),
        ),
        if (notification.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .45,
            ),
            child: SingleChildScrollView(
              child: Text(notification.body, style: GText.body),
            ),
          ),
        ],
        const SizedBox(height: 16),
        GButton(
          label: 'g5.common.close'.tr(),
          kind: GButtonKind.ghost,
          size: GButtonSize.second,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
