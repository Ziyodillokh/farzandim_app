// Testlar qidiruvi — barcha testlar bo'yicha (sarlavha yoki fan nomi).
// `/tests/search`. Apostrof turlari va registr e'tiborga olinmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/tests/presentation/providers/tests_providers.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/tests_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TestsSearchScreen extends ConsumerStatefulWidget {
  const TestsSearchScreen({super.key});

  @override
  ConsumerState<TestsSearchScreen> createState() => _TestsSearchScreenState();
}

class _TestsSearchScreenState extends ConsumerState<TestsSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(testSearchProvider(_query));

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    growthTopInset(context),
                    16,
                    16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        HeaderIconButton(
                          semanticLabel: 'common.back'.tr(),
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/contests'),
                          child: const HomeSvgIcon(homeBackSvg, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SearchField(
                            controller: _controller,
                            onChanged: _onChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_query.trim().isEmpty || results.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
                      child: Center(
                        child: Text(
                          _query.trim().isEmpty
                              ? 'tests.searchStart'.tr()
                              : 'tests.searchEmpty'.tr(),
                          textAlign: TextAlign.center,
                          style: homeText(14, color: HomeColors.textDim),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, insets.bottom + 24),
                    sliver: SliverTestsGrid(tests: results),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onChanged(String value) => setState(() => _query = value);
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HomeColors.iconButton,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.cardBorder),
      ),
      child: Row(
        children: [
          const HomeSvgIcon(homeSearchSvg, size: 18, color: HomeColors.textDim),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: HomeColors.primary,
              style: homeText(14, weight: FontWeight.w500),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'tests.searchHint'.tr(),
                hintStyle: homeText(14, color: HomeColors.textDim),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(13),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: HomeColors.textDim,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
