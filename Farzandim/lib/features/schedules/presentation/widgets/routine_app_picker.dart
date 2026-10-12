// ─────────────────────────────────────────────────────────────────────
// RoutineAppPicker — rejim (routine) UCHUN ilovalarni tanlash varag'i
// ─────────────────────────────────────────────────────────────────────
//
// Global "Ilovalarni bloklash" varag'idan FARQI: u har doim ishlaydigan
// (24/7) limit yozadi, bu esa tanlangan ilovalarni FAQAT shu rejimning vaqt
// oynasida bloklash uchun `Schedule.blockedApps` ro'yxatini qaytaradi
// (saqlashni chaqiruvchi qiladi: `scheduleActionsProvider.updateSchedule`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rejim uchun ilovalar tanlagichini ochadi va tanlangan paket nomlarini
/// qaytaradi. "Saqlash" bosilmasdan yopilsa `null` (o'zgarish yo'q).
Future<List<String>?> showRoutineAppPicker(
  BuildContext context, {
  required String childId,
  required List<String> initial,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusL),
      ),
    ),
    builder: (_) => _AppPickerSheet(childId: childId, initial: initial),
  );
}

class _AppPickerSheet extends ConsumerStatefulWidget {
  const _AppPickerSheet({required this.childId, required this.initial});

  final String childId;
  final List<String> initial;

  @override
  ConsumerState<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends ConsumerState<_AppPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final installedAsync = ref.watch(installedAppsProvider(widget.childId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppDimensions.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'schedules.appRestrictionsLabel'.tr(),
                      style: AppTextStyles.headlineL.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    child: Text(
                      'common.save'.tr(),
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: installedAsync.when(
                data: (apps) {
                  final list = apps.where((a) => a.appName.isNotEmpty).toList()
                    ..sort((a, b) => a.appName.compareTo(b.appName));
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.xl),
                        child: Text(
                          'schedules.appsNotLoaded'.tr(),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (_, i) => _AppPickRow(
                      app: list[i],
                      selected: _selected.contains(list[i].packageName),
                      onChanged: (sel) => setState(() {
                        if (sel) {
                          _selected.add(list[i].packageName);
                        } else {
                          _selected.remove(list[i].packageName);
                        }
                      }),
                    ),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text(
                    friendlyError(e),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppPickRow extends StatelessWidget {
  const _AppPickRow({
    required this.app,
    required this.selected,
    required this.onChanged,
  });

  final AppUsageEntry app;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: AppDimensions.sm,
        ),
        child: Row(
          children: [
            AppIconWidget(
              packageName: app.packageName,
              iconUrl: app.iconUrl,
              size: 40,
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                app.appName,
                style: AppTextStyles.bodyM,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Checkbox(
              value: selected,
              activeColor: AppColors.primary,
              checkColor: AppColors.onPrimary,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
