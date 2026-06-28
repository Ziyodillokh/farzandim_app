// ─────────────────────────────────────────────────────────────────────
// SchedulesListScreen — "Jadval" (Figma 1:1, dinamik)
// ─────────────────────────────────────────────────────────────────────
//
// Ikkita yig'iladigan karta: "Uyqu vaqtida bloklash" (SLEEP) va "Dars vaqti"
// (SCHOOL). Har kartada master toggle: YOQILGAN bo'lsa 3 qator ochiladi:
//   - "Bugun"            → vaqt oraliqi (bosilsa tahrirlanadi)
//   - "Haftalik jadval"  → qaysi kunlar (bosilsa tahrirlanadi)
//   - "Ilova cheklovlar" → oyna ichida bloklanadigan ilovalar (picker)
// O'CHIRILGAN bo'lsa karta yig'iladi (faqat sarlavha + toggle).
//
// Ma'lumot mavjud Routine model + schedulesProvider/scheduleActionsProvider
// (Backend CRUD) bilan — dublikat kod yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_usage.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

class SchedulesListScreen extends ConsumerWidget {
  const SchedulesListScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider(childId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: schedulesAsync.when(
                  data: (all) => ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.lg,
                      AppDimensions.sm,
                      AppDimensions.lg,
                      AppDimensions.xl,
                    ),
                    children: [
                      _ScheduleCard(
                        childId: childId,
                        type: ScheduleType.sleep,
                        title: 'schedules.sleepBlockTitle'.tr(),
                        schedule: all.firstWhereOrNull(
                          (s) => s.type == ScheduleType.sleep,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      _ScheduleCard(
                        childId: childId,
                        type: ScheduleType.school,
                        title: 'schedules.schoolTimeTitle'.tr(),
                        schedule: all.firstWhereOrNull(
                          (s) => s.type == ScheduleType.school,
                        ),
                      ),
                    ],
                  ),
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        friendlyError(e),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm,
        AppDimensions.sm,
        AppDimensions.sm,
        AppDimensions.md,
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
              'schedules.singleTitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ════════════════════════ SCHEDULE CARD ════════════════════════

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({
    required this.childId,
    required this.type,
    required this.title,
    required this.schedule,
  });

  final String childId;
  final ScheduleType type;
  final String title;
  final Schedule? schedule;

  bool get _isOn => schedule != null && schedule!.isActive;

  // Yangi yaratiladigan jadval uchun aqlli default'lar.
  ({int sh, int sm, int eh, int em, List<Weekday> days}) get _defaults {
    if (type == ScheduleType.sleep) {
      return (sh: 22, sm: 0, eh: 7, em: 0, days: Weekday.values);
    }
    return (
      sh: 8,
      sm: 0,
      eh: 14,
      em: 0,
      days: const [
        Weekday.monday,
        Weekday.tuesday,
        Weekday.wednesday,
        Weekday.thursday,
        Weekday.friday,
      ],
    );
  }

  /// Backend'ga PERSIST qilinadigan KANONIK uz title (review topilmasi):
  /// lokalizatsiyalangan `title` yozilsa ru/en user yaratgan jadval
  /// tarjima holida saqlanib, boshqa iste'molchilar (Child App, admin)
  /// aralash-tilli data olardi. UI'da baribir `title` (.tr) ko'rsatiladi.
  String get _backendTitle =>
      type == ScheduleType.sleep ? 'Uyqu vaqtida bloklash' : 'Dars vaqti';

  Future<void> _onToggle(WidgetRef ref, bool value) async {
    final actions = ref.read(scheduleActionsProvider.notifier);
    final current = schedule;
    if (value) {
      if (current == null) {
        final d = _defaults;
        await actions.addSchedule(
          childId: childId,
          title: _backendTitle,
          type: type,
          weekdays: d.days,
          startHour: d.sh,
          startMinute: d.sm,
          endHour: d.eh,
          endMinute: d.em,
          reminderMinutes: 0,
        );
      } else {
        await actions.toggleActive(
          childId: childId,
          scheduleId: current.id,
          current: current,
          isActive: true,
        );
      }
    } else if (current != null) {
      await actions.toggleActive(
        childId: childId,
        scheduleId: current.id,
        current: current,
        isActive: false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = type.color;
    return SettingsCard(
      accent: accent,
      child: Column(
        children: [
          // ─── Sarlavha + toggle ───
          Row(
            children: [
              SettingsIconChip(icon: type.icon, accent: accent, size: 40),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppSwitch(
                value: _isOn,
                activeColor: AppColors.success,
                onChanged: (v) => _onToggle(ref, v),
              ),
            ],
          ),

          // ─── Yoqilgan bo'lsa: 3 qator ───
          if (_isOn && schedule != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Divider(height: 1, color: AppColors.divider),
            _SubRow(
              label: 'schedules.todayLabel'.tr(),
              value: schedule!.timeRangeFormatted,
              onTap: () => _editTime(context, ref, schedule!),
            ),
            Divider(height: 1, color: AppColors.divider),
            _SubRow(
              label: 'schedules.weeklySchedule'.tr(),
              value: schedule!.weekdaysFormatted,
              onTap: () => _editDays(context, ref, schedule!),
            ),
            Divider(height: 1, color: AppColors.divider),
            _SubRow(
              label: 'schedules.appRestrictionsLabel'.tr(),
              trailing: _AppsTrailing(
                childId: childId,
                packages: schedule!.blockedApps,
              ),
              onTap: () => _editApps(context, ref, schedule!),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Vaqt oraliqi tahrirlash ───
  Future<void> _editTime(
    BuildContext context,
    WidgetRef ref,
    Schedule s,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: s.startTime,
      helpText: 'schedules.startTimeHelp'.tr(),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: s.endTime,
      helpText: 'schedules.endTimeHelp'.tr(),
    );
    if (end == null) return;
    await ref
        .read(scheduleActionsProvider.notifier)
        .updateSchedule(
          childId: childId,
          scheduleId: s.id,
          current: s,
          startHour: start.hour,
          startMinute: start.minute,
          endHour: end.hour,
          endMinute: end.minute,
        );
  }

  // ─── Hafta kunlari tahrirlash ───
  Future<void> _editDays(
    BuildContext context,
    WidgetRef ref,
    Schedule s,
  ) async {
    final result = await showModalBottomSheet<List<Weekday>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => _DaysSheet(initial: s.weekdays),
    );
    if (result == null || result.isEmpty) return;
    await ref
        .read(scheduleActionsProvider.notifier)
        .updateSchedule(
          childId: childId,
          scheduleId: s.id,
          current: s,
          weekdays: result,
        );
  }

  // ─── Ilova cheklovlar (picker) ───
  Future<void> _editApps(
    BuildContext context,
    WidgetRef ref,
    Schedule s,
  ) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => _AppPickerSheet(childId: childId, initial: s.blockedApps),
    );
    if (result == null) return;
    await ref
        .read(scheduleActionsProvider.notifier)
        .updateSchedule(
          childId: childId,
          scheduleId: s.id,
          current: s,
          blockedApps: result,
        );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.label,
    required this.onTap,
    this.value,
    this.trailing,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (trailing != null) trailing!,
            const SizedBox(width: 6),
            Icon(
              SolarIconsBold.altArrowRight,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ilova cheklovlar" o'ng tomoni — tanlangan ikonalar yoki "Kiritilmagan".
class _AppsTrailing extends ConsumerWidget {
  const _AppsTrailing({required this.childId, required this.packages});

  final String childId;
  final List<String> packages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packages.isEmpty) {
      return Text(
        'schedules.notSet'.tr(),
        style: AppTextStyles.bodyM.copyWith(color: AppColors.textTertiary),
      );
    }
    final installed =
        ref.watch(installedAppsProvider(childId)).valueOrNull ?? const [];
    final byPkg = {for (final a in installed) a.packageName: a};
    final shown = packages.take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
            child: AppIconWidget(
              packageName: shown[i],
              iconUrl: byPkg[shown[i]]?.iconUrl,
              size: 26,
            ),
          ),
        if (packages.length > 3)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+${packages.length - 3}',
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════ DAYS SHEET ════════════════════════

class _DaysSheet extends StatefulWidget {
  const _DaysSheet({required this.initial});

  final List<Weekday> initial;

  @override
  State<_DaysSheet> createState() => _DaysSheetState();
}

class _DaysSheetState extends State<_DaysSheet> {
  late final Set<Weekday> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'schedules.weeklySchedule'.tr(),
            style: AppTextStyles.headlineL.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in Weekday.values)
                _DayChip(
                  label: w.label,
                  selected: _selected.contains(w),
                  onTap: () => setState(() {
                    if (_selected.contains(w)) {
                      _selected.remove(w);
                    } else {
                      _selected.add(w);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      final list = _selected.toList()
                        ..sort((a, b) => a.iso.compareTo(b.iso));
                      Navigator.of(context).pop(list);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
              child: Text(
                'common.save'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyS.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ APP PICKER SHEET ════════════════════════

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
                      'Ilova cheklovlar',
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
