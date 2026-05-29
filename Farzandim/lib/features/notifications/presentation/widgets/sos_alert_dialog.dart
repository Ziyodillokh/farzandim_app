import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/shared/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// SOS xabari ko'rinishi — ota-onaning eng muhim notification'i.
///
/// Tashqaridan yopilmaydi (`barrierDismissible: false`) — foydalanuvchi
/// "Joylashuv", "Qo'ng'iroq" yoki "Yopish" tugmalaridan birini tanlaydi.
class SosAlertDialog extends ConsumerStatefulWidget {
  /// `SosAlertDialog` konstruktor.
  const SosAlertDialog({required this.notification, super.key});

  /// SOS xabari ma'lumoti.
  final AppNotification notification;

  /// Dialog'ni ochish.
  static Future<void> show(
    BuildContext context,
    AppNotification notif,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SosAlertDialog(notification: notif),
    );
  }

  @override
  ConsumerState<SosAlertDialog> createState() => _SosAlertDialogState();
}

class _SosAlertDialogState extends ConsumerState<SosAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// "Qo'ng'iroq" tugmasi bosilganda:
  ///   1. childByIdProvider'dan bola obyektini olamiz (phoneNumber bilan)
  ///   2. phoneNumber bor bo'lsa → `tel:` URI bilan native dialer ochish
  ///   3. Yo'q bo'lsa → SnackBar bilan ogohlantirish
  Future<void> _onCallPressed(AppNotification notif) async {
    final child = ref.read(childByIdProvider(notif.childId));
    final phone = child?.phoneNumber;
    Navigator.of(context).pop();

    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notifications.sos.callNoPhone'.tr()),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notifications.sos.callFailed'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppDimensions.lg),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          border: Border.all(color: AppColors.error, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsating qizil ring + ikonka.
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final scale = 1 + (_pulseController.value * 0.2);
                return Container(
                  width: 100 * scale,
                  height: 100 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(
                      alpha: 0.15 + _pulseController.value * 0.15,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'notifications.sos.title'.tr(),
              style: AppTextStyles.headlineXL.copyWith(
                color: AppColors.error,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'notifications.sos.subtitle'.tr(
                namedArgs: {'name': notif.childName},
              ),
              style: AppTextStyles.bodyM,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              formatRelativeTime(notif.timestamp),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'notifications.sos.locationButton'.tr(),
                    icon: Icons.location_on,
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(
                        AppRoutes.locationPath(notif.childId),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CallButton(
                    onPressed: () => _onCallPressed(notif),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'notifications.sos.close'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qizil "Qo'ng'iroq" tugmasi — pill, oq matn.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: Material(
        color: AppColors.error,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.white),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  'notifications.sos.callButton'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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
