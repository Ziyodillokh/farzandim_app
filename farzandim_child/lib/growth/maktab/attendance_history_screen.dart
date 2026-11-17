// M05 · Davomat tarixi: oy kalendari (holat rang + belgi bilan, faqat rang
// emas), tanlangan kun tafsiloti — kiosk hodisasi va maktab tasdig'i alohida.
// Skanerlanmagan kun neytral «Aniqlanmagan» — «kelmagan» degani emas.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_models.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

({GIconData icon, GHue hue, String key}) _look(DayStatus status) =>
    switch (status) {
      DayStatus.present => (
        icon: GIcons.check,
        hue: GHue.green,
        key: 'present',
      ),
      DayStatus.late => (icon: GIcons.timer, hue: GHue.gold, key: 'late'),
      DayStatus.absent => (icon: GIcons.x, hue: GHue.rose, key: 'absent'),
      DayStatus.excused => (icon: GIcons.info, hue: GHue.sky, key: 'excused'),
      DayStatus.leftEarly => (
        icon: GIcons.signOut,
        hue: GHue.orange,
        key: 'leftEarly',
      ),
      DayStatus.unknown => (
        icon: GIcons.circleDashed,
        hue: GHue.slate,
        key: 'unknown',
      ),
    };

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  DateTime? _month;
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(learningClockProvider)();
    final month = _month ?? DateTime(now.year, now.month);
    final selected = _selected ?? dateOnly(now);
    final async = ref.watch(schoolAttendanceMonthProvider(month));
    final data = async.valueOrNull;
    final canGoNext = DateTime(
      month.year,
      month.month + 1,
    ).isBefore(DateTime(now.year, now.month + 1));
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.school.history.title'.tr(),
        ),
        onRefresh: () async =>
            ref.invalidate(schoolAttendanceMonthProvider(month)),
        children: [
          Row(
            children: [
              GIconButton(
                icon: GIcons.caretLeft,
                label: 'g5.school.history.prev'.tr(),
                onPressed: () => setState(() {
                  _month = DateTime(month.year, month.month - 1);
                  _selected = null;
                }),
              ),
              Expanded(
                child: Text(
                  _monthTitle(month),
                  textAlign: TextAlign.center,
                  style: GText.h3,
                ),
              ),
              GIconButton(
                icon: GIcons.caretRight,
                label: 'g5.school.history.next'.tr(),
                onPressed: canGoNext
                    ? () => setState(() {
                        _month = DateTime(month.year, month.month + 1);
                        _selected = null;
                      })
                    : null,
              ),
            ],
          ),
          if (async.hasError && data == null)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () =>
                    ref.invalidate(schoolAttendanceMonthProvider(month)),
              ),
            )
          else
            GGlass(
              padding: const EdgeInsets.all(12),
              child: _Calendar(
                month: month,
                data: data,
                today: dateOnly(now),
                selected: selected,
                onSelect: (d) => setState(() => _selected = d),
              ),
            ),
          _DayDetail(date: selected, day: data?.dayOf(selected)),
          const _Legend(),
        ],
      ),
    );
  }

  String _monthTitle(DateTime month) {
    final names = 'common.monthsFull'.tr().split(',');
    final name = names.length == 12
        ? names[month.month - 1].trim()
        : '${month.month}';
    return '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.data,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final AttendanceMonth? data;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month).weekday - 1;
    final labels = [
      for (var i = 1; i <= 7; i++) 'g5.school.timetableScreen.days.$i'.tr(),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - 6 * 4) / 7;
        return Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  SizedBox(
                    width: cell,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: GText.caption,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < leading; i++)
                  SizedBox(width: cell, height: cell),
                for (var d = 1; d <= days; d++)
                  _cell(DateTime(month.year, month.month, d), cell),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _cell(DateTime date, double size) {
    final day = data?.dayOf(date);
    final future = date.isAfter(today);
    final on = sameDay(date, selected);
    final look = day == null ? null : _look(day.status);
    final color = look?.hue.base;
    return GPressable(
      onTap: future ? null : () => onSelect(date),
      selected: on,
      exclusive: true,
      semanticLabel:
          '${localizedDayMonth(date)}${look == null ? '' : ', ${'g5.school.history.${look.key}'.tr()}'}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color?.withValues(alpha: .16) ?? const Color(0x08FFFFFF),
          border: Border.all(
            color: on
                ? GColors.link
                : (color?.withValues(alpha: .4) ?? const Color(0x00FFFFFF)),
            width: on ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${date.day}',
                style: GText.onest(
                  14,
                  weight: FontWeight.w700,
                  color: future ? GColors.textFaint : GColors.text,
                ),
              ),
            ),
            if (look != null)
              Positioned(
                right: 3,
                bottom: 3,
                child: GIcon(
                  look.icon,
                  size: 11,
                  color: look.hue.icon,
                  secondaryOpacity: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.date, required this.day});

  final DateTime date;
  final AttendanceDay? day;

  @override
  Widget build(BuildContext context) {
    final d = day;
    return GSection(
      title: localizedDayMonth(date),
      child: GGlass(
        child: d == null
            ? Text('g5.school.history.noData'.tr(), style: GText.caption)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.kioskIn == null && d.kioskOut == null
                        ? 'g5.school.history.noKiosk'.tr()
                        : 'g5.school.history.kioskLine'.tr(
                            namedArgs: {
                              'in': d.kioskIn ?? '—',
                              'out': d.kioskOut ?? '—',
                            },
                          ),
                    style: GText.body,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (d.confirmed
                            ? 'g5.school.history.schoolLine'
                            : 'g5.school.history.autoLine')
                        .tr(
                          namedArgs: {
                            'status': 'g5.school.history.${_look(d.status).key}'
                                .tr(),
                          },
                        ),
                    style: GText.onest(
                      14,
                      weight: FontWeight.w600,
                      color: d.confirmed
                          ? const Color(0xFFBFF3DB)
                          : GColors.textLabel,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return GSection(
      title: 'g5.school.history.legend'.tr(),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          for (final status in DayStatus.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GIcon(
                  _look(status).icon,
                  size: 14,
                  color: _look(status).hue.icon,
                  secondaryOpacity: 0,
                ),
                const SizedBox(width: 6),
                Text(
                  'g5.school.history.${_look(status).key}'.tr(),
                  style: GText.caption,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
