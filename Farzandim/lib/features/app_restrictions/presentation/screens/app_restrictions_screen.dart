import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_combined.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/app_limits_screen.dart'
    show AppLimitModal;
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_combined_tile.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_tile_skeleton.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/category_block_sheet.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola ilovalar foydalanish + cheklov ekrani ("Foydalanish vaqti" / "Ilova
/// cheklovlari").
///
/// Yuqorida bugungi jami + haftalik grafik (`ScreenTimeChart`), pastda
/// ilovalar foydalanish bo'yicha (`AppCombinedTile`, o'ng tomonda ">").
///
/// **Ilova ustiga bosilsa — `AppLimitModal`** (bloklash / limit belgilash /
/// cheksiz — per-app sahifa). Avval bu yerda alohida `_LimitBottomSheet` bor
/// edi; endi ilova cheklovlari uchun YAGONA `AppLimitModal` ishlatiladi (bir
/// xil per-app tajriba "Ilova cheklovlari" ekrani bilan).
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
              _FaollikHeader(
                title: 'deviceSettings.activity'.tr(),
                onCategoryTap: () =>
                    CategoryBlockSheet.show(context, _childId),
              ),
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

                      // PERF: 100-300 ilova bo'lishi mumkin — builder
                      // faqat ko'ringan tile'larni quradi (avval hammasi
                      // birdan qurilardi). Index 0 — grafik header.
                      final itemCount =
                          1 + (allApps.isEmpty ? 1 : allApps.length);
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.lg,
                          AppDimensions.md,
                          AppDimensions.lg,
                          AppDimensions.lg,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // Bugungi jami + haftalik grafik (reuse).
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                ScreenTimeChart(childId: _childId),
                                const SizedBox(height: AppDimensions.lg),
                              ],
                            );
                          }
                          if (allApps.isEmpty) {
                            return Padding(
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
                            );
                          }
                          final app = allApps[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimensions.sm,
                            ),
                            child: AppCombinedTile(
                              app: app,
                              onTap: () => _showLimitSheet(app),
                              onLongPress: app.isBlocked
                                  ? null
                                  : () => _blockNow(app),
                            ),
                          );
                        },
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

  /// Ilova ustiga bosilganda — per-app limit modali (`AppLimitModal`,
  /// "Ilova cheklovlari" ekrani bilan bir xil): bloklash / limit / cheksiz.
  void _showLimitSheet(AppCombined app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => AppLimitModal(
        app: app,
        childId: widget.childId,
      ),
    );
  }

  /// Uzun bosish → "Darhol blokla" (#15): tasdiq → block-now → bola
  /// qurilmasida ~bir necha soniyada kuchga kiradi (silent resync push).
  Future<void> _blockNow(AppCombined app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Darhol bloklash'),
        content: Text(
          '"${app.appName}" ilovasini hoziroq bloklaymizmi? '
          'Bola qurilmasida bir necha soniyada kuchga kiradi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Blokla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    String msg;
    Color bg;
    try {
      await ref.read(backendAppLimitRepositoryProvider).blockNow(
            childId: _childId,
            packageName: app.packageName,
          );
      ref.invalidate(restrictionsProvider(_childId));
      msg = '"${app.appName}" bloklandi.';
      bg = AppColors.surfaceVariant;
    } on AppLimitException catch (e) {
      msg = e.message;
      bg = AppColors.error;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
        ),
      );
  }
}

/// "Faollik" header — ← + markazda sarlavha + (o'ngda) kategoriya bloklash.
class _FaollikHeader extends StatelessWidget {
  const _FaollikHeader({required this.title, this.onCategoryTap});

  final String title;

  /// Kategoriya bo'yicha bloklash varag'ini ochadi (#14).
  final VoidCallback? onCategoryTap;

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
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
          SizedBox(
            width: 48,
            height: 48,
            child: onCategoryTap == null
                ? null
                : IconButton(
                    tooltip: 'Kategoriya bloklash',
                    icon: Icon(
                      Icons.category_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: onCategoryTap,
                  ),
          ),
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
                      selected ? AppColors.onPrimary : AppColors.textPrimary,
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
