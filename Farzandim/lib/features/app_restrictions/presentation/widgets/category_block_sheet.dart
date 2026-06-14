// ─────────────────────────────────────────────────────────────────────
// CategoryBlockSheet — kategoriya bo'yicha bloklash (#14)
// ─────────────────────────────────────────────────────────────────────
//
// Ota-ona butun kategoriyani (Ijtimoiy tarmoqlar / O'yinlar / Video / Ta'lim
// / Boshqa) bir tugma bilan bloklaydi yoki ochadi. Backend o'sha kategoriyadagi
// barcha o'rnatilgan ilovalarni dinamik blok sifatida bolaga uzatadi.

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryBlockSheet extends ConsumerStatefulWidget {
  const CategoryBlockSheet({required this.childId, super.key});

  final String childId;

  static Future<void> show(BuildContext context, String childId) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => CategoryBlockSheet(childId: childId),
    );
  }

  @override
  ConsumerState<CategoryBlockSheet> createState() => _CategoryBlockSheetState();
}

class _CategoryBlockSheetState extends ConsumerState<CategoryBlockSheet> {
  List<AppCategoryInfo>? _categories;
  String? _error;
  // Hozir yangilanayotgan kategoriya (switch'ni bloklash uchun).
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cats = await ref
          .read(backendAppLimitRepositoryProvider)
          .getCategories(widget.childId);
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _toggle(AppCategoryInfo cat, bool block) async {
    setState(() => _busy.add(cat.category));
    try {
      final updated = await ref
          .read(backendAppLimitRepositoryProvider)
          .toggleCategory(
            childId: widget.childId,
            category: cat.category,
            block: block,
          );
      if (mounted) setState(() => _categories = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(cat.category));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.md,
          AppDimensions.lg,
          AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              "Kategoriya bo'yicha bloklash",
              style: AppTextStyles.headlineL.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'Butun turkumdagi ilovalarni bir tugma bilan bloklang. '
              "Yangi o'rnatilgan ilovalar ham avtomatik qamrab olinadi.",
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _error!,
          style: AppTextStyles.bodyS.copyWith(color: AppColors.error),
        ),
      );
    }
    final cats = _categories;
    if (cats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        for (final c in cats)
          _CategoryRow(
            info: c,
            busy: _busy.contains(c.category),
            onChanged: (v) => _toggle(c, v),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.info,
    required this.busy,
    required this.onChanged,
  });

  final AppCategoryInfo info;
  final bool busy;
  final ValueChanged<bool> onChanged;

  IconData get _icon {
    switch (info.category) {
      case 'SOCIAL':
        return Icons.groups_rounded;
      case 'GAME':
        return Icons.sports_esports_rounded;
      case 'VIDEO':
        return Icons.play_circle_fill_rounded;
      case 'EDU':
        return Icons.school_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = info.blocked ? AppColors.error : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.appCount} ta ilova',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            AppSwitch(
              value: info.blocked,
              activeColor: AppColors.error,
              onChanged: info.appCount == 0 ? null : onChanged,
            ),
        ],
      ),
    );
  }
}
