// ─────────────────────────────────────────────────────────────────────
// ForceUpdateDialog — majburiy yangilash (yopib bo'lmaydigan modal)
// ─────────────────────────────────────────────────────────────────────
//
// `forceUpdateRequired` state'da app.dart ko'rsatadi. Eski versiya bilan
// davom etib bo'lmaydi (PopScope canPop:false). Dizayn: Parvoz KO'K —
// avval `AppColors` yashil edi, hozirgi ko'k dizaynga mos emas edi.
//
// MUHIM: asosiy tugma `status.targetUrl`ni ochadi — provider uni
// `storeUrl ?? directApkUrl` qilib hisoblagan. Avval dialog to'g'ridan
// `playStoreUrl`ni ochardi; parent hali Do'konda yo'q (faqat APK), shuning
// uchun tugma `null` ochib HECH NARSA qilmasdi. Endi APK-only holatda ham
// ishlaydi va yorliq mos ("Yuklab olish (APK)").

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Parvoz tokenlar ───
const Color _bg = Color(0xFF12171E); // modal karta foni
const Color _blue = Color(0xFF216BFF);
const Color _white = Colors.white;
const Color _dim = Color(0x8CFFFFFF); // oq 55%
const Color _dimmer = Color(0x66FFFFFF); // oq 40%
const Color _field = Color(0x14FFFFFF); // release-notes qutisi
const Color _border = Color(0x1FFFFFFF); // oq 12%

class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({required this.status, super.key});

  final AppUpdateStatus status;

  static Future<void> show(BuildContext context, AppUpdateStatus status) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xF200060A),
      builder: (_) => ForceUpdateDialog(status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = status.info;
    final platform = Theme.of(context).platform;
    final isIos = platform == TargetPlatform.iOS;
    final platformInfo = info == null
        ? null
        : (isIos ? info.ios : info.android);

    // Do'kon havolasi bormi? Yo'q bo'lsa — to'g'ridan APK.
    final hasStore = platformInfo?.storeUrl != null;
    final primaryLabel = hasStore
        ? (isIos
              ? 'appUpdate.force.openAppStore'.tr()
              : 'appUpdate.force.openPlayStore'.tr())
        : 'appUpdate.force.downloadApk'.tr();
    final primaryIcon = hasStore
        ? (isIos ? SolarIconsBold.smartphone : SolarIconsBold.shop)
        : SolarIconsBold.download;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _border),
        ),
        insetPadding: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  SolarIconsBold.smartphoneUpdate,
                  color: _blue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'appUpdate.force.title'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.unbounded(
                  color: _white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'appUpdate.force.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _dim,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _VersionRow(
                current: status.currentVersion,
                latest: platformInfo?.latest ?? '—',
              ),
              if (info != null && info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    info.releaseNotes,
                    style: GoogleFonts.poppins(
                      color: _white,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _PrimaryButton(
                label: primaryLabel,
                icon: primaryIcon,
                // Provider hisoblagan URL: storeUrl ?? directApkUrl.
                onPressed: () => _launch(status.targetUrl),
              ),
              // Do'kon havolasi ASOSIY bo'lsa va APK ham bor bo'lsa — APK
              // muqobil tugma. APK allaqachon asosiy bo'lsa (do'kon yo'q),
              // takror ko'rsatmaymiz.
              if (hasStore && !isIos && platformInfo?.directApkUrl != null) ...[
                const SizedBox(height: 10),
                _SecondaryButton(
                  label: 'appUpdate.force.downloadApk'.tr(),
                  icon: SolarIconsBold.download,
                  onPressed: () => _launch(platformInfo!.directApkUrl),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launch(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.current, required this.latest});
  final String current;
  final String latest;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _versionChip('appUpdate.force.currentLabel'.tr(), current, _dim),
        const Icon(SolarIconsBold.altArrowRight, color: _dimmer, size: 20),
        _versionChip('appUpdate.force.latestLabel'.tr(), latest, _blue),
      ],
    );
  }

  Widget _versionChip(String label, String version, Color accent) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _dimmer,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          version,
          style: GoogleFonts.poppins(
            color: accent,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: _white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _white,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
