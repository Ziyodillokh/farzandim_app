// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'app_limits_screen.dart';

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm,
        AppDimensions.sm,
        AppDimensions.sm,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              SolarIconsBold.altArrowLeft,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineL.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48), // back tugma balansi
        ],
      ),
    );
  }
}

// ════════════════════════ CHILD CHIPS ════════════════════════

class _ChildChips extends ConsumerWidget {
  const _ChildChips({
    required this.childIds,
    required this.selectedId,
    required this.onSelect,
  });

  final List<String> childIds;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
        itemCount: childIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.sm),
        itemBuilder: (context, i) {
          final id = childIds[i];
          final child = ref.watch(childByIdProvider(id));
          final selected = id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Row(
                children: [
                  if (child != null)
                    ChildAvatar(child: child, size: 24, showBorder: false),
                  const SizedBox(width: 6),
                  Text(
                    child?.name ?? '—',
                    style: AppTextStyles.bodyS.copyWith(
                      color: selected
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════ APP LIST ════════════════════════

class _AppList extends StatelessWidget {
  const _AppList({required this.apps, required this.childId});

  final List<AppCombined> apps;
  final String childId;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Text(
            'appLimits.noApps'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    // ONGLI QAROR (PERF vs dizayn): barcha qatorlar BITTA SettingsCard
    // ichida — karta balandligi kontentga qarab o'sadi, shuning uchun
    // lazy builder ishlatib bo'lmaydi (DecoratedSliver bilan kartani
    // qayta chizish vizual regressiya xavfi). Qatorlar yengil (ikonka
    // keshi AppIconWidget'da memoizatsiyalangan), ro'yxat qurilma
    // ilovalari bilan chegaralangan — bir martalik build qabul qilingan.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.xl,
      ),
      children: [
        SettingsCard(
          accent: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
          child: Column(
            children: [
              for (var i = 0; i < apps.length; i++) ...[
                _AppRow(
                  app: apps[i],
                  onTap: () => _openModal(context, apps[i]),
                ),
                if (i != apps.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openModal(BuildContext context, AppCombined app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => AppLimitModal(app: app, childId: childId),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onTap});

  final AppCombined app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm + 2,
        ),
        child: Row(
          children: [
            AppIconWidget(
              packageName: app.packageName,
              iconUrl: app.iconUrl,
              iconBase64: app.iconBase64,
              size: 40,
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName.isEmpty ? app.packageName : app.appName,
                    style: AppTextStyles.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.usageFormatted,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            _RightStatus(app: app),
          ],
        ),
      ),
    );
  }
}

class _RightStatus extends StatelessWidget {
  const _RightStatus({required this.app});

  final AppCombined app;

  @override
  Widget build(BuildContext context) {
    if (app.isBlocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'appLimits.blocked'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Icon(
            SolarIconsBold.forbiddenCircle,
            size: 18,
            color: AppColors.error,
          ),
        ],
      );
    }
    if (app.hasLimit) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            app.limitFormatted ?? '',
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(SolarIconsBold.hourglass, size: 18, color: AppColors.accent),
        ],
      );
    }
    // Limit yo'q — bosib qo'yish mumkinligini bildiruvchi xira ikonka.
    return Icon(
      SolarIconsBold.hourglass,
      size: 18,
      color: AppColors.textTertiary,
    );
  }
}
