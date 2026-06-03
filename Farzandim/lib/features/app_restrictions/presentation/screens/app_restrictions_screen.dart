import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_combined.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_combined_tile.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_tile_skeleton.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola ilovalar foydalanish + cheklov ekrani (PDF p13 layout).
///
/// **2 ta tab:**
/// - **Hammasi:** barcha ilovalar (foydalanish + limit qo'yilgan)
///   foydalanish bo'yicha desc tartiblangan.
/// - **Cheklov bo'yicha:** faqat limit yoki block qo'yilgan ilovalar.
///
/// **Tile tap:** limit bottom sheet — ChoiceChip (15/30/60/120/180 daq)
/// + "Butunlay bloklash" Switch + Saqlash + (mavjud bo'lsa)
/// "Cheklovni olib tashlash".
class AppRestrictionsScreen extends ConsumerStatefulWidget {
  /// `AppRestrictionsScreen` konstruktor.
  const AppRestrictionsScreen({required this.childId, super.key});

  /// Qaysi bola uchun.
  final String childId;

  @override
  ConsumerState<AppRestrictionsScreen> createState() =>
      _AppRestrictionsScreenState();
}

class _AppRestrictionsScreenState
    extends ConsumerState<AppRestrictionsScreen> {
  late String _childId;

  @override
  void initState() {
    super.initState();
    _childId = widget.childId;
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenListProvider);
    final usageAsync = ref.watch(todayUsageProvider(_childId));
    final restrictionsAsync = ref.watch(restrictionsProvider(_childId));
    final installedAsync = ref.watch(installedAppsProvider(_childId));
    final child = ref.watch(childByIdProvider(_childId));
    final childName =
        child?.name ?? 'appRestrictions.fallbackChildName'.tr();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _FaollikHeader(title: 'deviceSettings.activity'.tr()),
              if (children.length > 1)
                _ChildChips(
                  children: children,
                  selectedId: _childId,
                  onSelect: (id) => setState(() => _childId = id),
                ),
              Expanded(
                child: usageAsync.when(
                  data: (usage) => restrictionsAsync.when(
                    data: (restrictions) {
                      final installed =
                          installedAsync.valueOrNull ?? const [];
                      final allApps = combineAppData(
                        usage: usage,
                        restrictions: restrictions,
                        installedApps: installed,
                      );

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.lg,
                          AppDimensions.md,
                          AppDimensions.lg,
                          AppDimensions.lg,
                        ),
                        children: [
                          // Bugungi jami + haftalik grafik (reuse).
                          ScreenTimeChart(childId: _childId),
                          const SizedBox(height: AppDimensions.lg),
                          if (allApps.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.xl,
                              ),
                              child: Text(
                                'appRestrictions.emptyAll'.tr(
                                  namedArgs: {'name': childName},
                                ),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyS.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            )
                          else
                            for (final app in allApps)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimensions.sm,
                                ),
                                child: AppCombinedTile(
                                  app: app,
                                  onTap: () => _showLimitSheet(app),
                                  onLongPress: () => _showQuickActions(app),
                                ),
                              ),
                        ],
                      );
                    },
                    loading: _loading,
                    error: (e, _) => _errorBox(e),
                  ),
                  loading: _loading,
                  error: (e, _) => _errorBox(e),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading() => ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => const AppTileSkeleton(),
      );

  Widget _errorBox(Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            'appRestrictions.errorPrefix'.tr(
              namedArgs: {'error': '$e'},
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );

  void _showLimitSheet(AppCombined app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      isScrollControlled: true,
      builder: (_) => _LimitBottomSheet(
        app: app,
        childId: widget.childId,
      ),
    );
  }

  /// Long-press → Quick Actions menu: "Hozir bloklash 15 daq",
  /// "Limit qo'yish" (LimitSheet'ga uzatadi), "Cheklovni olib
  /// tashlash" (faqat hasLimit). WhatsApp pattern.
  void _showQuickActions(AppCombined app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => _QuickActionsSheet(
        app: app,
        childId: widget.childId,
        onLimit: () {
          Navigator.of(context).pop();
          _showLimitSheet(app);
        },
      ),
    );
  }
}

/// "Faollik" header — ← + markazda sarlavha.
class _FaollikHeader extends StatelessWidget {
  const _FaollikHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Bola tanlash chiplari (gorizontal) — tanlangani lime.
class _ChildChips extends StatelessWidget {
  const _ChildChips({
    required this.children,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Child> children;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.sm),
        itemBuilder: (context, i) {
          final c = children[i];
          final selected = c.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(c.id),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                c.name,
                style: AppTextStyles.bodyS.copyWith(
                  color:
                      selected ? AppColors.background : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Limit bottom sheet — ChoiceChip (15/30/60/120/180 daq) + Block
/// switch + Saqlash + (mavjud bo'lsa) Cheklovni olib tashlash.
class _LimitBottomSheet extends ConsumerStatefulWidget {
  const _LimitBottomSheet({required this.app, required this.childId});

  final AppCombined app;
  final String childId;

  @override
  ConsumerState<_LimitBottomSheet> createState() =>
      _LimitBottomSheetState();
}

class _LimitBottomSheetState
    extends ConsumerState<_LimitBottomSheet> {
  /// ChoiceChip variantlari — locale'ga bog'liq, har build'da olinadi.
  List<({String label, int minutes})> _buildOptions() => [
        (label: 'appRestrictions.limitSheet.chip15'.tr(), minutes: 15),
        (label: 'appRestrictions.limitSheet.chip30'.tr(), minutes: 30),
        (label: 'appRestrictions.limitSheet.chip60'.tr(), minutes: 60),
        (label: 'appRestrictions.limitSheet.chip120'.tr(), minutes: 120),
        (label: 'appRestrictions.limitSheet.chip180'.tr(), minutes: 180),
      ];

  late int _selectedMinutes;
  late bool _isBlocked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.app.restriction?.limitMinutes ?? 60;
    _isBlocked = widget.app.isBlocked;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(appRestrictionRepositoryProvider);
    try {
      if (_isBlocked) {
        await repo.blockApp(
          childId: widget.childId,
          packageName: widget.app.packageName,
          appName: widget.app.appName,
        );
      } else if (_selectedMinutes > 0) {
        await repo.setLimit(
          childId: widget.childId,
          packageName: widget.app.packageName,
          appName: widget.app.appName,
          limitMinutes: _selectedMinutes,
        );
      } else {
        await repo.removeLimit(
          childId: widget.childId,
          packageName: widget.app.packageName,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'appRestrictions.limitSheet.saveErrorPrefix'.tr(
              namedArgs: {'error': '$e'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _removeLimit() async {
    setState(() => _saving = true);
    try {
      await ref.read(appRestrictionRepositoryProvider).removeLimit(
            childId: widget.childId,
            packageName: widget.app.packageName,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'appRestrictions.limitSheet.removeErrorPrefix'.tr(
              namedArgs: {'error': '$e'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.lg,
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
              widget.app.appName.isEmpty
                  ? widget.app.packageName
                  : widget.app.appName,
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'appRestrictions.limitSheet.todayUsage'.tr(
                namedArgs: {'usage': widget.app.usageFormatted},
              ),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'appRestrictions.limitSheet.timeLimit'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.sm + 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final opt in _buildOptions())
                  ChoiceChip(
                    label: Text(opt.label),
                    selected:
                        !_isBlocked && _selectedMinutes == opt.minutes,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() {
                              _selectedMinutes = opt.minutes;
                              _isBlocked = false;
                            }),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceVariant,
                    labelStyle: AppTextStyles.bodyS.copyWith(
                      color: !_isBlocked &&
                              _selectedMinutes == opt.minutes
                          ? AppColors.background
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SwitchListTile(
              value: _isBlocked,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _isBlocked = v),
              title: Text(
                'appRestrictions.limitSheet.blockTitle'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'appRestrictions.limitSheet.blockSubtitle'.tr(),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.error,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.border,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                ),
                child: Text(
                  _saving
                      ? 'appRestrictions.limitSheet.savingButton'.tr()
                      : 'appRestrictions.limitSheet.saveButton'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (widget.app.hasLimit) ...[
              const SizedBox(height: AppDimensions.sm),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _removeLimit,
                  child: Text(
                    'appRestrictions.limitSheet.removeButton'.tr(),
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Long-press menu — WhatsApp uslubidagi tezkor harakatlar.
/// 3 ta tile: "Hozir bloklash 15 daq", "Limit qo'yish", (faqat
/// hasLimit) "Cheklovni olib tashlash".
class _QuickActionsSheet extends ConsumerWidget {
  const _QuickActionsSheet({
    required this.app,
    required this.childId,
    required this.onLimit,
  });

  final AppCombined app;
  final String childId;
  final VoidCallback onLimit;

  Future<void> _block15(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    try {
      await ref.read(appRestrictionRepositoryProvider).blockApp(
            childId: childId,
            packageName: app.packageName,
            appName: app.appName,
            durationMinutes: 15,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'appRestrictions.quickActions.errorPrefix'.tr(
              namedArgs: {'error': '$e'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    try {
      await ref.read(appRestrictionRepositoryProvider).removeLimit(
            childId: childId,
            packageName: app.packageName,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'appRestrictions.quickActions.errorPrefix'.tr(
              namedArgs: {'error': '$e'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.sm + 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                0,
                AppDimensions.lg,
                AppDimensions.md,
              ),
              child: Text(
                app.appName.isEmpty ? app.packageName : app.appName,
                style: AppTextStyles.headlineL.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.block,
                color: AppColors.error,
              ),
              title: Text(
                'appRestrictions.quickActions.block15'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => _block15(context, ref),
            ),
            ListTile(
              leading: const Icon(
                Icons.timer,
                color: AppColors.primary,
              ),
              title: Text(
                'appRestrictions.quickActions.setLimit'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: onLimit,
            ),
            if (app.hasLimit)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  'appRestrictions.quickActions.removeRestriction'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () => _remove(context, ref),
              ),
            const SizedBox(height: AppDimensions.sm),
          ],
        ),
      ),
    );
  }
}
