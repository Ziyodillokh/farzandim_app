// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'app_limits_screen.dart';

// ════════════════════════ LIMIT MODAL ════════════════════════

enum _LimitMode { block, limit, unlimited }

class AppLimitModal extends ConsumerStatefulWidget {
  const AppLimitModal({required this.app, required this.childId, super.key});

  final AppCombined app;
  final String childId;

  @override
  ConsumerState<AppLimitModal> createState() => _AppLimitModalState();
}

class _AppLimitModalState extends ConsumerState<AppLimitModal> {
  late _LimitMode _mode;
  late int _limitMinutes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.app.restriction;
    if (r != null && r.isBlocked) {
      _mode = _LimitMode.block;
      _limitMinutes = r.limitMinutes > 0 ? r.limitMinutes : 60;
    } else if (widget.app.hasLimit) {
      _mode = _LimitMode.limit;
      _limitMinutes = r?.limitMinutes ?? 60;
    } else {
      _mode = _LimitMode.unlimited;
      _limitMinutes = 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final name = widget.app.appName.isEmpty
        ? widget.app.packageName
        : widget.app.appName;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.md,
          AppDimensions.lg,
          AppDimensions.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              name,
              style: AppTextStyles.headlineL.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimensions.lg),

            // ─── Ilovani bloklash (toggle) ───
            _OptionCard(
              selected: _mode == _LimitMode.block,
              onTap: () => setState(() => _mode = _LimitMode.block),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'appLimits.block'.tr(),
                          style: AppTextStyles.bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'appLimits.blockDesc'.tr(),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: _mode == _LimitMode.block,
                    activeColor: AppColors.error,
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _mode = v
                                ? _LimitMode.block
                                : _LimitMode.unlimited,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.sm),

            // ─── Limit belgilash (tahrirlash bilan) ───
            _OptionCard(
              selected: _mode == _LimitMode.limit,
              onTap: () => setState(() => _mode = _LimitMode.limit),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'appLimits.setLimit'.tr(),
                          style: AppTextStyles.bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatMinutes(_limitMinutes),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _editDuration,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('appLimits.edit'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.sm),

            // ─── Cheklanmagan vaqt ───
            _OptionCard(
              selected: _mode == _LimitMode.unlimited,
              onTap: () => setState(() => _mode = _LimitMode.unlimited),
              child: Row(
                children: [
                  Icon(
                    Icons.all_inclusive_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Text(
                    'appLimits.unlimited'.tr(),
                    style: AppTextStyles.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // ─── Bekor qilish / Qo'llash ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
                      ),
                    ),
                    child: Text('appLimits.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Text(
                            'appLimits.apply'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editDuration() async {
    setState(() => _mode = _LimitMode.limit);
    var picked = Duration(minutes: _limitMinutes);
    final result = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'appLimits.pickDuration'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(minutes: _limitMinutes),
                    onTimerDurationChanged: (d) => picked = d,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(picked),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusPill,
                        ),
                      ),
                    ),
                    child: Text('appLimits.apply'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) {
      final mins = result.inMinutes.clamp(1, 24 * 60);
      setState(() => _limitMinutes = mins);
    }
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    final facade = ref.read(appRestrictionRepositoryProvider);
    final pkg = widget.app.packageName;
    final name = widget.app.appName;
    try {
      switch (_mode) {
        case _LimitMode.block:
          await facade.blockApp(
            childId: widget.childId,
            packageName: pkg,
            appName: name,
          );
        case _LimitMode.limit:
          await facade.setLimit(
            childId: widget.childId,
            packageName: pkg,
            appName: name,
            limitMinutes: _limitMinutes,
          );
        case _LimitMode.unlimited:
          await facade.removeLimit(childId: widget.childId, packageName: pkg);
      }
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, 'appLimits.saved'.tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        // Aniq sabab (AppLimitException) ko'rsatamiz — generic "saqlashda
        // xatolik" o'rniga, foydalanuvchi muammoni tushunishi uchun.
        AppToast.error(
          context,
          e is AppLimitException ? e.message : 'appLimits.saveError'.tr(),
        );
      }
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) {
      return 'appLimits.durationMinutes'.tr(namedArgs: {'minutes': '$m'});
    }
    if (m == 0) {
      return 'appLimits.durationHours'.tr(namedArgs: {'hours': '$h'});
    }
    return 'formatters.duration'.tr(
      namedArgs: {'hours': '$h', 'minutes': '$m'},
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
