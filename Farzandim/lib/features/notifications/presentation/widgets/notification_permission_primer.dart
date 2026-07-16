import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_icons/solar_icons.dart';

/// Primer bir marta ko'rsatilganini eslab qoladigan kalit.
const String _primerShownKey = 'notif_primer_shown';

// ════════════ Parvoz varaq tokenlari ════════════
// Reyting ekranidagi "DON qanday yig'iladi?" varag'i bilan AYNAN bir xil —
// ilovada bitta varaq uslubi bo'lsin.
const _sheetBg = Color(0xFF12171E);
const _sheetBorder = Color(0x14FFFFFF); // oq ~8%
const _dim = Color(0x99FFFFFF); // oq 60%

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
      isScrollControlled: true,
      // Fon/radius `_PrimerSheet` ichida — Parvoz varaqlari shu tartibda.
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => const _PrimerSheet(),
    );
  }
}

/// Bildirishnoma primer varag'i — Parvoz uslubi (qorong'i varaq, ko'k porlash,
/// Unbounded sarlavha). Avval eski tema ranglari (yashil `AppColors.primary`)
/// ishlatilardi va ilovaning qolgan qismidan ajralib turardi.
class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _sheetBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tortish dastagi
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 26),
              // Qo'ng'iroq ikonasi — ko'k porlash bilan.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ParvozColors.blue.withValues(alpha: 0.16),
                  border: Border.all(
                    color: ParvozColors.blue.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ParvozColors.glow.withValues(alpha: 0.28),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  SolarIconsBold.bellBing,
                  color: ParvozColors.blueLight,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'permissions.notifPrimerTitle'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.unbounded(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.45,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'permissions.notifPrimerBody'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _dim,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              ParvozPrimaryButton(
                label: 'permissions.notifPrimerAllow'.tr(),
                showArrow: false,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'permissions.notifPrimerLater'.tr(),
                  style: GoogleFonts.poppins(fontSize: 14, color: _dim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
