// ─────────────────────────────────────────────────────────────────────
// ConsentScreen — Parent Consent (App Store / Play Store compliance)
// ─────────────────────────────────────────────────────────────────────
//
// Bola ilovasi BIRINCHI marta ochilganda ko'rsatiladi. Splash dan keyin,
// /pairing dan oldin. Rozilik berilmaguncha keyingi sahifaga
// o'tib bo'lmaydi (router redirect himoyasi).
//
// "Ota-onam tasdiqlaydi" tugmasi — oddiy 1 marta bosish (ilgari 3s ushlab
// turish edi, soddalashtirildi). Tugmani ota-ona bosishi kutiladi (matn +
// izoh shuni bildiradi). Bosilgach ma'lumot yig'ishga rozilik yoziladi.
//
// Tasdiqlangach: SharedPreferences `parent_consent_v1 = true` yoziladi,
// router avtomatik /splash → keyingi ekran (pairing yoki dashboard)ga
// o'tkazadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/consent/presentation/providers/consent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _confirming = false;

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    HapticFeedback.mediumImpact();
    // Routerning `refreshListenable` o'zgargan state'ni eshitib, /consent dan
    // keyingi marshrutga (/splash → ...) o'tkazadi — qo'lda navigatsiya yo'q.
    await ref.read(consentStateProvider.notifier).confirm();
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      await launchUrl(
        Uri.parse('https://farzandimedu.uz/privacy.html'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* havola ochilmadi — jimgina o'tkazamiz */
    }
  }

  void _decline() {
    // Rad etilsa — ilova ma'lumot yig'maydi. Ilovadan chiqamiz.
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const _ShieldBadge(color: AppColors.parvozGreen),
                      const SizedBox(height: 24),
                      Text(
                        'consent.title'.tr(),
                        style: const TextStyle(
                          color: AppColors.parvozText,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'consent.subtitle'.tr(),
                        style: const TextStyle(
                          color: AppColors.parvozTextDim,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ConsentBullet(
                        icon: Icons.location_on_rounded,
                        title: 'consent.locationTitle'.tr(),
                        text: 'consent.locationText'.tr(),
                      ),
                      _ConsentBullet(
                        icon: Icons.apps_rounded,
                        title: 'consent.usageTitle'.tr(),
                        text: 'consent.usageText'.tr(),
                      ),
                      _ConsentBullet(
                        icon: Icons.notifications_active_rounded,
                        title: 'consent.notificationsTitle'.tr(),
                        text: 'consent.notificationsText'.tr(),
                      ),
                      _ConsentBullet(
                        icon: Icons.shield_rounded,
                        title: 'consent.securityTitle'.tr(),
                        text: 'consent.securityText'.tr(),
                      ),
                      _ConsentBullet(
                        icon: Icons.lock_rounded,
                        title: 'consent.privacyTitle'.tr(),
                        text: 'consent.privacyText'.tr(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ConfirmButton(
                confirming: _confirming,
                onTap: _confirming ? null : () => unawaited(_confirm()),
              ),
              const SizedBox(height: 12),
              Text(
                'consent.holdHint'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.parvozTextDim,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              // Maxfiylik siyosati havolasi + "rad etish" (Play consent talabi).
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _openPrivacyPolicy,
                    child: Text(
                      'consent.privacyPolicy'.tr(),
                      style: const TextStyle(
                        color: AppColors.parvozBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    '·',
                    style: TextStyle(color: AppColors.parvozTextDim),
                  ),
                  TextButton(
                    onPressed: _decline,
                    child: Text(
                      'consent.decline'.tr(),
                      style: const TextStyle(
                        color: AppColors.parvozTextDim,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Icon(Icons.verified_user_rounded, color: color, size: 38),
    );
  }
}

class _ConsentBullet extends StatelessWidget {
  const _ConsentBullet({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.parvozGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.parvozGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.parvozText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.parvozTextDim,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ota-onam tasdiqlaydi" — oddiy 1 marta bosiladigan aqua tugma.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.confirming, required this.onTap});

  final bool confirming;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.parvozGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.parvozGreen.withValues(alpha: 0.35),
              offset: const Offset(0, 6),
              blurRadius: 18,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirming) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.parvozOnGreen,
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.parvozOnGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],
              Text(
                confirming
                    ? 'consent.confirming'.tr()
                    : 'consent.confirmButton'.tr(),
                style: const TextStyle(
                  color: AppColors.parvozOnGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
