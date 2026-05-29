// ─────────────────────────────────────────────────────────────────────
// DonWalletCard — DON valyuta balansi card
// ─────────────────────────────────────────────────────────────────────
//
// PDF p20: konkurs bonus "+5 DON" — bola valyuta yig'adi. Kelajakda
// shop ekrani (sertifikat, kitob, tovar sotib olish).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DonWalletCard extends StatelessWidget {
  const DonWalletCard({required this.don, super.key});

  final int don;

  static const Color _gold = AppColors.catGold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // ignore: deprecated_member_use
            _gold.withOpacity(0.15),
            // ignore: deprecated_member_use
            _gold.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: _gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: _gold.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on,
              color: _gold,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'gamification.donBalance'.tr(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$don',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'DON',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
