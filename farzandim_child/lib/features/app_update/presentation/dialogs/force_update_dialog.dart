// ─────────────────────────────────────────────────────────────────────
// ForceUpdateDialog — Majburiy yangilash modal (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────
//
// `forceUpdateRequired` state'da app ildiz widget tomondan ko'rsatiladi.
// Foydalanuvchi yopa olmaydi (barrierDismissible: false, WillPopScope
// false). Faqat Store/APK link'ga o'tib telefon'da yangilash mumkin.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';

class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({required this.status, super.key});

  final AppUpdateStatus status;

  static Future<void> show(BuildContext context, AppUpdateStatus status) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.backgroundBottom.withValues(alpha: 0.92),
      builder: (_) => ForceUpdateDialog(status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = status.info;
    final platform = Theme.of(context).platform;
    final platformInfo = info == null
        ? null
        : (platform == TargetPlatform.iOS ? info.ios : info.android);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'appUpdate.forceTitle'.tr(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'appUpdate.forceMessage'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
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
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _PrimaryButton(
                label: platform == TargetPlatform.iOS
                    ? 'appUpdate.openAppStore'.tr()
                    : 'appUpdate.openPlayMarket'.tr(),
                icon: platform == TargetPlatform.iOS
                    ? Icons.apple_rounded
                    : Icons.shop_rounded,
                onPressed: () => _launch(
                  platformInfo?.playStoreUrl ?? platformInfo?.appStoreUrl,
                ),
              ),
              if (platformInfo?.directApkUrl != null &&
                  platform != TargetPlatform.iOS) ...[
                const SizedBox(height: 10),
                _SecondaryButton(
                  label: 'appUpdate.downloadApk'.tr(),
                  icon: Icons.download_rounded,
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
        _versionChip(
          'appUpdate.currentVersion'.tr(),
          current,
          AppColors.textSecondary,
        ),
        const Icon(AppIcons.forward, color: AppColors.textTertiary, size: 20),
        _versionChip('appUpdate.latestVersion'.tr(), latest, AppColors.primary),
      ],
    );
  }

  Widget _versionChip(String label, String version, Color accent) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          version,
          style: TextStyle(
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
