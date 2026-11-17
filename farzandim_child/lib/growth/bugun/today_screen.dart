// B01 · Bugun — bosh ekran: salomlashuv va aloqa ikonlari, ko'rsatkichlar,
// kunlik vazifa, maktab va kunning savoli. Pastga tortilsa hamma manbalar yangilanadi.

import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/bugun/kids_today_screen.dart';
import 'package:farzandim_child/growth/bugun/widgets/mission_card.dart';
import 'package:farzandim_child/growth/bugun/widgets/setup_reminders.dart';
import 'package:farzandim_child/growth/common/learning_rules.dart';
import 'package:farzandim_child/growth/bugun/widgets/stats_strip.dart';
import 'package:farzandim_child/growth/bugun/widgets/today_header.dart';
import 'package:farzandim_child/growth/bugun/widgets/today_tiles.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(backendGamificationProvider)
      ..invalidate(schoolTodayProvider)
      ..invalidate(schoolAssignmentsProvider)
      ..invalidate(kelajakOverviewProvider);
    await refreshLearning(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(learningClockProvider)();
    final profile = ref.watch(learningProfileProvider);
    // 1–4-sinf o'quvchisi uchun B01 o'rniga soddalashtirilgan B03.
    if (profile != null && isEarlyGrade(profile.grade)) {
      return KidsTodayView(profile: profile, onRefresh: () => _refresh(ref));
    }
    return GScreen(
      top: TodayHeader(now: now),
      onRefresh: () => _refresh(ref),
      children: const [
        SetupReminders(),
        StatsStrip(),
        MissionCard(),
        TodayTiles(),
      ],
    );
  }
}
