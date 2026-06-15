// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'support_chat_screen.dart';

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
          const _OperatorAvatar(size: 42, showOnlineDot: true),
          const SizedBox(width: AppDimensions.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'support.operator'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'support.online'.tr(),
                  style: AppTextStyles.label.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),
          _CallButton(),
        ],
      ),
    );
  }
}

/// Operator avatari — brand gradient doira + support ikona. Header'da
/// online nuqta bilan, bubble yonida nuqtasiz.
class _OperatorAvatar extends StatelessWidget {
  const _OperatorAvatar({required this.size, this.showOnlineDot = false});
  final double size;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.support_agent_rounded,
        color: AppColors.onPrimary,
        size: size * 0.55,
      ),
    );
    if (!showOnlineDot) return avatar;
    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppToast.info(context, 'settings.comingSoon'.tr());
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.call_outlined,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ DATE SEPARATOR ════════════════════════

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    String two(int n) => n.toString().padLeft(2, '0');
    final label = isToday
        ? 'support.today'.tr()
        : '${two(date.day)}.${two(date.month)}.${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ════════════════════════ TYPING INDIKATOR ════════════════════════

/// Operator "yozmoqda…" qatori — avatar + 3 nuqtali animatsiyali bubble.
class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _OperatorAvatar(size: 28),
          const SizedBox(width: AppDimensions.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _dot(i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    // Har nuqta 0.2 siljish bilan ko'tarilib-tushadi (silliq to'lqin).
    final t = (_controller.value + index * 0.2) % 1.0;
    final wave = (t < 0.5 ? t : 1 - t) * 2; // 0→1→0
    return Transform.translate(
      offset: Offset(0, -3 * wave),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.5 + 0.5 * wave),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
