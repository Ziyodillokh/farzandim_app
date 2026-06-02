import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../ux/connectivity_cubit.dart';
import '../ux/offline_banner.dart';
import '../widgets/sidebar.dart';
import 'sidebar_cubit.dart';
import 'sidebar_rail_cubit.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (_) => _MobileLayout(child: child),
      tablet: (_) => _DesktopLayout(compact: true, child: child),
      desktop: (_) => _DesktopLayout(compact: false, child: child),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final Widget child;
  final bool compact;
  const _DesktopLayout({required this.child, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ConnectivityCubit, bool>(
        builder: (context, offline) {
          return BlocBuilder<SidebarRailCubit, bool>(
            builder: (context, railNarrow) {
              final base = compact ? 104.0 : 252.0;
              final sidebarWidth = railNarrow ? 72.0 : base;
              final iconsOnly = railNarrow || compact;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (offline) const OfflineBanner(),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: offline,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: offline ? 0.55 : 1,
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: sidebarWidth,
                              child: AdminSidebar(iconsOnly: iconsOnly),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.lg),
                                child: child,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final Widget child;
  const _MobileLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => context.read<SidebarCubit>().toggle(),
        ),
        title: const Text('Farzandim Admin'),
      ),
      body: BlocBuilder<ConnectivityCubit, bool>(
        builder: (context, offline) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (offline) const OfflineBanner(),
              Expanded(
                child: AbsorbPointer(
                  absorbing: offline,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: offline ? 0.55 : 1,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: child,
                        ),
                        BlocBuilder<SidebarCubit, bool>(
                          builder: (context, open) {
                            if (!open) return const SizedBox.shrink();
                            return Positioned.fill(
                              child: GestureDetector(
                                onTap: () => context.read<SidebarCubit>().collapse(),
                                child: Container(
                                  color: Colors.black45,
                                  alignment: Alignment.centerLeft,
                                  child: BlocBuilder<SidebarRailCubit, bool>(
                                    builder: (context, railNarrow) {
                                      final w = railNarrow ? 72.0 : 252.0;
                                      return SizedBox(
                                        width: w,
                                        child: Material(
                                          color: AppColors.sidebar,
                                          child: AdminSidebar(iconsOnly: railNarrow),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
