import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/widgets/notification_card.dart';
import 'package:farzandim/features/notifications/presentation/widgets/sos_alert_dialog.dart';
import 'package:farzandim/features/notifications/presentation/widgets/unlock_decision_sheet.dart';
import 'package:farzandim/features/pair_requests/data/repositories/backend_pair_request_repository.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

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
              icon: Icon(
                SolarIconsBold.altArrowLeft,
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
    // SOS xabarlar doim tepada (eng muhim), keyin vaqt bo'yicha yangi→eski.
    final items = [...notifications]
      ..sort((a, b) {
        final aSos = a.type == NotificationType.sos ? 0 : 1;
        final bSos = b.type == NotificationType.sos ? 0 : 1;
        if (aSos != bSos) return aSos - bSos;
        return b.timestamp.compareTo(a.timestamp);
      });
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, i) {
        final n = items[i];
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
            child: const Icon(
              SolarIconsBold.trashBinMinimalistic,
              color: Colors.white,
            ),
          ),
          onDismissed: (_) =>
              ref.read(notificationsProvider.notifier).deleteNotification(n.id),
          child: NotificationCard(
            notification: n,
            onTap: () => _onTap(context, ref, n),
            onReview: n.isActionable
                ? () => n.isUnlockRequest
                      ? _decideUnlock(context, ref, n)
                      : _review(context, ref, n)
                : null,
            onReject: n.isActionable
                ? () => n.isUnlockRequest
                      ? _denyUnlock(context, ref, n)
                      : _reject(context, ref, n)
                : null,
            onBlock: n.isGame ? () => _block(context, ref, n) : null,
            reviewLabel: n.isUnlockRequest ? 'Vaqt ber' : null,
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
        // Past batareya — bola qayerdaligini ko'rsatish muhim (quvvat
        // tugashidan oldin joyni bilish): jonli xarita ekraniga olib boramiz.
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.locationPath(n.childId));
        }
      case NotificationType.appLimit:
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.appRestrictionsPath(n.childId));
        }
      case NotificationType.game:
        // Tap → cheklovlar ekrani; asosiy amal pastdagi "Bloklash" tugmasida.
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
      case NotificationType.unlockRequest:
        // Tap → qaror varag'ini ochamiz (asosiy amal tugmalarda ham bor).
        _decideUnlock(context, ref, n);
      case NotificationType.permissionChanged:
        // Ruxsat holati — cheklovlar/qurilma ekraniga.
        if (n.childId.isNotEmpty) {
          context.push(AppRoutes.appRestrictionsPath(n.childId));
        }
      case NotificationType.offline:
      case NotificationType.online:
        break;
    }
  }

  // ─── "Vaqt ber" — unlock so'roviga qaror (sheet: rad et / 5·15·30·60) ───

  Future<void> _decideUnlock(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    ref.read(notificationsProvider.notifier).markAsRead(n.id);
    final reqId = n.unlockRequestId;
    if (reqId == null || reqId.isEmpty) return;

    final decision = await UnlockDecisionSheet.show(
      context,
      childName: n.childName,
      appName: n.appName ?? n.packageName,
      requestedMinutes: n.requestedMinutes,
      reason: n.unlockReason,
    );
    if (decision == null || !context.mounted) return;

    final ok = await ref
        .read(backendUnlockRequestRepositoryProvider)
        .decide(
          requestId: reqId,
          approve: decision.approve,
          minutes: decision.minutes,
        );
    // Qaror berilgach xabarni o'chiramiz (qайта harakat kerak emas).
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (!context.mounted) return;
    final msg = !ok
        ? "Xatolik. Qaytadan urinib ko'ring."
        : decision.approve
        ? '${decision.minutes} daqiqa ruxsat berildi.'
        : "So'rov rad etildi.";
    if (ok) {
      AppToast.success(context, msg);
    } else {
      AppToast.error(context, msg);
    }
  }

  // ─── "Rad et" — unlock so'rovini tezda rad etish (sheet'siz) ───

  Future<void> _denyUnlock(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final reqId = n.unlockRequestId;
    if (reqId != null && reqId.isNotEmpty) {
      await ref
          .read(backendUnlockRequestRepositoryProvider)
          .decide(requestId: reqId, approve: false);
    }
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (context.mounted) {
      AppToast.info(context, 'notifications.rejected'.tr());
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
      await ref
          .read(backendPairRequestRepositoryProvider)
          .reject(childId: n.childId, requestId: reqId);
    }
    ref.read(notificationsProvider.notifier).deleteNotification(n.id);
    if (context.mounted) {
      AppToast.info(context, 'notifications.rejected'.tr());
    }
  }

  // ─── "Bloklash" — o'yinni to'liq bloklash (app-limit dailyLimitMs=0) ───

  Future<void> _block(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final pkg = n.packageName;
    if (pkg == null || pkg.isEmpty || n.childId.isEmpty) return;
    final appName = n.appName ?? n.childName;
    try {
      await ref
          .read(appRestrictionRepositoryProvider)
          .blockApp(childId: n.childId, packageName: pkg, appName: appName);
      ref.read(notificationsProvider.notifier).markAsRead(n.id);
      if (context.mounted) {
        AppToast.info(
          context,
          'notifications.blockedSnack'.tr(namedArgs: {'app': appName}),
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'notifications.blockError'.tr());
      }
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
              SolarIconsBold.mailbox,
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
