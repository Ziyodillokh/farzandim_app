// ─────────────────────────────────────────────────────────────────────
// SosAlertsListScreen — Parent SOS alerts (Sprint 4.4.15 + 4.4.19 enh.)
// ─────────────────────────────────────────────────────────────────────
//
// Faol va Tarix tabi. Har bir alert ustida xaritada ko'rish + resolve.
// Backend: GET /api/sos-alerts?status=ACTIVE|RESOLVED + WS sos:* refresh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/sos/data/repositories/backend_sos_repository.dart';
import 'package:farzandim/features/sos/presentation/providers/sos_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Parent App'da bola yuborgan SOS alert'lar ro'yxati (Tabs + Map).
class SosAlertsListScreen extends ConsumerWidget {
  /// `SosAlertsListScreen` konstruktor.
  const SosAlertsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                const _Header(),
                const _Tabs(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _AlertsList(
                        provider: activeSosAlertsProvider,
                        showResolveButton: true,
                        emptyTitle: 'sos.emptyActiveTitle'.tr(),
                        emptySubtitle: 'sos.emptyActiveSubtitle'.tr(),
                        emptyIcon: Icons.check_circle_outline_rounded,
                        emptyIconColor: AppColors.success,
                      ),
                      _AlertsList(
                        provider: resolvedSosAlertsProvider,
                        showResolveButton: false,
                        emptyTitle: 'sos.emptyHistoryTitle'.tr(),
                        emptySubtitle: 'sos.emptyHistorySubtitle'.tr(),
                        emptyIcon: Icons.history_rounded,
                        emptyIconColor: AppColors.textSecondary,
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
}

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
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'sos.headerTitle'.tr(),
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

class _Tabs extends StatelessWidget {
  const _Tabs();
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
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.onPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.bodyM,
        tabs: [
          Tab(text: 'sos.tabActive'.tr()),
          Tab(text: 'sos.tabHistory'.tr()),
        ],
      ),
    );
  }
}

class _AlertsList extends ConsumerWidget {
  const _AlertsList({
    required this.provider,
    required this.showResolveButton,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.emptyIconColor,
  });

  final ProviderListenable<AsyncValue<List<Map<String, dynamic>>>> provider;
  final bool showResolveButton;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final Color emptyIconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'sos.loadFailed'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyM.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppDimensions.md),
              TextButton.icon(
                onPressed: () => ref.invalidate(sosAlertsByStatusProvider),
                icon: Icon(Icons.refresh_rounded, color: AppColors.accent),
                label: Text(
                  'common.retry'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (alerts) {
        if (alerts.isEmpty) {
          // EH-10: bo'sh holatda ham pull-to-refresh ishlasin (avval faqat
          // ro'yxat bor holatda bor edi — bo'sh ekranni yangilab bo'lmasdi).
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(sosAlertsByStatusProvider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _EmptyState(
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    icon: emptyIcon,
                    iconColor: emptyIconColor,
                  ),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(sosAlertsByStatusProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg,
              vertical: AppDimensions.md,
            ),
            itemCount: alerts.length,
            itemBuilder: (_, i) {
              final alert = alerts[i];
              return _AlertTile(
                alert: alert,
                showResolveButton: showResolveButton,
                onResolve: showResolveButton
                    ? () => _confirmResolve(context, ref, alert)
                    : null,
                onShowMap: () => _showMap(context, alert),
              );
            },
          ),
        );
      },
    );
  }

  void _showMap(BuildContext context, Map<String, dynamic> alert) {
    final lat = (alert['latitude'] as num?)?.toDouble();
    final lng = (alert['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sos.noLocationSnack'.tr()),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _LocationMapDialog(
        lat: lat,
        lng: lng,
        title:
            (alert['child'] as Map<String, dynamic>?)?['name'] as String? ??
            'sos.fallbackChildName'.tr(),
      ),
    );
  }

  Future<void> _confirmResolve(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> alert,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'sos.resolveDialogTitle'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'sos.resolveDialogContent'.tr(),
          style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'sos.resolveAction'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final id = alert['id'] as String?;
    if (id == null) return;

    final ok = await ref.read(backendSosRepositoryProvider).resolveAlert(id);
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(sosAlertsByStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sos.resolvedSnack'.tr()),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sos.resolveErrorSnack'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.showResolveButton,
    required this.onResolve,
    required this.onShowMap,
  });

  final Map<String, dynamic> alert;
  final bool showResolveButton;
  final VoidCallback? onResolve;
  final VoidCallback onShowMap;

  @override
  Widget build(BuildContext context) {
    final child = alert['child'] as Map<String, dynamic>?;
    final childName =
        (child?['name'] as String?) ?? 'sos.fallbackChildName'.tr();
    final lat = (alert['latitude'] as num?)?.toDouble();
    final lng = (alert['longitude'] as num?)?.toDouble();
    final createdAt = alert['createdAt'] as String?;
    final resolvedAt = alert['resolvedAt'] as String?;
    final createdTime = _parse(createdAt);
    final resolvedTime = _parse(resolvedAt);
    final hasLocation = lat != null && lng != null;

    final accent = showResolveButton ? AppColors.error : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: SettingsCard(
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SettingsIconChip(
                  icon: showResolveButton
                      ? Icons.warning_amber_rounded
                      : Icons.check_rounded,
                  accent: accent,
                  size: 44,
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showResolveButton
                            ? 'sos.alertTitle'.tr(
                                namedArgs: {'name': childName},
                              )
                            : childName,
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      if (createdTime != null)
                        Text(
                          _formatTime(createdTime),
                          style: AppTextStyles.bodyS.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (!showResolveButton && resolvedTime != null)
                        Text(
                          'sos.resolvedAt'.tr(
                            namedArgs: {'time': _formatTime(resolvedTime)},
                          ),
                          style: AppTextStyles.bodyS.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasLocation) ...[
              const SizedBox(height: AppDimensions.sm),
              Text(
                'sos.locationLine'.tr(
                  namedArgs: {
                    'lat': lat.toStringAsFixed(5),
                    'lng': lng.toStringAsFixed(5),
                  },
                ),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                if (hasLocation)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShowMap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(
                        'sos.mapButton'.tr(),
                        style: AppTextStyles.bodyM,
                      ),
                    ),
                  ),
                if (hasLocation && showResolveButton)
                  const SizedBox(width: AppDimensions.sm),
                if (showResolveButton)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onResolve,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'sos.resolveAction'.tr(),
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static DateTime? _parse(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  // ARCH-07: <24h markaziy formatter (locale-aware). 24h+ esa TO'LIQ
  // sana-vaqt — SOS favqulodda hodisa, soat:daqiqa aniqligi muhim
  // (markaziy "DD.MM" formati bu yerda yetarli emas).
  String _formatTime(DateTime dt) {
    if (DateTime.now().difference(dt).inHours < 24) {
      return formatRelativeTime(dt);
    }
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _LocationMapDialog extends StatelessWidget {
  const _LocationMapDialog({
    required this.lat,
    required this.lng,
    required this.title,
  });

  final double lat;
  final double lng;
  final String title;

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(lat, lng);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppDimensions.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'sos.mapDialogTitle'.tr(namedArgs: {'name': title}),
                    style: AppTextStyles.headlineL.copyWith(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: SizedBox(
              height: 360,
              width: double.infinity,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: pos, zoom: 16),
                markers: {
                  Marker(
                    markerId: const MarkerId('sos'),
                    position: pos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    infoWindow: InfoWindow(title: title),
                  ),
                },
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 48),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              title,
              style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              subtitle,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
