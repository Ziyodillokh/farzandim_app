// ─────────────────────────────────────────────────────────────────────
// IosSetupBanner — iOS: nazorat to'liq ishlashi uchun yetishmayotgan sozlama
// ─────────────────────────────────────────────────────────────────────
//
// Ekran vaqti (Family Controls) ruxsati bo'lmasa ota-ona cheklovlari
// iPhone'da umuman ishlamaydi; joylashuv "Har doim" bo'lmasa ilova fonda
// uxlaydi — xarita yangilanmaydi, ota-ona o'zgarishlari kechikadi. Avval bu
// holat jim qolardi; banner bosilsa tegishli joy ochiladi. Ilovaga
// qaytilganda holat qayta tekshiriladi.
//
// Joylashuv eslatmasini bola yopishi mumkin (×) — 7 kun ko'rinmaydi
// (Apple 5.1.1: ruxsatga majburlovchi doimiy ogohlantirish bo'lmasin).
// Ekran vaqti eslatmasi yopilmaydi — busiz ota-ona cheklovlari ishlamaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/screen_time/domain/banner_snooze.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';

/// Joylashuv eslatmasi yopilgan vaqt (ms, epoch).
const _kLocationBannerDismissedAtKey = 'ios_location_banner_dismissed_at_ms';

/// Joylashuv "Har doim" berilganmi (xato bo'lsa — banner ko'rsatilmaydi).
final _locationAlwaysProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await Permission.locationAlways.isGranted;
  } catch (_) {
    return true;
  }
});

/// Joylashuv eslatmasi hozir yopiq (snooze) holatdami.
final _locationBannerSnoozedProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return isBannerSnoozed(
      dismissedAtMs: prefs.getInt(_kLocationBannerDismissedAtKey),
      now: DateTime.now(),
    );
  } catch (_) {
    return false;
  }
});

class IosSetupBanner extends ConsumerStatefulWidget {
  const IosSetupBanner({super.key});

  @override
  ConsumerState<IosSetupBanner> createState() => _IosSetupBannerState();
}

class _IosSetupBannerState extends ConsumerState<IosSetupBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref
      ..invalidate(screenTimeStatusProvider)
      ..invalidate(_locationAlwaysProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.isIOS) return const SizedBox.shrink();
    final screenTime = ref.watch(screenTimeStatusProvider).valueOrNull;
    final isLocationAlways = ref.watch(_locationAlwaysProvider).valueOrNull;
    final isLocationSnoozed =
        ref.watch(_locationBannerSnoozedProvider).valueOrNull ?? true;

    if (screenTime != null && !screenTime.isAuthorized) {
      return _BannerCard(
        icon: Icons.hourglass_bottom_rounded,
        title: 'screenTime.bannerAuthTitle'.tr(),
        body: 'screenTime.bannerAuthBody'.tr(),
        onTap: () => context.push('/screen-time'),
      );
    }
    if (isLocationAlways == false && !isLocationSnoozed) {
      return _BannerCard(
        icon: Icons.location_on_rounded,
        title: 'screenTime.bannerLocationTitle'.tr(),
        body: 'screenTime.bannerLocationBody'.tr(),
        onTap: openAppSettings,
        onDismiss: _dismissLocationBanner,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _dismissLocationBanner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kLocationBannerDismissedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('IosSetupBanner: yopish saqlanmadi: $e');
    }
    if (mounted) ref.invalidate(_locationBannerSnoozedProvider);
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.onDismiss,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  /// Berilsa — "×" tugmasi (eslatmani yopish).
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.adaptive.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          color: context.adaptive.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss case final dismiss?)
                  IconButton(
                    onPressed: dismiss,
                    tooltip: 'common.close'.tr(),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.adaptive.textSecondary,
                      size: 20,
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.warning,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
