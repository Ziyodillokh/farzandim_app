// Fan testlari — bitta fan bo'yicha barcha testlar (HAQIQIY backend).
// `/tests/subject` (extra: fan kaliti — `testSubjectKey`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/tests/presentation/providers/tests_providers.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/subject_grid.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/subject_style.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/tests_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubjectTestsScreen extends ConsumerWidget {
  const SubjectTestsScreen({super.key, required this.subjectKey});

  final String subjectKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(testSubjectProvider(subjectKey));
    final loading = ref.watch(backendContestsProvider).isLoading;
    final style = subjectStyleFor(subjectKey);

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return RefreshIndicator(
              color: HomeColors.primary,
              backgroundColor: HomeColors.card,
              edgeOffset: insets.top,
              onRefresh: () async {
                ref.invalidate(backendContestsProvider);
                await ref.read(backendContestsProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      growthTopInset(context),
                      16,
                      16,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: InnerPageHeader(
                        title: group == null ? '' : subjectDisplayName(group),
                        subtitle: group == null
                            ? null
                            : 'tests.count'.plural(group.count),
                        trailing: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: style.squareColor,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: style.icon(21, style.squareColor),
                        ),
                      ),
                    ),
                  ),
                  if (group == null || group.count == 0)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: loading
                            ? const CircularProgressIndicator(
                                color: HomeColors.primary,
                              )
                            : Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'tests.subjectSoon'.tr(),
                                  textAlign: TextAlign.center,
                                  style: homeText(
                                    14,
                                    color: HomeColors.textDim,
                                  ),
                                ),
                              ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        insets.bottom + 24,
                      ),
                      sliver: SliverTestsGrid(tests: group.tests),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
