import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/providers/selected_child_index_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/child_page_view.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/quick_action_tile.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Asosiy ekran — auth qilingan foydalanuvchi uchun bola monitoringi.
///
/// **Conditional UI:**
/// - **Empty state** (`children.isEmpty`): "Bola qo'shing" call-to-action
///   karta.
/// - **Has children**: yuqorida `ChildPageView` (swipe), pastida Quick
///   Action grid va yumaloq Settings tugmasi.
///
/// Tanlangan bola `selectedChildIndexProvider` orqali bog'lanadi —
/// `ChildPageView` swipe qilganda boshqa kartalar avtomatik yangilanadi.
class DashboardScreen extends ConsumerWidget {
  /// `DashboardScreen` konstruktor.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: children.isEmpty
              ? const _EmptyState()
              : _DashboardContent(children: children),
        ),
      ),
    );
  }
}

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.md),
          const _TopBar(),
          const SizedBox(height: AppDimensions.xl),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            padding: const EdgeInsets.all(AppDimensions.xl),
            constraints: const BoxConstraints(minHeight: 280),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'dashboard.emptyState.message'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyM,
                ),
                const SizedBox(height: AppDimensions.lg),
                PrimaryButton(
                  label: 'dashboard.emptyState.addButton'.tr(),
                  icon: Icons.add,
                  expanded: false,
                  onPressed: () => context.push(AppRoutes.addChild),
                ),
              ],
            ),
          ),
          const Spacer(),
          const _SettingsCircleButton(),
          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }
}

// ════════════════════════ HAS-CHILDREN CONTENT ════════════════════════

/// Stack-based glassmorphism layout:
///   Layer 1 (pastda): scroll kontenti (ScreenTimeChart + QuickActions)
///   Layer 2 (yuqorida): glass plate — TopBar + ChildPageView
///   Layer 3 (pastda): glass plate — Settings tugmasi
///
/// Header/footer balandligi har build'da `GlobalKey` orqali o'lchanadi —
/// scroll kontenti `padding(top/bottom)` orqali plate ostiga "kirib boradi"
/// va `BackdropFilter` blur effekt beradi (Telegram/iOS-style glass).
class _DashboardContent extends ConsumerStatefulWidget {
  const _DashboardContent({required this.children});

  final List<Child> children;

  @override
  ConsumerState<_DashboardContent> createState() =>
      _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _footerKey = GlobalKey();
  double _headerHeight = 0;
  double _footerHeight = 0;
  bool _measureScheduled = false;

  // Layout o'lchash. `build()` har safar chaqirsa ham, bir frame ichida
  // faqat bitta postFrameCallback ro'yxatdan o'tadi (#3 audit — har build'da
  // callback registratsiyasi to'planib ketishini oldini oladi). Layout
  // o'zgarsa (masalan UpdateBanner ko'rinsa) — keyingi build qayta o'lchaydi.
  void _measureAfterLayout() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final headerBox =
          _headerKey.currentContext?.findRenderObject() as RenderBox?;
      final footerBox =
          _footerKey.currentContext?.findRenderObject() as RenderBox?;
      final hh = headerBox?.size.height ?? 0;
      final fh = footerBox?.size.height ?? 0;
      if (hh != _headerHeight || fh != _footerHeight) {
        setState(() {
          _headerHeight = hh;
          _footerHeight = fh;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // UpdateBanner ko'rinishi yoki bola karta o'lchami o'zgarsa —
    // har build'dan keyin qayta o'lchaymiz.
    _measureAfterLayout();

    final selectedIndex = ref
        .watch(selectedChildIndexProvider)
        .clamp(0, widget.children.length - 1);
    final currentChild = widget.children[selectedIndex];

    return Stack(
      children: [
        // Layer 1: Scroll kontenti (full-bleed, top/bottom glass plate ostiga
        // kirib boradi). Padding header/footer balandligiga moslashtirilgan.
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.lg,
              _headerHeight + AppDimensions.md,
              AppDimensions.lg,
              _footerHeight + AppDimensions.md,
            ),
            child: Column(
              children: [
                ScreenTimeChart(childId: currentChild.id),
                const SizedBox(height: AppDimensions.lg),
                _QuickActionsGrid(childId: currentChild.id),
              ],
            ),
          ),
        ),

        // Layer 2: Yuqoridagi glass plate — TopBar + UpdateBanner + Child.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _GlassPlate(
            child: KeyedSubtree(
              key: _headerKey,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.lg,
                      vertical: AppDimensions.md,
                    ),
                    child: _TopBar(),
                  ),
                  const UpdateBanner(),
                  ChildPageView(children: widget.children),
                  const SizedBox(height: AppDimensions.md),
                ],
              ),
            ),
          ),
        ),

        // Layer 3: Pastdagi glass plate — Settings tugmasi.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _GlassPlate(
            isTop: false,
            child: KeyedSubtree(
              key: _footerKey,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.md),
                child: _SettingsCircleButton(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Glassmorphism plate — kuchli `BackdropFilter` blur + ko'p shaffof fon.
///
/// Telegram/iOS uslubi: tagidagi kontent xira ko'rinadi, plate juda shaffof
/// (ko'proq frosted glass effekt). Atrofida nozik oq chiziq — shine edge.
class _GlassPlate extends StatelessWidget {
  const _GlassPlate({required this.child, this.isTop = true});

  final Widget child;

  /// `true` bo'lsa pastida shine chiziq, `false` bo'lsa yuqorida.
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Juda shaffof gradient — kontent plate ostidan aniq ko'rinadi.
            gradient: LinearGradient(
              begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.22),
                AppColors.background.withValues(alpha: 0.02),
              ],
            ),
            // Plate chetida nozik oq shine chiziq (1px).
            border: Border(
              top: isTop
                  ? BorderSide.none
                  : BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
              bottom: isTop
                  ? BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    )
                  : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ════════════════════════ KICHIK WIDGET'LAR ════════════════════════

/// Top bar: chap tomonda logo, o'ngda bell.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/icons/parent_logo_icon.png',
          height: 64,
          width: 64,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        const _NotificationBell(),
      ],
    );
  }
}

/// Bell ikona + o'qilmagan xabarlar soni badge'i.
///
/// `unreadCountProvider`'ga obuna — yangi xabar kelganda yoki
/// "Hammasini o'qildi qil" bossa avtomatik qayta render qilinadi.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.notifications),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_outlined,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.surface,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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

/// Quick actions grid — 6 ta tugma, 2x3.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    // Stagger entrance — har kvadrat status-coded accent rangida.
    final tiles = [
      QuickActionTile(
        icon: Icons.smartphone,
        label: 'dashboard.quickActions.device'.tr(),
        accentColor: AppColors.info, // ko'k — qurilma
        onTap: () => context.push(AppRoutes.qaDevicePath(childId)),
      ),
      QuickActionTile(
        icon: Icons.mic,
        label: 'dashboard.quickActions.voice'.tr(),
        accentColor: AppColors.primary, // lime — ovoz (asosiy)
        onTap: () => context.push(AppRoutes.qaVoicePath(childId)),
      ),
      QuickActionTile(
        icon: Icons.timer_outlined,
        label: 'dashboard.quickActions.appRestrictions'.tr(),
        accentColor: AppColors.warning, // sariq — vaqt cheklov
        onTap: () => context.push(AppRoutes.appRestrictionsPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.location_on_outlined,
        label: 'dashboard.quickActions.location'.tr(),
        accentColor: AppColors.success, // yashil — joylashuv
        onTap: () => context.push(AppRoutes.locationPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.calendar_today_outlined,
        label: 'dashboard.quickActions.schedules'.tr(),
        accentColor: AppColors.error, // qizil — jadval
        onTap: () => context.push(AppRoutes.schedulesPath(childId)),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.1,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        for (var i = 0; i < tiles.length; i++)
          tiles[i]
              .animate()
              .fadeIn(
                duration: 400.ms,
                delay: (80 * i).ms,
                curve: Curves.easeOut,
              )
              .moveY(
                begin: 16,
                end: 0,
                duration: 400.ms,
                delay: (80 * i).ms,
                curve: Curves.easeOutCubic,
              ),
      ],
    );
  }
}

/// Empty state'dagi pastki settings tugmasi (yumaloq, border bilan).
class _SettingsCircleButton extends StatelessWidget {
  const _SettingsCircleButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.settings),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Icon(
                Icons.settings_outlined,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
