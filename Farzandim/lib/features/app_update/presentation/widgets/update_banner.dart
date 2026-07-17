// ─────────────────────────────────────────────────────────────────────
// UpdateBanner — Dashboard tepasidagi yumshoq "yangilash" taklifi
// ─────────────────────────────────────────────────────────────────────
//
// Faqat `softUpdateAvailable` state'da ko'rinadi (majburiy yangilash —
// alohida ForceUpdateDialog). "Yangilash" tugma Store/APK URL'ni ochadi,
// "×" tugma shu versiyani 24 soatga yashiradi.
//
// Dizayn: Parvoz KO'K (dashboard bilan bir xil til) — avval `AppColors`
// yashil edi, ko'k dashboardda yot ko'rinardi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Parvoz tokenlar (dashboard bilan bir xil) ───
const Color _blue = Color(0xFF216BFF);
const Color _white = Colors.white;
const Color _dim = Color(0x8CFFFFFF); // oq 55%

class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appUpdateProvider).valueOrNull;
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blue.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  SolarIconsBold.smartphoneUpdate,
                  color: _blue,
                  size: 22,
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
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (info.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        info.releaseNotes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: _dim,
                          fontSize: 12,
                          height: 1.35,
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
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'appUpdate.banner.updateButton'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'appUpdate.banner.dismissTooltip'.tr(),
                icon: const Icon(
                  SolarIconsBold.closeCircle,
                  size: 18,
                  color: _dim,
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
