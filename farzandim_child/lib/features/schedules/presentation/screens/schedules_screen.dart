// ─────────────────────────────────────────────────────────────────────
// SchedulesScreen — bola o'zining jadvalini ko'radi (read-only)
// ─────────────────────────────────────────────────────────────────────
//
// - Personalized greeting (vaqt bo'yicha)
// - Status card: "Hozir: ..." yoki "Keyingi: ..."
// - Bugungi jadvallar list (vaqt bo'yicha sort)
// - Auto-refresh har daqiqa (current/next yangilanish)

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim_child/features/schedules/presentation/widgets/schedule_tile.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/skeleton_card.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() =>
      _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'schedules.greetingNight'.tr();
    if (h < 12) return 'schedules.greetingMorning'.tr();
    if (h < 17) return 'schedules.greetingDay'.tr();
    if (h < 22) return 'schedules.greetingEvening'.tr();
    return 'schedules.greetingNight'.tr();
  }

  String _minutesUntil(Schedule schedule) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.startHour,
      schedule.startMinute,
    );
    final diff = start.difference(now).inMinutes;

    if (diff < 60) {
      return 'schedules.minutesUntil'.tr(
        namedArgs: {'minutes': '$diff'},
      );
    }
    final hours = diff ~/ 60;
    final mins = diff % 60;
    if (mins == 0) {
      return 'schedules.hoursUntil'.tr(
        namedArgs: {'hours': '$hours'},
      );
    }
    return 'schedules.hoursMinutesUntil'.tr(
      namedArgs: {'hours': '$hours', 'minutes': '$mins'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todaySchedulesProvider);
    final current = ref.watch(currentScheduleProvider);
    final next = ref.watch(nextScheduleProvider);
    final activeAsync = ref.watch(activeSchedulesProvider);

    return Scaffold(
      backgroundColor: context.adaptive.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.adaptive.bgPrimary,
        elevation: 0,
        title: Text(
          'schedules.title'.tr(),
          style: TextStyle(
            color: context.adaptive.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: context.adaptive.textPrimary),
      ),
      body: activeAsync.when(
        data: (_) {
          if (today.isEmpty) {
            return _EmptyState();
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.adaptive.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.adaptive.border,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}!',
                        style: TextStyle(
                          color: context.adaptive.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (current != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: AppColors.primary,
                              size: 10,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'schedules.current'.tr(
                                  namedArgs: {
                                    'title': current.title,
                                    'endTime':
                                        current.endTimeFormatted,
                                  },
                                ),
                                style: TextStyle(
                                  color: context.adaptive.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (next != null)
                        Row(
                          children: [
                            Icon(
                              AppIcons.schedule,
                              color: context.adaptive.textSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'schedules.next'.tr(
                                  namedArgs: {
                                    'title': next.title,
                                    'until': _minutesUntil(next),
                                  },
                                ),
                                style: TextStyle(
                                  color: context.adaptive.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'schedules.allDone'.tr(),
                          style: TextStyle(
                            color: context.adaptive.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'schedules.todayList'.tr(),
                  style: TextStyle(
                    color: context.adaptive.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...today.map(
                (s) => ScheduleTile(
                  schedule: s,
                  isCurrent: s.id == current?.id,
                ),
              ),
            ],
          );
        },
        // Skeleton: status card + 4 ta jadval kartochka
        loading: () => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonCard(height: 120),
              SizedBox(height: 24),
              SkeletonBox(width: 180, height: 18),
              SizedBox(height: 16),
              SkeletonRowCard(),
              SizedBox(height: 12),
              SkeletonRowCard(),
              SizedBox(height: 12),
              SkeletonRowCard(),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'schedules.errorPrefix'.tr(namedArgs: {'error': '$e'}),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.adaptive.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // FARO faceSleeping — "dam olish kuni, jadval yo'q" hissi
    return EmptyStateMascot(
      faroVariant: FaroVariant.faceSleeping,
      title: 'schedules.emptyTitle'.tr(),
      subtitle: 'schedules.emptySubtitle'.tr(),
    );
  }
}
