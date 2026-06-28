// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'support_chat_screen.dart';

// ════════════════════════ INPUT BAR ════════════════════════

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  // Pill balandligi — ingichka, Telegram uslubidagi yagona qator.
  static const double _barHeight = 46;

  @override
  Widget build(BuildContext context) {
    // Parent ekran allaqachon SafeArea bilan o'ralgan — bu yerda takror yo'q.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm,
        AppDimensions.xs,
        AppDimensions.sm,
        AppDimensions.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Yagona ingichka pill: matn + biriktirma (📎 o'ngda). Ichki
          // "qo'sh-quti" yo'q — TextField to'ldirishi butunlay o'chirilgan.
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: _barHeight),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(_barHeight / 2),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 4, 12),
                      child: TextField(
                        controller: controller,
                        style: AppTextStyles.bodyM,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          isDense: true,
                          // Global theme `filled:true` ichki quti chizardi —
                          // bu yerda butunlay o'chiramiz (yagona pill).
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'support.inputHint'.tr(),
                          hintStyle: AppTextStyles.bodyM.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Biriktirma — pill ichida o'ngda (Telegram'dagidek).
                  SizedBox(
                    width: 42,
                    height: _barHeight,
                    child: IconButton(
                      onPressed: onAttach,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        SolarIconsBold.paperclip,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.xs + 2),
          // Yuborish — alohida yumaloq tugma (matn borligida lime).
          GestureDetector(
            onTap: hasText ? onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _barHeight,
              height: _barHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasText ? AppColors.primary : AppColors.surface,
                shape: BoxShape.circle,
                border: hasText ? null : Border.all(color: AppColors.border),
              ),
              child: Icon(
                SolarIconsBold.plain,
                size: 20,
                color: hasText ? AppColors.onPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ ATTACHMENT SHEET ════════════════════════

enum _AttachKind { image, video, document }

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.md,
          horizontal: AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            _AttachOption(
              icon: SolarIconsBold.gallery,
              label: 'support.attach.image'.tr(),
              color: AppColors.info,
              onTap: () => Navigator.of(context).pop(_AttachKind.image),
            ),
            _AttachOption(
              icon: SolarIconsBold.videocamera,
              label: 'support.attach.video'.tr(),
              color: AppColors.warning,
              onTap: () => Navigator.of(context).pop(_AttachKind.video),
            ),
            _AttachOption(
              icon: SolarIconsBold.file,
              label: 'support.attach.document'.tr(),
              color: AppColors.success,
              onTap: () => Navigator.of(context).pop(_AttachKind.document),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppDimensions.md),
            Text(label, style: AppTextStyles.bodyM),
          ],
        ),
      ),
    );
  }
}
