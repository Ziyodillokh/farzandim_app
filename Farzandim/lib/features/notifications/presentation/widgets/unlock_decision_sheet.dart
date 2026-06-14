// ─────────────────────────────────────────────────────────────────────
// UnlockDecisionSheet — ota-ona unlock so'roviga qaror beradi
// ─────────────────────────────────────────────────────────────────────
//
// Bola "qo'shimcha vaqt" so'raganda (so'ralgan daqiqa + sabab bilan) ota-ona
// shu pastki varaqda qaror beradi:
//   - "Tasdiqlash ({N} daqiqa)" → bola so'ragan miqdorni o'shancha beradi
//   - "Boshqa muddat" chiplari (5/15/30/60) → boshqa miqdor berish
//   - "Rad etish" → deny
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
    this.requestedMinutes,
    this.reason,
    super.key,
  });

  /// Qaysi bola so'rayapti (sarlavhada ko'rsatiladi).
  final String childName;

  /// APP so'rovi bo'lsa ilova nomi (bo'lmasa ekran vaqti).
  final String? appName;

  /// Bola so'ragan daqiqa (5..60). null bo'lsa eski oqim — faqat chiplar.
  final int? requestedMinutes;

  /// Bola yozgan sabab (ixtiyoriy).
  final String? reason;

  /// Varaqni ochadi; tanlangan qaror (bekor bo'lsa null) qaytadi.
  static Future<UnlockDecision?> show(
    BuildContext context, {
    required String childName,
    String? appName,
    int? requestedMinutes,
    String? reason,
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
      builder: (_) => UnlockDecisionSheet(
        childName: childName,
        appName: appName,
        requestedMinutes: requestedMinutes,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = (appName != null && appName!.trim().isNotEmpty)
        ? appName!
        : 'ekran vaqti';
    final req = requestedMinutes;
    final reasonText = reason?.trim();
    // So'ralgan miqdor bo'lsa, chiplar "boshqa muddat" sifatida shu qiymatni
    // takrorlamasin (asosiy tugmada bor).
    final chipMinutes =
        const [5, 15, 30, 60].where((m) => m != req).toList(growable: false);

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
              req != null
                  ? '$childName — "$subject" uchun $req daqiqa '
                      "qo'shimcha vaqt so'rayapti."
                  : '$childName — "$subject" uchun qo\'shimcha vaqt '
                      "so'rayapti. Qancha vaqt berasiz?",
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            // Sabab (bola yozgan bo'lsa).
            if (reasonText != null && reasonText.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.md),
              _ReasonBox(reason: reasonText),
            ],
            const SizedBox(height: AppDimensions.lg),
            // Asosiy amal — bola so'ragan miqdorni o'shancha tasdiqlash.
            if (req != null) ...[
              _ApproveRequestedButton(
                minutes: req,
                onTap: () =>
                    Navigator.of(context).pop(UnlockDecision.grant(req)),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Boshqa muddat berish:',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Daqiqa variantlari (so'ralgan miqdordan boshqa muddatlar).
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final m in chipMinutes)
                  _MinuteChip(
                    minutes: m,
                    onTap: () =>
                        Navigator.of(context).pop(UnlockDecision.grant(m)),
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

/// Bola yozgan sabab — yumshoq fon ichidagi quote.
class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tasdiqlash ({N} daqiqa)" — to'liq-kenglik asosiy lime tugma.
class _ApproveRequestedButton extends StatelessWidget {
  const _ApproveRequestedButton({required this.minutes, required this.onTap});
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.primary,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: Colors.black,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tasdiqlash ($minutes daqiqa)',
                  style: AppTextStyles.bodyM.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
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
