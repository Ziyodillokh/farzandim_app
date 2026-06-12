// ARCH-13: monolit ekran fayli `part` fayllarga bo'lindi — private nomlar
// va vizual xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'location_map_screen.dart';

// ════════════════════════ TOP BAR ════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(),
        ),
        const Spacer(),
        _ChildSelectorChip(child: child),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                icon,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildSelectorChip extends ConsumerWidget {
  const _ChildSelectorChip({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenListProvider);
    final hasMultiple = children.length > 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasMultiple ? () => _openPicker(context, children) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChildAvatar(child: child, size: 32, showBorder: false),
                const SizedBox(width: 8),
                Text(
                  child.name,
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasMultiple) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    List<Child> children,
  ) async {
    final selected = await showModalBottomSheet<Child>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Text(
                'location.picker.title'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              ),
            ),
            for (final c in children)
              ListTile(
                leading: ChildAvatar(child: c, size: 40),
                title: Text(c.name, style: AppTextStyles.bodyM),
                trailing: c.id == child.id
                    ? Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
            const SizedBox(height: AppDimensions.sm),
          ],
        ),
      ),
    );

    if (selected != null && selected.id != child.id && context.mounted) {
      context.pushReplacement(AppRoutes.locationPath(selected.id));
    }
  }
}

// ════════════════════════ NO LOCATION ════════════════════════

class _NoLocationState extends StatelessWidget {
  const _NoLocationState({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: _TopBar(child: child),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 80,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'location.noLocation.title'.tr(),
                    style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'location.noLocation.subtitle'.tr(
                      namedArgs: {'name': child.name},
                    ),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ ERROR STATE ════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.child, required this.error});

  final Child child;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: _TopBar(child: child),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'location.error.title'.tr(),
                    style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    '$error',
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ NO CHILDREN ════════════════════════

class _NoChildrenScreen extends StatelessWidget {
  const _NoChildrenScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            'location.noChildren'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
