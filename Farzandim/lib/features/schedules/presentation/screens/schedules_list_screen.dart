import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bola jadvallari ekran (per-child).
///
/// **UI:**
/// - Yuqorida day picker (7 ta chip — Du-Ya), bugungi kun default
///   tanlangan, lime green
/// - Tanlangan kunda boshlanadigan yozuvlar timeline tarzida
///   (Stream Firestore'dan)
/// - Pastdagi FAB → bottom sheet (yangi/tahrirlash)
/// - Karta tap → tahrirlash sheet'i
/// - Switch — `isActive` toggle (Cloud Function reminder uchun)
class SchedulesListScreen extends ConsumerStatefulWidget {
  /// `SchedulesListScreen` konstruktor.
  const SchedulesListScreen({required this.childId, super.key});

  /// Qaysi bola uchun jadvallar.
  final String childId;

  @override
  ConsumerState<SchedulesListScreen> createState() =>
      _SchedulesListScreenState();
}

class _SchedulesListScreenState
    extends ConsumerState<SchedulesListScreen> {
  late int _selectedDayIso; // 1=Du ... 7=Ya

  @override
  void initState() {
    super.initState();
    _selectedDayIso = DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync =
        ref.watch(schedulesProvider(widget.childId));
    final selectedWeekday = weekdayFromIso(_selectedDayIso);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              _DayPicker(
                selectedIso: _selectedDayIso,
                onChanged: (d) => setState(() => _selectedDayIso = d),
              ),
              const SizedBox(height: AppDimensions.md),
              Expanded(
                child: schedulesAsync.when(
                  data: (all) {
                    final dayEntries = all
                        .where(
                          (s) => s.weekdays.contains(selectedWeekday),
                        )
                        .toList()
                      ..sort(
                        (a, b) =>
                            a.startMinutes.compareTo(b.startMinutes),
                      );

                    if (dayEntries.isEmpty) return const _EmptyDay();
                    return _Timeline(
                      entries: dayEntries,
                      onEdit: _onEdit,
                    );
                  },
                  // Skeleton: schedule card list (default height 88)
                  loading: () => const SkeletonList(
                    itemCount: 4,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.lg),
                      child: Text(
                        'schedules.errorPrefix'.tr(
                          namedArgs: {'error': '$e'},
                        ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add),
        label: Text(
          'schedules.newFab'.tr(),
          style: AppTextStyles.bodyM.copyWith(
            color: AppColors.background,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _onAdd() => _openSheet(null);
  Future<void> _onEdit(Schedule entry) => _openSheet(entry);

  Future<void> _openSheet(Schedule? entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleEditSheet(
        childId: widget.childId,
        entry: entry,
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
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'schedules.headerTitle'.tr(),
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

// ════════════════════════ DAY PICKER ════════════════════════

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.selectedIso, required this.onChanged});

  final int selectedIso;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: Row(
        children: [
          for (final w in Weekday.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DayChip(
                  label: w.label,
                  isSelected: w.iso == selectedIso,
                  onTap: () => onChanged(w.iso),
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
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyS.copyWith(
                color: isSelected
                    ? AppColors.background
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ TIMELINE / EMPTY ════════════════════════

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'schedules.empty.title'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'schedules.empty.subtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, required this.onEdit});

  final List<Schedule> entries;
  final void Function(Schedule) onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        0,
        AppDimensions.lg,
        96, // FAB ostidan ko'rinishi uchun
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _EntryCard(
        entry: entries[i],
        onTap: () => onEdit(entries[i]),
      )
          // Stagger: har timeline entry 50ms kechikish bilan
          .animate()
          .fadeIn(
            duration: 300.ms,
            delay: (50 * i).ms,
          )
          .slideY(
            begin: 0.1,
            end: 0,
            duration: 300.ms,
            delay: (50 * i).ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final Schedule entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = entry.type.color;
    final borderRadius = BorderRadius.circular(AppDimensions.radiusM);
    return Material(
      color: AppColors.surface,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Vaqt + vertikal chiziq.
                SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      Text(
                        entry.startTimeFormatted,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          margin:
                              const EdgeInsets.symmetric(vertical: 4),
                          color: AppColors.border,
                        ),
                      ),
                      Text(
                        entry.endTimeFormatted,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(entry.type.icon, color: color, size: 22),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title.isEmpty
                            ? entry.type.label
                            : entry.title,
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w700,
                          color: entry.isActive
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.weekdaysFormatted,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (entry.reminderMinutes > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.reminderMinutes} daqiqa oldin',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: entry.isActive,
                  onChanged: (v) async {
                    await ref
                        .read(scheduleActionsProvider.notifier)
                        .toggleActive(
                          childId: entry.childId,
                          scheduleId: entry.id,
                          current: entry,
                          isActive: v,
                        );
                  },
                  activeThumbColor: AppColors.background,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ EDIT SHEET ════════════════════════

class _ScheduleEditSheet extends ConsumerStatefulWidget {
  const _ScheduleEditSheet({required this.childId, this.entry});

  final String childId;
  final Schedule? entry;

  @override
  ConsumerState<_ScheduleEditSheet> createState() =>
      _ScheduleEditSheetState();
}

class _ScheduleEditSheetState
    extends ConsumerState<_ScheduleEditSheet> {
  late TextEditingController _titleController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Set<Weekday> _selectedWeekdays;
  late ScheduleType _type;
  late int _reminderMinutes;
  late bool _isActive;
  bool _saving = false;

  /// Reminder uchun ruxsat etilgan qiymatlar.
  static const _reminderOptions = [0, 5, 10, 15, 30];

  bool get _isEditMode => widget.entry != null;

  bool get _isFormValid =>
      _titleController.text.trim().isNotEmpty &&
      _selectedWeekdays.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleController = TextEditingController(
      text: e?.title ?? ScheduleType.school.label,
    );
    _startTime = e?.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = e?.endTime ?? const TimeOfDay(hour: 10, minute: 0);
    _selectedWeekdays = e?.weekdays.toSet() ??
        {weekdayFromIso(DateTime.now().weekday)};
    _type = e?.type ?? ScheduleType.school;
    _reminderMinutes = e?.reminderMinutes ?? 10;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusL),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle.
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.md,
                AppDimensions.lg,
                AppDimensions.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditMode
                          ? 'schedules.edit.titleEdit'.tr()
                          : 'schedules.edit.titleAdd'.tr(),
                      style: AppTextStyles.headlineL.copyWith(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (_isEditMode)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      onPressed: _saving ? null : _onDelete,
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('schedules.edit.typeLabel'.tr()),
                    const SizedBox(height: AppDimensions.sm),
                    _TypeSelector(
                      selected: _type,
                      onChanged: (t) => setState(() {
                        _type = t;
                        // Default sarlavha — foydalanuvchi yozmagan
                        // bo'lsa type label avtomatik to'ldiriladi.
                        // 'custom' tanlansa bo'sh qoldirib, foydalanuvchi
                        // o'z matnini kiritsin.
                        if (t != ScheduleType.custom &&
                            (_titleController.text.trim().isEmpty ||
                                ScheduleType.values.any(
                                  (st) => st.label == _titleController
                                      .text.trim(),
                                ))) {
                          _titleController.text = t.label;
                        }
                      }),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _Label('schedules.edit.titleFieldLabel'.tr()),
                    const SizedBox(height: AppDimensions.sm),
                    CustomTextField(
                      controller: _titleController,
                      hint: 'schedules.edit.titleFieldHint'.tr(),
                      maxLength: 40,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _Label('schedules.edit.timeLabel'.tr()),
                    const SizedBox(height: AppDimensions.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'schedules.edit.startLabel'.tr(),
                            time: _startTime,
                            onTap: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            label: 'schedules.edit.endLabel'.tr(),
                            time: _endTime,
                            onTap: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _Label('schedules.edit.weekdaysLabel'.tr()),
                    const SizedBox(height: AppDimensions.sm),
                    _ShortcutDays(
                      selected: _selectedWeekdays,
                      onSelectAll: () => setState(() {
                        _selectedWeekdays = Weekday.values.toSet();
                      }),
                      onSelectWeekdays: () => setState(() {
                        _selectedWeekdays = const {
                          Weekday.monday,
                          Weekday.tuesday,
                          Weekday.wednesday,
                          Weekday.thursday,
                          Weekday.friday,
                        };
                      }),
                      onSelectWeekend: () => setState(() {
                        _selectedWeekdays = const {
                          Weekday.saturday,
                          Weekday.sunday,
                        };
                      }),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    _DaysSelector(
                      selected: _selectedWeekdays,
                      onToggle: (w) => setState(() {
                        if (_selectedWeekdays.contains(w)) {
                          _selectedWeekdays.remove(w);
                        } else {
                          _selectedWeekdays.add(w);
                        }
                      }),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _Label('schedules.edit.reminderLabel'.tr()),
                    const SizedBox(height: AppDimensions.sm),
                    _ReminderSelector(
                      selected: _reminderMinutes,
                      options: _reminderOptions,
                      onChanged: (m) =>
                          setState(() => _reminderMinutes = m),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _ActiveToggle(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: AppDimensions.xl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.sm,
                AppDimensions.lg,
                AppDimensions.lg,
              ),
              child: PrimaryButton(
                label: _saving
                    ? 'schedules.edit.savingButton'.tr()
                    : (_isEditMode
                        ? 'schedules.edit.updateButton'.tr()
                        : 'schedules.edit.saveButton'.tr()),
                icon: Icons.check,
                onPressed:
                    (_isFormValid && !_saving) ? _onSave : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    final notifier = ref.read(scheduleActionsProvider.notifier);
    final daysList = _selectedWeekdays.toList()
      ..sort((a, b) => a.iso.compareTo(b.iso));
    final title = _titleController.text.trim();

    final result = _isEditMode
        ? await notifier.updateSchedule(
            childId: widget.childId,
            scheduleId: widget.entry!.id,
            current: widget.entry!,
            title: title,
            type: _type,
            weekdays: daysList,
            startHour: _startTime.hour,
            startMinute: _startTime.minute,
            endHour: _endTime.hour,
            endMinute: _endTime.minute,
            reminderMinutes: _reminderMinutes,
            isActive: _isActive,
          )
        : await notifier.addSchedule(
            childId: widget.childId,
            title: title,
            type: _type,
            weekdays: daysList,
            startHour: _startTime.hour,
            startMinute: _startTime.minute,
            endHour: _endTime.hour,
            endMinute: _endTime.minute,
            reminderMinutes: _reminderMinutes,
            isActive: _isActive,
          );

    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'schedules.edit.saveErrorPrefix'.tr(
              namedArgs: {'error': '${result.error}'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onDelete() async {
    setState(() => _saving = true);
    final result = await ref
        .read(scheduleActionsProvider.notifier)
        .deleteSchedule(
          childId: widget.childId,
          scheduleId: widget.entry!.id,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'schedules.edit.deleteErrorPrefix'.tr(
              namedArgs: {'error': '${result.error}'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ════════════════════════ FORM HELPERS ════════════════════════

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final borderRadius =
        BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              Text(
                label,
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                formatted,
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutDays extends StatelessWidget {
  const _ShortcutDays({
    required this.selected,
    required this.onSelectAll,
    required this.onSelectWeekdays,
    required this.onSelectWeekend,
  });

  final Set<Weekday> selected;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectWeekdays;
  final VoidCallback onSelectWeekend;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _ShortcutChip(
          label: 'schedules.edit.shortcutAll'.tr(),
          onTap: onSelectAll,
        ),
        _ShortcutChip(
          label: 'schedules.edit.shortcutWeekdays'.tr(),
          onTap: onSelectWeekdays,
        ),
        _ShortcutChip(
          label: 'schedules.edit.shortcutWeekend'.tr(),
          onTap: onSelectWeekend,
        ),
      ],
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _DaysSelector extends StatelessWidget {
  const _DaysSelector({required this.selected, required this.onToggle});

  final Set<Weekday> selected;
  final ValueChanged<Weekday> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final w in Weekday.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _DayChip(
                label: w.label,
                isSelected: selected.contains(w),
                onTap: () => onToggle(w),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final ScheduleType selected;
  final ValueChanged<ScheduleType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in ScheduleType.values)
          _TypeChip(
            type: t,
            isSelected: t == selected,
            onTap: () => onChanged(t),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final ScheduleType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    final bgColor = isSelected ? color : AppColors.surfaceVariant;
    final fgColor =
        isSelected ? AppColors.background : AppColors.textPrimary;
    final borderRadius =
        BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: bgColor,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: AppTextStyles.bodyS.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderSelector extends StatelessWidget {
  const _ReminderSelector({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final int selected;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final m in options)
          _ReminderChip(
            minutes: m,
            isSelected: m == selected,
            onTap: () => onChanged(m),
          ),
      ],
    );
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = minutes == 0
        ? 'schedules.edit.reminderOff'.tr()
        : 'schedules.edit.reminderMinutes'.tr(
            namedArgs: {'minutes': '$minutes'},
          );
    final borderRadius =
        BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyS.copyWith(
              color: isSelected
                  ? AppColors.background
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  const _ActiveToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            value
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: value ? AppColors.primary : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'schedules.edit.activeTitle'.tr(),
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'schedules.edit.activeSubtitle'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.background,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.border,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
