import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/providers/selected_child_index_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/quick_action_tile.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/shared/widgets/app_bottom_nav.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/glass_card.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

part 'dashboard_header_widgets.dart';
part 'dashboard_time_card.dart';

/// Bir ota-ona maksimal nechta farzand qo'sha oladi (backend ham cheklaydi).
const int _kMaxChildren = 3;

/// Asosiy ekran — Figma 1:1, dinamik bola monitoringi.
///
/// **Empty state**: bola yo'q bo'lsa "Bola qo'shing" CTA.
/// **Has children**: header (logo + bell), bola kartasi (ism/qurilma/batareya
/// + avatar), reyting (lime), bugungi ekran vaqti + ilovalar + bloklash,
/// 6 ta quick action, pastda "Foydalanish vaqti" + sozlamalar.
class DashboardScreen extends ConsumerWidget {
  /// `DashboardScreen` konstruktor.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthed = ref.watch(
      backendAuthProvider.select((s) => s is AuthAuthenticated),
    );
    final childrenAsync = ref.watch(childrenProvider);
    final children = childrenAsync.valueOrNull;

    // Auth tiklanmoqda yoki bolalar hali yuklanmoqda → spinner. Bu add-child
    // sahifaga "o'zidan o'zi otib ketish" (bo'sh ro'yxat flash) muammosini
    // bartaraf etadi: faqat haqiqatan bola yo'q (settled) bo'lganda
    // "Bola qo'shing" ko'rsatiladi. Qayta-fetch paytida oxirgi ro'yxat
    // (valueOrNull, copyWithPrevious) saqlanib turadi.
    final Widget body;
    if (!isAuthed) {
      body = const _DashboardLoading();
    } else if (children == null) {
      // Birinchi yuklash XATO bo'lsa (offline ochilish) — abadiy spinner
      // o'rniga aniq xabar + retry (EH-05). Hali yuklanmoqda bo'lsa spinner.
      body = childrenAsync.hasError
          ? _DashboardError(
              onRetry: () =>
                  ref.read(childrenRefreshTickProvider.notifier).state++,
            )
          : const _DashboardLoading();
    } else if (children.isEmpty) {
      body = childrenAsync.isLoading
          ? const _DashboardLoading()
          : const _EmptyState();
    } else {
      body = _DashboardBody(children: children);
    }

    return Scaffold(
      // Solid theme baza — overscroll/pull-to-refresh paytida oq oyna foni
      // ko'rinmasligi uchun (gradient ustidan chiziladi).
      backgroundColor: AppColors.background,
      body: GradientBackground(child: SafeArea(child: body)),
    );
  }
}

// ════════════════════════ LOADING ════════════════════════

/// Dashboard yuklanish holati — auth tiklanmoqda yoki bolalar kelmoqda.
/// `_EmptyState` (add-child) o'rniga ko'rsatiladi, shunda bo'sh "flash"
/// bo'lmaydi.
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: AppColors.accent));
  }
}

/// Birinchi yuklash xatosi (offline ochilish) — aniq xabar + qayta urinish.
/// Avval abadiy spinner ko'rinardi (EH-05).
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: AppDimensions.md),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
            child: Text(
              "Ma'lumotlarni yuklab bo'lmadi.\nInternet aloqasini tekshiring.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, color: AppColors.accent),
            label: Text(
              'Qayta urinish',
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.md),
          const _Header(),
          const SizedBox(height: AppDimensions.lg),

          // ─── Placeholder bola header (hali bola yo'q) ───
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.emptyState.placeholderName'.tr(),
                      style: AppTextStyles.headlineL.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'dashboard.emptyState.placeholderDevice'.tr(),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    const _BatteryBar(level: null),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              // Bo'sh avatar (person silueti).
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 30,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),

          // ─── Asosiy karta: "Bola qo'shing" ───
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'dashboard.emptyState.message'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
          ),
          const SizedBox(height: AppDimensions.md),

          // ─── Pastki navigatsiya (Foydalanish vaqti ↔ Sozlamalar) ───
          AppBottomNav(
            activeIndex: 0,
            activityLabel: 'dashboard.usageTime'.tr(),
            settingsLabel: 'settings.title'.tr(),
            onActivity: () => context.push(AppRoutes.addChild),
            onSettings: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }
}

// ════════════════════════ DASHBOARD BODY ════════════════════════

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.children});

  final List<Child> children;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody>
    with WidgetsBindingObserver {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = ref
        .read(selectedChildIndexProvider)
        .clamp(0, widget.children.length - 1);
    _pageController = PageController(initialPage: initial);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foydalanuvchi ilovaga QAYTGANDA bolalar ro'yxatini darhol yangilaymiz —
    // aks holda eski snapshot'dagi lastSeenAt/isConnected bilan bola noto'g'ri
    // "Aloqa uzildi"/"Ulanmagan" ko'rinardi (asosiy shikoyat shu edi).
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(childrenRefreshTickProvider.notifier).state++;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// Tepadan pastga tortilganda — tanlangan bolaning BARCHA dashboard
  /// provayderlarini invalidate qilib, backend'dan qayta o'qiydi. Spinner
  /// yangi ma'lumot kelguncha (yoki 8s himoya) ko'rinib turadi.
  Future<void> _onRefresh(String childId) async {
    // childrenProvider'ni INVALIDATE qilmaymiz — u dispose bo'lib ekran bir
    // lahza bo'shab ("add-child" flash) ketardi. O'rniga counter'ni oshiramiz:
    // provider RECOMPUTE bo'ladi, oxirgi ro'yxat saqlanib turadi.
    ref.read(childrenRefreshTickProvider.notifier).state++;
    ref
      ..invalidate(todayUsageProvider(childId))
      ..invalidate(installedAppsProvider(childId))
      ..invalidate(restrictionsProvider(childId))
      ..invalidate(weeklyChildUsageProvider(childId))
      ..invalidate(childProfileProvider(childId));
    try {
      await Future.wait([
        ref.read(childrenProvider.future),
        ref.read(todayUsageProvider(childId).future),
        ref.read(weeklyChildUsageProvider(childId).future),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Tarmoq xatosi/timeout — spinner baribir yopiladi, UI reaktiv yangilanadi.
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    final canAdd = children.length < _kMaxChildren;
    final pageCount = children.length + (canAdd ? 1 : 0);
    final selectedIndex = ref
        .watch(selectedChildIndexProvider)
        .clamp(0, children.length - 1);
    final isDark = AppColors.isDark;

    return Column(
      children: [
        // ─── Fiksirlangan tepa: LOGO + bell ───
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.md,
            AppDimensions.lg,
            AppDimensions.sm,
          ),
          child: _Header(),
        ),

        // Soft-update banner — yangi versiya bo'lsa "Yangilash" taklifi chiqadi
        // (yangilanish bo'lmasa o'zi SizedBox.shrink qaytaradi).
        const UpdateBanner(),

        // ─── Pastki qism: scroll + SUZUVCHI nav (Stack) ───
        // PageView butun bo'shliqni egallaydi; AppBottomNav uning USTIDA suzadi
        // (orqa gradient + aurora nav ortidan UZLUKSIZ ko'rinadi — eski "footer
        // to'rtburchak" yo'qoladi). Scroll pastki padding'i nav balandligini
        // hisobga oladi, shunda oxirgi karta nav ostida yashirinmaydi.
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (i) {
                    // Faqat bola sahifalarida tanlovni yangilaymiz (add
                    // sahifasida selectedIndex oxirgi bolada qoladi).
                    if (i < children.length) {
                      ref.read(selectedChildIndexProvider.notifier).state = i;
                    }
                  },
                  itemBuilder: (context, i) {
                    if (i >= children.length) {
                      return const _AddChildPage();
                    }
                    final c = children[i];
                    // Tepadan pastga tortsa — shu bolaning ma'lumoti qayta
                    // yuklanadi. AlwaysScrollableScrollPhysics: kalta sahifada
                    // ham pull-to-refresh ishlaydi.
                    return RefreshIndicator(
                      color: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      onRefresh: () => _onRefresh(c.id),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Pastki padding = lg + nav balandligi + bo'shliq:
                        // oxirgi karta suzuvchi nav ostida qolib ketmaydi.
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.lg,
                          AppDimensions.sm,
                          AppDimensions.lg,
                          AppDimensions.lg +
                              AppBottomNav.kBarHeight +
                              AppDimensions.md +
                              8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChildInfoHeader(
                              child: c,
                              childCount: children.length,
                              selectedIndex: i,
                            ),
                            const SizedBox(height: AppDimensions.lg),
                            _RatingSection(child: c),
                            const SizedBox(height: AppDimensions.lg),
                            _TimeCard(
                              childId: c.id,
                              blockAllInitial: c.blockAllApps,
                            ),
                            const SizedBox(height: AppDimensions.lg),
                            _QuickActionsGrid(childId: c.id),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Fade scrim — nav ortidagi kontent yumshoq so'nadi (QATTIQ blok
              // EMAS; faqat pastga qarab shaffofdan fon rangiga o'tadi, shunda
              // suzuvchi nav aniq o'qiladi).
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 110,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0),
                          AppColors.background.withValues(
                            alpha: isDark ? 0.35 : 0.25,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // SUZUVCHI nav — orqa fon yo'q (shaffof): gradient + aurora
              // ustida qalqaydi, glass kartalar bilan bir xil premium til.
              Positioned(
                left: AppDimensions.lg,
                right: AppDimensions.lg,
                bottom: AppDimensions.md,
                child: AppBottomNav(
                  activeIndex: 0,
                  activityLabel: 'dashboard.usageTime'.tr(),
                  settingsLabel: 'settings.title'.tr(),
                  onActivity: () => context.push(
                    AppRoutes.appRestrictionsPath(children[selectedIndex].id),
                  ),
                  onSettings: () => context.push(AppRoutes.settings),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
