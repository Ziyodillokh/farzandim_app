// ─────────────────────────────────────────────────────────────────────
// SchedulesScreen — bola o'zining jadvalini ko'radi (read-only)
// Parvoz NIGHT/GLASS redizayn (izchil parvoz_glass.dart tokenlar)
// ─────────────────────────────────────────────────────────────────────
//
// - ParvozHeader (push-screen, orqaga bor)
// - Status card: "Hozir: ..." yoki "Keyingi: ..." — parvozGlass
// - Bugungi jadvallar list (vaqt bo'yicha sort) — ScheduleTile (night)
// - Auto-refresh har daqiqa (current/next yangilanish)
// - LOGIKA O'ZGARMAGAN: provider'lar, .tr(), Timer — saqlanishi shart

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim_child/features/schedules/presentation/widgets/schedule_tile.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:farzandim_child/shared/widgets/skeleton_card.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
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
      backgroundColor: AppColors.parvozBg,
      body: Column(
        children: [
          ParvozHeader(
            title: 'schedules.title'.tr(),
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: activeAsync.when(
              data: (_) {
                if (today.isEmpty) {
                  return const _EmptyState();
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
                  children: [
                    // ─── Status / greeting glass card ───────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatusCard(
                        greeting: _greeting(),
                        current: current,
                        next: next,
                        minutesUntil: _minutesUntil,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ─── "Bugungi jadval" sarlavhasi ────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ParvozSectionLabel(
                        'schedules.todayList'.tr(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ─── Jadval qatorlari ───────────────────────────
                    ...today.map(
                      (s) => ScheduleTile(
                        schedule: s,
                        isCurrent: s.id == current?.id,
                      ),
                    ),
                  ],
                );
              },
              // Skeleton: status card + 3 ta jadval qatori
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
                    style: const TextStyle(color: AppColors.parvozTextDim),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status / greeting glass karta ─────────────────────────────────────
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.greeting,
    required this.current,
    required this.next,
    required this.minutesUntil,
  });

  final String greeting;
  final Schedule? current;
  final Schedule? next;
  final String Function(Schedule) minutesUntil;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: parvozGlass(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Salomlashuv
          Text(
            '$greeting!',
            style: const TextStyle(
              color: AppColors.parvozText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          // Holat qatori
          if (current != null)
            _StatusRow(
              icon: Icons.circle,
              iconColor: AppColors.parvozGreen,
              iconSize: 10,
              text: 'schedules.current'.tr(
                namedArgs: {
                  'title': current!.title,
                  'endTime': current!.endTimeFormatted,
                },
              ),
            )
          else if (next != null)
            _StatusRow(
              icon: AppIcons.schedule,
              iconColor: AppColors.parvozTextDim,
              iconSize: 16,
              text: 'schedules.next'.tr(
                namedArgs: {
                  'title': next!.title,
                  'until': minutesUntil(next!),
                },
              ),
            )
          else
            Text(
              'schedules.allDone'.tr(),
              style: const TextStyle(
                color: AppColors.parvozTextDim,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.parvozText,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bo'sh holat ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
