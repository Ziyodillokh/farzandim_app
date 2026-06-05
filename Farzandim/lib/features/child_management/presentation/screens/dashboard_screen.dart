import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/providers/selected_child_index_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/quick_action_tile.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/screen_time_chart.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/shared/widgets/app_bottom_nav.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final isAuthed =
        ref.watch(backendAuthProvider.select((s) => s is AuthAuthenticated));
    final childrenAsync = ref.watch(childrenProvider);
    final children = childrenAsync.valueOrNull;

    // Auth tiklanmoqda yoki bolalar hali yuklanmoqda → spinner. Bu add-child
    // sahifaga "o'zidan o'zi otib ketish" (bo'sh ro'yxat flash) muammosini
    // bartaraf etadi: faqat haqiqatan bola yo'q (settled) bo'lganda
    // "Bola qo'shing" ko'rsatiladi. Qayta-fetch paytida oxirgi ro'yxat
    // (valueOrNull, copyWithPrevious) saqlanib turadi.
    final Widget body;
    if (!isAuthed || children == null) {
      body = const _DashboardLoading();
    } else if (children.isEmpty) {
      body = childrenAsync.isLoading
          ? const _DashboardLoading()
          : const _EmptyState();
    } else {
      body = _DashboardBody(children: children);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(child: body),
      ),
    );
  }
}

// ════════════════════════ LOADING ════════════════════════

/// Dashboard yuklanish holati — auth tiklanmoqda yoki bolalar kelmoqda.
/// `_EmptyState` (add-child) o'rniga ko'rsatiladi, shunda bo'sh "flash" bo'lmaydi.
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: AppColors.primary),
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
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                border: Border.all(color: AppColors.border),
              ),
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

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  bool _blockAll = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initial = ref
        .read(selectedChildIndexProvider)
        .clamp(0, widget.children.length - 1);
    _pageController = PageController(initialPage: initial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('auth.social.comingSoon'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
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
    final selectedIndex =
        ref.watch(selectedChildIndexProvider).clamp(0, children.length - 1);

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

        // ─── Gorizontal PageView — har bola TO'LIQ ekran ───
        // Chapga sursa keyingi bola butunlay ochiladi (oldingisi ko'rinmaydi).
        // Oxirgi sahifa (agar <3 bola) — yangi bola qo'shish.
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (i) {
              // Faqat bola sahifalarida tanlovni yangilaymiz (add sahifasida
              // selectedIndex oxirgi bolada qoladi — pastki bar uchun).
              if (i < children.length) {
                ref.read(selectedChildIndexProvider.notifier).state = i;
              }
            },
            itemBuilder: (context, i) {
              if (i >= children.length) {
                return const _AddChildPage();
              }
              final c = children[i];
              // Tepadan pastga tortsa — shu bolaning BARCHA ma'lumotlari qayta
              // yuklanadi (RefreshIndicator). AlwaysScrollableScrollPhysics —
              // kalta sahifada ham pull-to-refresh ishlashi uchun.
              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => _onRefresh(c.id),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.sm,
                    AppDimensions.lg,
                    AppDimensions.md,
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
                        blockAll: _blockAll,
                        onBlockChanged: (v) {
                          setState(() => _blockAll = v);
                          _comingSoon();
                        },
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

        // ─── Fiksirlangan pastki bar: Foydalanish vaqti + sozlamalar ───
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.sm,
            AppDimensions.lg,
            AppDimensions.md,
          ),
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
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/icons/parent_logo_icon.png',
          height: 44,
          width: 44,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        // Light/dark toggle — notification bell'ning CHAP tarafida.
        const _ThemeToggle(),
        const SizedBox(width: AppDimensions.sm),
        const _NotificationBell(),
      ],
    );
  }
}

/// ☀️/🌙 — light va dark rejim orasida almashtiradi (saqlanadi).
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == AppThemeMode.dark;
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(themeModeProvider.notifier).toggle(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              // Dark'da quyosh (light'ga o'tish), light'da oy (dark'ga o'tish).
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 23,
              color: isDark ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.notifications),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.notifications_outlined,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
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

// ════════════════════════ CHILD HEADER ════════════════════════

/// Bitta bolaning header'i — ism, qurilma, yashil sanoq indikatori + avatar.
/// Bolalar orasida o'tish PageView orqali (bu yerda strip yo'q) — yashil
/// segmentlar qaysi bola ko'rsatilayotganini bildiradi.
class _ChildInfoHeader extends StatelessWidget {
  const _ChildInfoHeader({
    required this.child,
    required this.childCount,
    required this.selectedIndex,
  });

  final Child child;
  final int childCount;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                child.name,
                style: AppTextStyles.headlineL.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                child.deviceModel?.isNotEmpty ?? false
                    ? child.deviceModel!
                    : 'dashboard.noDevice'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.sm),
              // Yashil segmentlar = bola SONI + qaysi biri ko'rsatilayapti.
              _ChildCountIndicator(
                count: childCount,
                selected: selectedIndex,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        ChildAvatar(child: child),
      ],
    );
  }
}

/// Yashil segmentli indikator — bola SONINI va tanlanganini ko'rsatadi.
/// Har segment = bitta bola; tanlangani kengroq va yorqinroq.
class _ChildCountIndicator extends StatelessWidget {
  const _ChildCountIndicator({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(right: 4),
            width: i == selected ? 22 : 12,
            height: 6,
            decoration: BoxDecoration(
              color: i == selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// PageView'ning oxirgi sahifasi — yangi bola qo'shish (max 3 tagacha).
/// Bolalar sahifalaridan keyin chapga sursa shu ko'rinadi.
class _AddChildPage extends StatelessWidget {
  const _AddChildPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.md,
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
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
    );
  }
}

class _BatteryBar extends StatelessWidget {
  const _BatteryBar({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    const segments = 6;
    final filled = level == null
        ? 0
        : ((level! / 100) * segments).round().clamp(0, segments);
    final color = (level ?? 0) <= 20 ? AppColors.error : AppColors.primary;

    return Row(
      children: [
        for (var i = 0; i < segments; i++)
          Container(
            margin: const EdgeInsets.only(right: 4),
            width: 18,
            height: 6,
            decoration: BoxDecoration(
              color: i < filled ? color : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        if (level != null) ...[
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════ RATING ════════════════════════

class _RatingSection extends ConsumerWidget {
  const _RatingSection({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(childProfileProvider(child.id)).valueOrNull;
    final xp = profile?.xp ?? 0;
    final donBalance = profile?.donBalance ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'dashboard.rating.title'.tr(),
              style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  context.push(AppRoutes.childAchievementsPath(child.id)),
              child: Row(
                children: [
                  Text(
                    'dashboard.rating.details'.tr(),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          child: Row(
            children: [
              Text(
                '$donBalance',
                style: AppTextStyles.headlineL.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              ChildAvatar(child: child, size: 44, showBorder: false),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (child.region.isNotEmpty)
                      Text(
                        child.region,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              const Icon(
                Icons.star_rounded,
                size: 20,
                color: Color(0xFF6D28D9),
              ),
              const SizedBox(width: 4),
              Text(
                '$xp',
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════ TIME CARD ════════════════════════

class _TimeCard extends ConsumerWidget {
  const _TimeCard({
    required this.childId,
    required this.blockAll,
    required this.onBlockChanged,
  });

  final String childId;
  final bool blockAll;
  final ValueChanged<bool> onBlockChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayUsageProvider(childId)).valueOrNull;
    // FAQAT foydalanuvchi ilovalari (system/launcher/orqa-fon emas) — ikonka
    // qatori uchun. `filteredApps` system prefixlarni chiqarib tashlaydi.
    final filtered = day?.filteredApps ?? const [];
    final apps =
        filtered.map((a) => _AppBrief(a.appName, a.iconUrl)).toList();
    // Bugungi jami vaqt — detail "Ekran vaqti" bilan AYNI avtoritar manba
    // (server `/weekly`, system filtrlangan + Toshkent, 30 sek polling). Avval
    // bu yer per-app yig'indini alohida hisoblardi → dashboard ↔ detail farq
    // qilardi (1h7m ↔ 1h22m) va realtime emas edi.
    final weeklyAsync = ref.watch(weeklyChildUsageProvider(childId));
    final totalMs = ref.watch(todayScreenTimeMsProvider(childId));
    // Birinchi yuklash paytida "0 daq" o'rniga "—" — ma'lumot hali kelmaganda
    // noto'g'ri 0 ko'rsatib, keyin sakrab o'zgarmasligi uchun (startup "0 then
    // corrects" muammosi).
    final isFirstLoad = weeklyAsync.isLoading && !weeklyAsync.hasValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dashboard.screenTime.todayTitle'.tr(),
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isFirstLoad ? '—' : _formatDuration(totalMs),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // Ilova ikonkalari — ekran kengligiga moslab nechta sig'sa shuncha
          // (qolganlari "+N" badge). Qat'iy 6 ta tor telefonlarda overflow
          // berardi ("qisilib qolyapti" muammosi).
          if (apps.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                const iconSlot = 36.0 + AppDimensions.sm; // ikonka + oraliq
                final fit = (constraints.maxWidth / iconSlot)
                    .floor()
                    .clamp(1, apps.length);
                // Hammasi sig'masa, oxirgi slotni "+N" badge uchun qoldiramiz.
                final iconCount =
                    fit < apps.length ? (fit - 1).clamp(1, apps.length) : fit;
                final shown = apps.take(iconCount).toList();
                final remaining = apps.length - shown.length;
                return Row(
                  children: [
                    for (final app in shown) ...[
                      _AppIcon(iconUrl: app.iconUrl, name: app.name),
                      const SizedBox(width: AppDimensions.sm),
                    ],
                    if (remaining > 0)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+$remaining',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppDimensions.md),

          // Bloklash toggle.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'dashboard.screenTime.blockAll'.tr(),
                    style: AppTextStyles.bodyS,
                  ),
                ),
                Switch.adaptive(
                  value: blockAll,
                  onChanged: onBlockChanged,
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    if (h == 0) return '$m daq';
    return '$h st $m daq';
  }
}

class _AppBrief {
  const _AppBrief(this.name, this.iconUrl);
  final String name;
  final String? iconUrl;
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.iconUrl, required this.name});

  final String? iconUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: iconUrl != null && iconUrl!.isNotEmpty
          ? Image.network(
              iconUrl!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(letter),
            )
          : _fallback(letter),
    );
  }

  Widget _fallback(String letter) {
    return Text(
      letter,
      style: AppTextStyles.bodyS.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ════════════════════════ QUICK ACTIONS ════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    final tiles = <QuickActionTile>[
      QuickActionTile(
        icon: Icons.smartphone,
        label: 'dashboard.quickActions.device'.tr(),
        accentColor: AppColors.info,
        onTap: () => context.push(AppRoutes.qaDevicePath(childId)),
      ),
      QuickActionTile(
        icon: Icons.telegram,
        label: 'dashboard.quickActions.messenger'.tr(),
        accentColor: AppColors.primary,
        onTap: () => context.push(AppRoutes.qaVoicePath(childId)),
      ),
      // "Ilova cheklovlari" — eski "Qurilma cheklovlari" ekrani
      // (`app_limits_screen`, Figma 1:1: 2-tab ro'yxat + `AppLimitModal`)
      // shunchaki "Ilova cheklovlari" deb nomlanadi (soat ikona, eskisidek).
      // Ortiqcha ikkinchi cheklov kartasi (Faollik) olib tashlandi — Faollik
      // endi faqat pastdagi "Foydalanish vaqti" tugmasidan ochiladi.
      QuickActionTile(
        icon: Icons.lock_clock,
        label: 'dashboard.quickActions.appRestrictions'.tr(),
        accentColor: const Color(0xFFA78BFA),
        onTap: () => context.push(AppRoutes.appLimitsPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.location_on_outlined,
        label: 'dashboard.quickActions.locationHistory'.tr(),
        accentColor: AppColors.success,
        onTap: () => context.push(AppRoutes.locationHistoryPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.calendar_today_outlined,
        label: 'dashboard.quickActions.schedules'.tr(),
        accentColor: AppColors.error,
        onTap: () => context.push(AppRoutes.schedulesPath(childId)),
      ),
    ];

    // `childAspectRatio` o'rniga `mainAxisExtent` — tile balandligi ekran
    // kengligiga bog'liq EMAS. Aks holda tor telefonlarda tile qisilib,
    // ikonka + 2 qatorli matn sig'may qolardi ("qisilib qolyapti" muammosi).
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 118,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => tiles[i],
    );
  }
}
