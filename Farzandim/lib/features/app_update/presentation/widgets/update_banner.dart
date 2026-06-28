// ─────────────────────────────────────────────────────────────────────
// UpdateBanner — Parent Dashboard top'idagi yumshoq taklif
// (Sprint 4.4.28)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStatus = ref.watch(appUpdateProvider);
    final status = asyncStatus.valueOrNull;
    if (status == null || status.state != UpdateState.softUpdateAvailable) {
      return const SizedBox.shrink();
    }
    final info = status.info;
    if (info == null) return const SizedBox.shrink();

    final platform = Theme.of(context).platform;
    final platformInfo = platform == TargetPlatform.iOS
        ? info.ios
        : info.android;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  SolarIconsBold.smartphoneUpdate,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'appUpdate.banner.title'.tr(
                        namedArgs: {'version': platformInfo.latest},
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (info.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        info.releaseNotes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _launch(status.targetUrl),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'appUpdate.banner.updateButton'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'appUpdate.banner.dismissTooltip'.tr(),
                icon: Icon(
                  SolarIconsBold.closeCircle,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => ref
                    .read(appUpdateProvider.notifier)
                    .dismissSoftUpdate(platformInfo.latest),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
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
