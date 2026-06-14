// ─────────────────────────────────────────────────────────────────────
// UnlockDecisionSheet — ota-ona unlock so'roviga qaror beradi
// ─────────────────────────────────────────────────────────────────────
//
// Bola "qo'shimcha vaqt" so'raganda ota-ona shu pastki varaqда qaror beradi:
//   - "Rad etish" → deny (result: UnlockDecision.deny())
//   - 5 / 15 / 30 / 60 daqiqa → grant (result: UnlockDecision.grant(min))
//   - tashqariga bossa → null (bekor)

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Sheet natijasi — rad etish yoki N daqiqa berish.
@immutable
class UnlockDecision {
  const UnlockDecision._(this.approve, this.minutes);
  const UnlockDecision.deny() : this._(false, null);
  const UnlockDecision.grant(int minutes) : this._(true, minutes);

  final bool approve;
  final int? minutes;
}

class UnlockDecisionSheet extends StatelessWidget {
  const UnlockDecisionSheet({
    required this.childName,
    this.appName,
    super.key,
  });

  /// Qaysi bola so'rayapti (sarlavhada ko'rsatiladi).
  final String childName;

  /// APP so'rovi bo'lsa ilova nomi (bo'lmasa ekran vaqti).
  final String? appName;

  /// Varaqni ochadi; tanlangan qaror (bekor bo'lsa null) qaytadi.
  static Future<UnlockDecision?> show(
    BuildContext context, {
    required String childName,
    String? appName,
  }) {
    return showModalBottomSheet<UnlockDecision>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) =>
          UnlockDecisionSheet(childName: childName, appName: appName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = (appName != null && appName!.trim().isNotEmpty)
        ? appName!
        : 'ekran vaqti';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.md,
          AppDimensions.lg,
          AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              "Qo'shimcha vaqt",
              style: AppTextStyles.headlineL.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              '$childName — "$subject" uchun qo\'shimcha vaqt so\'rayapti. '
              'Qancha vaqt berasiz?',
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            // Daqiqa variantlari
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final m in const [5, 15, 30, 60])
                  _MinuteChip(
                    minutes: m,
                    onTap: () => Navigator.of(context)
                        .pop(UnlockDecision.grant(m)),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            // Rad etish
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 1.4,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context).pop(const UnlockDecision.deny()),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Rad etish',
                        style: AppTextStyles.bodyM.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinuteChip extends StatelessWidget {
  const _MinuteChip({required this.minutes, required this.onTap});
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.6),
          width: 1.4,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            '$minutes daqiqa',
            style: AppTextStyles.bodyM.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
