import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bolalarni boshqarish — ro'yxat, qo'shish, tahrirlash, o'chirish.
///
/// Sozlamalar → Bolalarni boshqarish orqali ochiladi.
///
/// **List state**: bolalar kartochkalari (avatar, ism, yosh, hudud,
/// oila kodi pill, popup menu — Tahrirlash/O'chirish), pastdagi
/// FAB orqali yangi qo'shish.
/// **Empty state**: markazda hint + "Bola qo'shish" PrimaryButton.
class ChildrenManagementScreen extends ConsumerWidget {
  /// `ChildrenManagementScreen` konstruktor.
  const ChildrenManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final children = childrenAsync.valueOrNull ?? const <Child>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: childrenAsync.when(
                  data: (children) => children.isEmpty
                      ? const _EmptyState()
                      : _ChildrenList(children: children),
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  ),
                  error: (e, _) => _ErrorState(
                    error: e,
                    onRetry: () => ref.invalidate(childrenProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: children.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.addChild),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add),
              label: Text(
                'childManagement.list.addChildFab'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

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
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'childManagement.list.title'.tr(),
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

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.child_care_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'childManagement.list.emptyTitle'.tr(),
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),
            PrimaryButton(
              label: 'childManagement.list.emptyAddButton'.tr(),
              icon: Icons.add,
              expanded: false,
              onPressed: () => context.push(AppRoutes.addChild),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ LIST ════════════════════════

class _ChildrenList extends StatelessWidget {
  const _ChildrenList({required this.children});

  final List<Child> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        // FAB ostidan elementlar ko'rinishi uchun pastdan ko'p padding.
        96,
      ),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _ChildCard(child: children[index]);
      },
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.editChildPath(child.id)),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              ChildAvatar(child: child, size: 56),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      child.name,
                      style: AppTextStyles.bodyM.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'childManagement.list.ageAndRegion'.tr(
                        namedArgs: {
                          'age': '${child.age}',
                          'region': child.region,
                        },
                      ),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _ConnectionBadge(isConnected: child.isConnected),
                    const SizedBox(height: 8),
                    _FamilyCodePill(code: child.familyCode),
                  ],
                ),
              ),
              _ActionMenu(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yashil/kulrang nuqta + matn — bola qurilmasi (Child App) pairing
/// qilinganmi yo'qmi. Familiya kodi pill yonida ko'rsatiladi.
class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? AppColors.success : AppColors.textTertiary,
            shape: BoxShape.circle,
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isConnected
              ? 'childManagement.list.connected'.tr()
              : 'childManagement.list.disconnected'.tr(),
          style: AppTextStyles.bodyS.copyWith(
            fontSize: 13,
            color: isConnected
                ? AppColors.success
                : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FamilyCodePill extends StatelessWidget {
  const _FamilyCodePill({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag, size: 12, color: AppColors.onPrimary),
          const SizedBox(width: 4),
          Text(
            code,
            style: AppTextStyles.label.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends ConsumerWidget {
  const _ActionMenu({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.textPrimary,
      ),
      color: AppColors.surfaceVariant,
      onSelected: (action) async {
        switch (action) {
          case 'edit':
            await context.push(AppRoutes.editChildPath(child.id));
          case 'delete':
            await _confirmDelete(context, ref, child);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                'childManagement.list.editAction'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              Text(
                'childManagement.list.deleteAction'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Child child,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'childManagement.list.deleteDialog.title'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'childManagement.list.deleteDialog.content'.tr(
            namedArgs: {'name': child.name},
          ),
          style: AppTextStyles.bodyS.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'childManagement.list.deleteDialog.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'childManagement.list.deleteDialog.delete'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;
    final result =
        await ref.read(childActionsProvider.notifier).deleteChild(child.id);
    if (!context.mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'childManagement.list.deletedSnack'.tr(
              namedArgs: {'name': child.name},
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'childManagement.list.errorPrefix'.tr(
              namedArgs: {'error': result.error ?? ''},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

/// Firestore xato bo'lganda ko'rsatiladigan retry UI.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'childManagement.list.errorTitle'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              error.toString(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.md),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'common.retry'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
