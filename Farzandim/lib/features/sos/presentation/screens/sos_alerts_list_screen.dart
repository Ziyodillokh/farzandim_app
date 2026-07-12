// SOS alert'lar ro'yxati: Faol va Tarix tabi, xaritada ko'rish, resolve.
//
// REDIZAYN: eski gradient/SettingsCard o'rniga yangi qora-glass dizayn
// (Manzillar/Ilova haqida bilan bir xil top-bar, kartalar, Solar ikonlar).
// Xarita dialogi endi keyless flutter_map (CARTO) — web'da GoogleMap kalitsiz
// crash bo'lardi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/map/map_tiles.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/sos/data/repositories/backend_sos_repository.dart';
import 'package:farzandim/features/sos/presentation/providers/sos_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── Yangi dizayn tokenlari (Manzillar/Joylashuv bilan bir xil) ───
const Color _bg = Color(0xFF0B0B10); // qora fon
const Color _cardBg = Color(0xFF1A1B22); // qoramtir karta
const Color _cardBorder = Color(0x14FFFFFF); // oq ~8% chegara
const Color _dim = Color(0x99FFFFFF); // oq 60% ikkilamchi matn
const Color _glassBtn = Color(0xE6121C2E); // top-bar tugma foni

/// Parent App'da bola yuborgan SOS alert'lar ro'yxati.
class SosAlertsListScreen extends ConsumerWidget {
  const SosAlertsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
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
                      emptyIcon: SolarIconsBold.checkCircle,
                      emptyIconColor: AppColors.success,
                    ),
                    _AlertsList(
                      provider: resolvedSosAlertsProvider,
                      showResolveButton: false,
                      emptyTitle: 'sos.emptyHistoryTitle'.tr(),
                      emptySubtitle: 'sos.emptyHistorySubtitle'.tr(),
                      emptyIcon: SolarIconsBold.history,
                      emptyIconColor: _dim,
                    ),
                  ],
                ),
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
      // Boshqa yangi ekranlar bilan bir xil: tepadan pastroq (md + 44).
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md + 44,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: SolarIconsOutline.arrowLeft,
            onTap: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'sos.headerTitle'.tr(),
                style: AppTextStyles.headlineL.copyWith(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}

/// Top-bar yumaloq-kvadrat shisha tugmasi (yangi dizayn uslubi).
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _glassBtn,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: Icon(icon, size: 22, color: Colors.white)),
        ),
      ),
    );
  }
}

// ════════════════════════ TABS ════════════════════════

class _Tabs extends StatelessWidget {
  const _Tabs();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardBorder),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.info,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _dim,
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

// ════════════════════════ RO'YXAT ════════════════════════

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
          Center(child: CircularProgressIndicator(color: AppColors.info)),
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
                icon: Icon(SolarIconsBold.refresh, color: AppColors.info),
                label: Text(
                  'common.retry'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.info,
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
          // Bo'sh holatda ham pull-to-refresh ishlashi kerak, shuning
          // uchun scrollable ichiga o'raymiz.
          return RefreshIndicator(
            color: AppColors.info,
            backgroundColor: _cardBg,
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
          color: AppColors.info,
          backgroundColor: _cardBg,
          onRefresh: () async {
            ref.invalidate(sosAlertsByStatusProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.sm,
              AppDimensions.md,
              AppDimensions.lg,
            ),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
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
      AppToast.warning(context, 'sos.noLocationSnack'.tr());
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
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _cardBorder),
        ),
        title: Text(
          'sos.resolveDialogTitle'.tr(),
          style: AppTextStyles.headlineL.copyWith(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        content: Text(
          'sos.resolveDialogContent'.tr(),
          style: AppTextStyles.bodyM.copyWith(color: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(color: _dim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'sos.resolveAction'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.success,
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
      AppToast.success(context, 'sos.resolvedSnack'.tr());
    } else {
      AppToast.error(context, 'sos.resolveErrorSnack'.tr());
    }
  }
}

// ════════════════════════ ALERT KARTASI ════════════════════════

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
    final createdTime = _parse(alert['createdAt'] as String?);
    final resolvedTime = _parse(alert['resolvedAt'] as String?);
    final hasLocation = lat != null && lng != null;

    // Faol → qizil (favqulodda), Tarix → yashil (hal qilingan).
    final accent = showResolveButton ? AppColors.error : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status ikon-chip (yumshoq rangli doira).
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  showResolveButton
                      ? SolarIconsBold.dangerTriangle
                      : SolarIconsBold.checkCircle,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showResolveButton
                          ? 'sos.alertTitle'.tr(namedArgs: {'name': childName})
                          : childName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    if (createdTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _formatTime(createdTime),
                          style: AppTextStyles.bodyS.copyWith(color: _dim),
                        ),
                      ),
                    if (!showResolveButton && resolvedTime != null)
                      Text(
                        'sos.resolvedAt'.tr(
                          namedArgs: {'time': _formatTime(resolvedTime)},
                        ),
                        style: AppTextStyles.bodyS.copyWith(
                          color: _dim,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: AppDimensions.sm + 2),
            // Joylashuv qatori — kichik xarita-nuqta ikoni + koordinata.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(SolarIconsBold.mapPoint, size: 16, color: _dim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'sos.locationLine'.tr(
                        namedArgs: {
                          'lat': lat.toStringAsFixed(5),
                          'lng': lng.toStringAsFixed(5),
                        },
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyS.copyWith(
                        color: _dim,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(SolarIconsBold.map, size: 18),
                    label: Text(
                      'sos.mapButton'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyM,
                    ),
                  ),
                ),
              if (hasLocation && showResolveButton)
                const SizedBox(width: AppDimensions.sm),
              if (showResolveButton)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onResolve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(SolarIconsBold.checkCircle, size: 18),
                    label: Text(
                      'sos.resolveAction'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyM.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static DateTime? _parse(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  // 24 soatgacha nisbiy vaqt, undan eskisi to'liq sana-vaqt — SOS
  // favqulodda hodisa, soat:daqiqa aniqligi kerak.
  String _formatTime(DateTime dt) {
    if (DateTime.now().difference(dt).inHours < 24) {
      return formatRelativeTime(dt);
    }
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════ XARITA DIALOGI ════════════════════════

/// SOS joyini keyless flutter_map (CARTO) xaritada ko'rsatuvchi dialog.
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
      backgroundColor: _cardBg,
      insetPadding: const EdgeInsets.all(AppDimensions.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Icon(SolarIconsBold.mapPoint, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'sos.mapDialogTitle'.tr(namedArgs: {'name': title}),
                    style: AppTextStyles.headlineL.copyWith(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    SolarIconsBold.closeCircle,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(19),
            ),
            child: SizedBox(
              height: 360,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: pos,
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: mapTileUrl,
                        userAgentPackageName: kMapUserAgent,
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pos,
                            width: 46,
                            height: 46,
                            child: const _SosMarker(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Attribution (ToS talabi).
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mapAttribution,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Xaritadagi qizil SOS nuqta belgisi.
class _SosMarker extends StatelessWidget {
  const _SosMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        SolarIconsBold.dangerTriangle,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

// ════════════════════════ BO'SH HOLAT ════════════════════════

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
                color: iconColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 48),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              title,
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 18,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              subtitle,
              style: AppTextStyles.bodyS.copyWith(color: _dim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
