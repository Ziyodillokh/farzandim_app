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

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/notification_tokens.dart';
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
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
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
      body: GradientBackground(
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
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      GestureDetector(
                        onTap: () => _markAllAsRead(ref),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: NotifTokens.successSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 16, color: NotifTokens.success),
                              SizedBox(width: 6),
                              Text(
                                "O'qildi",
                                style: TextStyle(
                                  color: NotifTokens.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _refresh(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    ref.invalidate(notificationsProvider);
    try {
      await ref.read(notificationsProvider.future);
    } catch (_) {}
  }

  /// Sana bo'limi yorlig'i: Bugun / Kecha / Bu hafta / Avvalroq.
  static String _bucketLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff <= 0) return 'Bugun';
    if (diff == 1) return 'Kecha';
    if (diff < 7) return 'Bu hafta';
    return 'Avvalroq';
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    // Bo'sh holat ham pastga tortib yangilanadigan bo'lsin.
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.10),
            EmptyStateMascot(
              faroVariant: FaroVariant.faceSleeping,
              title: 'notifications.emptyTitle'.tr(),
              subtitle: 'notifications.emptySubtitle'.tr(),
            ),
          ],
        ),
      );
    }

    // Sana bo'yicha guruhlaymiz (ro'yxat allaqachon yangi → eski tartibda).
    final order = <String>[];
    final groups = <String, List<AppNotification>>{};
    for (final n in items) {
      final label = _bucketLabel(n.createdAt);
      if (!groups.containsKey(label)) {
        groups[label] = <AppNotification>[];
        order.add(label);
      }
      groups[label]!.add(n);
    }

    // Bo'lim sarlavhalari + kartalar — yagona tekis ro'yxat.
    final rows = <Widget>[];
    for (final label in order) {
      rows.add(_SectionHeader(label: label));
      for (final n in groups[label]!) {
        rows.add(
          NotificationCard(
            notification: n,
            onTap: () => _onTap(context, ref, n),
            onDismiss: () => _onDismiss(ref, n.id),
          ),
        );
      }
    }

    // prefers-reduced-motion — kirish animatsiyasini o'chiramiz.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _refresh(ref),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          if (reduce) return rows[i];
          // Staggered: fade + 18px yuqoriga sirpanish, ~80ms kechikish
          // (uzun ro'yxatda umumiy kechikish cheklangan).
          final delay = (80 * math.min(i, 9)).ms;
          return rows[i]
              .animate()
              .fadeIn(duration: 320.ms, delay: delay, curve: Curves.easeOut)
              .moveY(
                begin: 18,
                end: 0,
                duration: 320.ms,
                delay: delay,
                curve: Curves.easeOutCubic,
              );
        },
      ),
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

/// Sana bo'limi sarlavhasi (Bugun / Kecha / Bu hafta / Avvalroq).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
