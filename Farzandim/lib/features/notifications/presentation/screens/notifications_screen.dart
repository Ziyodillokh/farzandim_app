import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notification_card.dart';
import 'package:farzandim/features/notifications/presentation/widgets/sos_alert_dialog.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bildirishnomalar markazi — barcha xabarlar tarixi (Sprint 4.4.21).
///
/// **Funksionallik:**
/// - SharedPreferences persistence (app restart'dan keyin tiklanadi)
/// - 4 ta filter tab: Hammasi / SOS / Zonalar / Boshqa
/// - Date grouping: Bugun / Kecha / Avvalgi (sticky-style headerlar)
/// - "Hammasini o'qildi qil" tugma (faqat o'qilmagan bor paytda)
/// - Clear all (top right menu)
/// - Dismissible swipe (chap → o'ng = o'chirish)
/// - Karta bossa: o'qilgan deb belgilash + type bo'yicha navigatsiya
class NotificationsScreen extends ConsumerWidget {
  /// `NotificationsScreen` konstruktor.
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  showMarkAllRead: unreadCount > 0,
                  onMarkAllRead: () => ref
                      .read(notificationsProvider.notifier)
                      .markAllAsRead(),
                  onClearAll: () => _confirmClearAll(context, ref),
                ),
                const _FilterTabs(),
                const Expanded(
                  child: TabBarView(
                    physics: BouncingScrollPhysics(),
                    children: [
                      _NotificationsTabContent(
                        filter: NotificationFilter.all,
                      ),
                      _NotificationsTabContent(
                        filter: NotificationFilter.sos,
                      ),
                      _NotificationsTabContent(
                        filter: NotificationFilter.zones,
                      ),
                      _NotificationsTabContent(
                        filter: NotificationFilter.other,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Hammasini o\'chirish?',
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'Bildirishnomalar tarixi tozalanadi. Bu amalni qaytarib '
          'bo\'lmaydi.',
          style: AppTextStyles.bodyM
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Bekor qilish',
              style: AppTextStyles.bodyM
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'O\'chirish',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(notificationsProvider.notifier).clearAll();
    }
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.showMarkAllRead,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  final bool showMarkAllRead;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'notifications.title'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          if (showMarkAllRead)
            TextButton(
              onPressed: onMarkAllRead,
              child: Text(
                'notifications.markAllRead'.tr(),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textPrimary,
            ),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'clear') onClearAll();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep_outlined,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hammasini o\'chirish',
                      style: AppTextStyles.bodyM
                          .copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ FILTER TABS ════════════════════════

class _FilterTabs extends StatelessWidget {
  const _FilterTabs();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
            AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.bodyM,
        tabs: const [
          Tab(text: 'Hammasi'),
          Tab(text: 'SOS'),
          Tab(text: 'Zonalar'),
          Tab(text: 'Boshqa'),
        ],
      ),
    );
  }
}

// ════════════════════════ TAB CONTENT ════════════════════════

class _NotificationsTabContent extends ConsumerWidget {
  const _NotificationsTabContent({required this.filter});
  final NotificationFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredNotificationsProvider(filter));
    if (list.isEmpty) {
      return _EmptyState(filter: filter);
    }
    final grouped = _groupByDate(list);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      itemCount: grouped.length,
      itemBuilder: (ctx, i) => grouped[i].build(context, ref, i),
    );
  }

  List<_GroupItem> _groupByDate(List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String labelFor(DateTime dt) {
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d == today) return 'Bugun';
      if (d == yesterday) return 'Kecha';
      return 'Avvalgi';
    }

    final items = <_GroupItem>[];
    String? currentLabel;
    for (final n in notifications) {
      final label = labelFor(n.timestamp);
      if (label != currentLabel) {
        items.add(_HeaderItem(label));
        currentLabel = label;
      }
      items.add(_NotificationItem(n));
    }
    return items;
  }
}

// ════════════════════════ LIST ITEMS ════════════════════════

sealed class _GroupItem {
  Widget build(BuildContext context, WidgetRef ref, int index);
}

class _HeaderItem extends _GroupItem {
  _HeaderItem(this.label);
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref, int index) {
    return Padding(
      padding: EdgeInsets.only(
        top: index == 0 ? 0 : AppDimensions.md,
        bottom: AppDimensions.sm,
        left: 4,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyS.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _NotificationItem extends _GroupItem {
  _NotificationItem(this.notification);
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppDimensions.lg),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => ref
            .read(notificationsProvider.notifier)
            .deleteNotification(notification.id),
        child: NotificationCard(
          notification: notification,
          onTap: () => _onTap(context, ref, notification),
        ),
      ).animate().fadeIn(
            duration: 250.ms,
            delay: (30 * index).ms,
            curve: Curves.easeOut,
          ),
    );
  }

  void _onTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notif,
  ) {
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);
    switch (notif.type) {
      case NotificationType.sos:
        SosAlertDialog.show(context, notif);
      case NotificationType.enterZone:
      case NotificationType.exitZone:
        context.push(AppRoutes.locationPath(notif.childId));
      case NotificationType.lowBattery:
        context.push(AppRoutes.qaDevicePath(notif.childId));
      case NotificationType.appLimit:
        context.push(AppRoutes.appRestrictionsPath(notif.childId));
      case NotificationType.scheduleStart:
      case NotificationType.scheduleReminder:
        context.push(AppRoutes.schedulesPath(notif.childId));
      case NotificationType.pairRequest:
        if (notif.childId.isNotEmpty) {
          context.push(AppRoutes.pairRequestsPath(notif.childId));
        }
      case NotificationType.offline:
      case NotificationType.online:
        // Boshqa harakat yo'q — faqat o'qilgan deb belgilanadi.
        break;
    }
  }
}

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final NotificationFilter filter;

  String get _title => switch (filter) {
        NotificationFilter.all => 'notifications.emptyTitle'.tr(),
        NotificationFilter.sos => 'SOS yo\'q',
        NotificationFilter.zones => 'Zona xabarlari yo\'q',
        NotificationFilter.other => 'Boshqa xabarlar yo\'q',
      };

  String get _subtitle => switch (filter) {
        NotificationFilter.all => 'notifications.emptySubtitle'.tr(),
        NotificationFilter.sos =>
          'Bola SOS bosganda bu yerda ko\'rinadi.',
        NotificationFilter.zones =>
          'Bola geo-zonadan kirgan/chiqqanda ko\'rinadi.',
        NotificationFilter.other =>
          'Jadval, batareya va boshqa xabarlar shu yerda.',
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              _title,
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              _subtitle,
              style: AppTextStyles.bodyS
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
