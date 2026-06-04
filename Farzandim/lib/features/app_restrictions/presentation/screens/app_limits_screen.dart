// ─────────────────────────────────────────────────────────────────────
// AppLimitsScreen — "Qurilma cheklovlari" (Figma 1:1, dinamik)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard "Qurilma cheklovlari" tugmasidan ochiladi. Ikkita tab:
//   - "Hammasi"        — bola ishlatgan barcha ilovalar
//   - "Cheklov bo'yicha" — faqat limit yoki blok qo'yilgan ilovalar
// Ilova ustiga bosilsa — modal: bloklash / limit belgilash / cheksiz.
//
// Ma'lumot mavjud provayderlardan (combineAppData): usage + restrictions +
// installed apps. Hech qanday dublikat backend mantiq yo'q.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_combined.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/tab_switcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> {
  late String _childId;
  int _tab = 0; // 0 = Hammasi, 1 = Cheklov bo'yicha

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'appLimits.title'.tr()),
              if (children.length > 1)
                _ChildChips(
                  childIds: children.map((c) => c.id).toList(),
                  selectedId: _childId,
                  onSelect: (id) => setState(() => _childId = id),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg,
                  AppDimensions.sm,
                  AppDimensions.lg,
                  AppDimensions.sm,
                ),
                child: TabSwitcher(
                  tabs: [
                    'appLimits.tabAll'.tr(),
                    'appLimits.tabLimited'.tr(),
                  ],
                  activeIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: usageAsync.when(
                  data: (usage) => restrictionsAsync.when(
                    data: (restrictions) {
                      final installed = installedAsync.valueOrNull ?? const [];
                      var apps = combineAppData(
                        usage: usage,
                        restrictions: restrictions,
                        installedApps: installed,
                      );
                      // "Cheklov bo'yicha" — faqat limit/blok qo'yilganlar.
                      if (_tab == 1) {
                        apps = apps
                            .where((a) => a.hasLimit || a.isBlocked)
                            .toList();
                      }
                      return _AppList(apps: apps, childId: _childId);
                    },
                    loading: _loading,
                    error: _error,
                  ),
                  loading: _loading,
                  error: _error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading() => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );

  Widget _error(Object e, StackTrace _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            '$e',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
}

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
            icon: const Icon(
              Icons.arrow_back_rounded,
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
              ),
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
                          ? AppColors.background
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
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.xl,
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
          child: Column(
            children: [
              for (var i = 0; i < apps.length; i++) ...[
                _AppRow(
                  app: apps[i],
                  onTap: () => _openModal(context, apps[i]),
                ),
                if (i != apps.length - 1)
                  const Divider(
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
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.block_rounded, size: 18, color: AppColors.error),
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
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ],
      );
    }
    // Limit yo'q — bosib qo'yish mumkinligini bildiruvchi xira ikonka.
    return const Icon(
      Icons.hourglass_empty_rounded,
      size: 18,
      color: AppColors.textTertiary,
    );
  }
}

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
                  Switch.adaptive(
                    value: _mode == _LimitMode.block,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.error,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _mode =
                            v ? _LimitMode.block : _LimitMode.unlimited),
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
                  const Icon(
                    Icons.hourglass_empty_rounded,
                    color: AppColors.primary,
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
                      foregroundColor: AppColors.primary,
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
                  const Icon(
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
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
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
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
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
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
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
          await facade.removeLimit(
            childId: widget.childId,
            packageName: pkg,
          );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('appLimits.saved'.tr()),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.surfaceVariant,
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('appLimits.saveError'.tr()),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.surfaceVariant,
            ),
          );
      }
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m daq';
    if (m == 0) return '$h soat';
    return '$h st $m daq';
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
