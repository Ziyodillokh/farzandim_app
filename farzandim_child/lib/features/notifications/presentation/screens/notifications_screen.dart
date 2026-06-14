// ─────────────────────────────────────────────────────────────────────
// NotificationsScreen — bola bildirishnoma markazi (PDF p7)
// ─────────────────────────────────────────────────────────────────────
//
// Tarkib:
//   1. Top header (LOGO + SOS + avatar)
//   2. "Bildirishnoma" sarlavhasi + "Hammasini o'qildi" tugmasi
//   3. NotificationTabs (Barchasi / Yangiliklar)
//   4. NotificationCard list (yangi → eski)
//   5. EmptyState (bo'sh bo'lsa, FARO sleeping bilan)

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/notifications/presentation/widgets/notification_card.dart';
import 'package:farzandim_child/features/notifications/presentation/widgets/notification_tabs.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(notificationsProvider);
    final filtered = ref.watch(filteredNotificationsProvider);
    // Sprint 4.4.9: Firestore permission-denied'da exception throw qilmaslik.
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        // Dark fon — mockup'ga mos (kartalar dark, fon ham dark).
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16161F), Color(0xFF0E0E16)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DashboardTopHeader(
                  onAvatarTap: () => context.push('/account-edit'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'notifications.title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      TextButton.icon(
                        onPressed: () => _markAllAsRead(ref),
                        icon: const Icon(AppIcons.success, size: 18),
                        label: Text('notifications.markAllRead'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: NotificationTabs(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: allAsync.when(
                  data: (_) => _buildList(context, ref, filtered),
                  // Shimmer skeleton — notification card list shape
                  loading: () => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const SkeletonRowCard(),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'common.errorPrefix'
                            .tr(namedArgs: {'error': '$e'}),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    if (items.isEmpty) {
      return EmptyStateMascot(
        faroVariant: FaroVariant.faceSleeping,
        title: 'notifications.emptyTitle'.tr(),
        subtitle: 'notifications.emptySubtitle'.tr(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final notification = items[i];
        // Stagger: har kartochka 50ms kechikish bilan fade-up
        return NotificationCard(
          notification: notification,
          onTap: () => _onTap(context, ref, notification),
          onDismiss: () => _onDismiss(ref, notification.id),
        )
            .animate()
            .fadeIn(
              duration: 300.ms,
              delay: (50 * i).ms,
              curve: Curves.easeOut,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
              delay: (50 * i).ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  void _onTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    // Sprint 4.4.9.5: Backend mark as read (silently) + provider refresh.
    final repo = ref.read(backendNotificationRepositoryProvider);
    if (!notification.isRead) {
      repo.markAsRead(notification.id).then((_) {
        ref.invalidate(notificationsProvider);
      });
    }

    // Navigate to related route
    final route = notification.relatedRoute;
    if (route != null && route.isNotEmpty) {
      context.push(route);
    }
  }

  void _onDismiss(WidgetRef ref, String notificationId) {
    final repo = ref.read(backendNotificationRepositoryProvider);
    repo.deleteNotification(notificationId).then((_) {
      ref.invalidate(notificationsProvider);
    });
  }

  Future<void> _markAllAsRead(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final pairing = ref.read(pairingStateProvider);
    final childId = pairing.childId;
    if (childId == null) return;
    final repo = ref.read(backendNotificationRepositoryProvider);
    await repo.markAllAsRead(childId);
    ref.invalidate(notificationsProvider);
  }
}
