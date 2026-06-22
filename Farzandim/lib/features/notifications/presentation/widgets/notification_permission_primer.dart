import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Primer bir marta ko'rsatilganini eslab qoladigan kalit.
const String _primerShownKey = 'notif_primer_shown';

/// Login'dan keyin BIR MARTA ko'rsatiladigan bildirishnoma "primer"i.
///
/// Play Store tavsiyasi: OS ruxsat dialogidan oldin NEGA kerakligini
/// tushuntiruvchi "rationale" ko'rsatish. Bu opt-in foizini oshiradi va
/// foydalanuvchi ilova nimaligini bilmay turib rad etmaydi.
///
/// Oqim:
///   - ruxsat allaqachon berilgan  → faqat token saqlanadi (dialogsiz)
///   - doimiy rad etilgan          → bezovta qilinmaydi
///   - hali so'ralmagan            → rationale ko'rsatiladi → "Ruxsat berish"
///     bosilsa OS dialogi chiqadi va token saqlanadi
class NotificationPermissionPrimer {
  const NotificationPermissionPrimer._();

  /// Kerak bo'lsa primer'ni ko'rsatadi, so'ng ruxsatni so'rab token saqlaydi.
  static Future<void> ensure(BuildContext context, WidgetRef ref) async {
    final status = await Permission.notification.status;

    // Allaqachon berilgan — faqat token'ni registratsiya qilamiz (dialog yo'q).
    if (status.isGranted) {
      await ref.read(fcmServiceProvider).registerToken();
      return;
    }

    // Doimiy rad — qayta nag qilmaymiz (foydalanuvchi Sozlamalardan yoqsa
    // bo'ladi).
    if (status.isPermanentlyDenied) return;

    // Primer avval ko'rsatilgan bo'lsa qayta bezovta qilmaymiz.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_primerShownKey) ?? false) return;

    if (!context.mounted) return;
    final accepted = await _showPrimerSheet(context);
    await prefs.setBool(_primerShownKey, true);
    if (accepted != true) return;

    final result = await Permission.notification.request();
    if (result.isGranted) {
      await ref.read(fcmServiceProvider).registerToken();
    }
  }

  static Future<bool?> _showPrimerSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'permissions.notifPrimerTitle'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'permissions.notifPrimerBody'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'permissions.notifPrimerAllow'.tr(),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'permissions.notifPrimerLater'.tr(),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
