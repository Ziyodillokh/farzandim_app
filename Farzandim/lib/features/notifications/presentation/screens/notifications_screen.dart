import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notification_card.dart';
import 'package:farzandim/features/notifications/presentation/widgets/sos_alert_dialog.dart';
import 'package:farzandim/features/pair_requests/data/repositories/backend_pair_request_repository.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bildirishnomalar markazi (Figma 1:1, Sprint 7 redesign).
///
/// Sodda tekis ro'yxat: aksiyali xabarlar (pair so'rov) "Tekshirish" /
/// "Rad etish" tugmalari bilan, info xabarlar tugmasiz. Bo'sh holatda
/// pochta qutisi rasmi. Swipe (← o'ng→chap) bilan o'chirish.
class NotificationsScreen extends ConsumerWidget {
  /// `NotificationsScreen` konstruktor.
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: notifications.isEmpty
                    ? const _EmptyState()
                    : _NotificationsList(notifications: notifications),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

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
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ════════════════════════ LIST ════════════════════════

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList({required this.notifications});
  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, i) {
        final n = notifications[i];
        return Dismissible(
          key: ValueKey(n.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppDimensions.lg),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => ref
              .read(notificationsProvider.notifier)
              .deleteNotification(n.id),
          child: NotificationCard(
            notification: n,
            onTap: () => _onTap(context, ref, n),
            onReview: n.isActionable ? () => _review(context, ref, n) : null,
            onReject: n.isActionable ? () => _reject(context, ref, n) : null,
          ),
        ).animate().fadeIn(
              duration: 220.ms,
              delay: (30 * i).ms,
              curve: Curves.easeOut,
            );
      },
    );
  }

  // ─── Karta bossa: o'qilgan + navigatsiya ───

  void _onTap(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markAsRead(n.id);
    switch (n.type) {
      case NotificationType.sos:
        SosAlertDialog.show(context, n);
      case NotificationType.enterZone:
      case NotificationType.exitZone:
        context.push(AppRoutes.locationPath(n.childId));
      case NotificationType.lowBattery:
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.qaDevicePath(n.childId));
        }
      case NotificationType.appLimit:
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.appRestrictionsPath(n.childId));
        }
      case NotificationType.scheduleStart:
      case NotificationType.scheduleReminder:
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.schedulesPath(n.childId));
        }
      case NotificationType.pairRequest:
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.pairRequestsPath(n.childId));
        }
      case NotificationType.offline:
      case NotificationType.online:
        break;
    }
  }

  // ─── "Tekshirish" — pair so'rovni ko'rish ───

  void _review(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markAsRead(n.id);
    if (n.childId.isNotEmpty) {
      context.push(AppRoutes.pairRequestsPath(n.childId));
    }
  }

  // ─── "Rad etish" — pair so'rovni rad etish + xabarni o'chirish ───

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final reqId = n.pairRequestId;
    if (reqId != null && n.childId.isNotEmpty) {
      await ref.read(backendPairRequestRepositoryProvider).reject(
            childId: n.childId,
            requestId: reqId,
          );
    }
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('notifications.rejected'.tr()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceVariant,
          ),
        );
    }
  }
}

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pochta qutisi rasmi (Figma'dagi illyustratsiyaga yaqin).
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.surfaceVariant,
                  AppColors.surface.withValues(alpha: 0.4),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.markunread_mailbox_rounded,
              size: 76,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'notifications.emptyTitle'.tr(),
            style: AppTextStyles.bodyM.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
