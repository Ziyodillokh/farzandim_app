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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pill maydon: 📎 ichkarida + matn (messenger-style).
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Biriktirma — maydon ichida (Telegram'dagidek).
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      onPressed: onAttach,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: AppDimensions.md,
                        top: 13,
                        bottom: 13,
                      ),
                      child: TextField(
                        controller: controller,
                        style: AppTextStyles.bodyM,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'support.inputHint'.tr(),
                          hintStyle: AppTextStyles.bodyM.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Yuborish tugmasi — matn borligida brand gradient bilan jonlanadi.
          AnimatedScale(
            scale: hasText ? 1 : 0.9,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: hasText
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, AppColors.primary],
                      )
                    : null,
                color: hasText ? null : AppColors.surface,
                shape: BoxShape.circle,
                border: hasText ? null : Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasText ? onSend : null,
                  child: Icon(
                    Icons.send_rounded,
                    color: hasText
                        ? AppColors.onPrimary
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
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
              icon: Icons.image_rounded,
              label: 'support.attach.image'.tr(),
              color: AppColors.info,
              onTap: () => Navigator.of(context).pop(_AttachKind.image),
            ),
            _AttachOption(
              icon: Icons.videocam_rounded,
              label: 'support.attach.video'.tr(),
              color: AppColors.warning,
              onTap: () => Navigator.of(context).pop(_AttachKind.video),
            ),
            _AttachOption(
              icon: Icons.insert_drive_file_rounded,
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
