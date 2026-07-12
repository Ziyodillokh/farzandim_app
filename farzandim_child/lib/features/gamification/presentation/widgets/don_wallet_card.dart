// ─────────────────────────────────────────────────────────────────────
// DonWalletCard — XP balansi card (avval DON valyuta edi)
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanuvchi talabiga ko'ra DON valyuta o'rniga XP ko'rsatiladi —
// "Mening XP balansim". Shop ekrani kelajakda alohida joyga
// ko'chiriladi (DON valyuta backend'da saqlanib qoladi).

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DonWalletCard extends StatelessWidget {
  const DonWalletCard({required this.xp, super.key});

  final int xp;

  static const Color _gold = AppColors.catGold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      // Row Expanded ostida tor joyga sig'ishi uchun ikon yumshoq kichik,
      // tekst esa wrap qilinadi — overflow oldini olish.
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: _gold.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: _gold, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mening XP balansim',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.adaptive.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        '$xp',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.adaptive.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'XP',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
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
