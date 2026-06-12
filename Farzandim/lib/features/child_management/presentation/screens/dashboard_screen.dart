import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
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
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:farzandim/shared/widgets/glass_card.dart';
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
/// `_EmptyState` (add-child) o'rniga ko'rsatiladi, shunda bo'sh "flash" bo'lmaydi.
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
              radius: AppDimensions.radiusL,
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

              // SUZUVCHI nav — orqa fon yo'q (shaffof): gradient + aurora ustida
              // qalqaydi, glass kartalar bilan bir xil premium til.
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

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Logo — header tugmalari bilan bir xil shisha doirada (professional).
        GlassCard(
          expandWidth: false,
          width: 52,
          radius: 26,
          blurSigma: 20,
          padding: const EdgeInsets.all(7),
          child: ClipOval(
            child: Image.asset(
              'assets/icons/parent_logo_icon.png',
              height: 38,
              width: 38,
              fit: BoxFit.cover,
            ),
          ),
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
    // Glass doira — header tugmalar ham shisha tilida (qattiq surface emas).
    return GlassCard(
      expandWidth: false,
      width: 48,
      radius: 24,
      blurSigma: 20,
      padding: EdgeInsets.zero,
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
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    // Glass doira — _ThemeToggle bilan bir xil til.
    return GlassCard(
      expandWidth: false,
      width: 48,
      radius: 24,
      blurSigma: 20,
      padding: EdgeInsets.zero,
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
                // deviceModel bo'sh bo'lsa holatga BOG'LIQ matn: ulangan bo'lsa
                // "model aniqlanmagan" (keyingi heartbeat ~20s'da to'ldiradi),
                // ulanmagan bo'lsagina "Qurilma ulanmagan". Avval har doim
                // "ulanmagan" chiqib, bola ONLINE bo'lsa ham chalg'itardi.
                child.deviceModel?.isNotEmpty ?? false
                    ? child.deviceModel!
                    : (child.isConnected
                        ? 'dashboard.deviceModelUnknown'.tr()
                        : 'dashboard.noDevice'.tr()),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.sm),
              // Jonli holat: online / aloqa uzildi / ulanmagan + batareya.
              _StatusLine(child: child),
              const SizedBox(height: AppDimensions.sm),
              // Yashil segmentlar = bola SONI + qaysi biri ko'rsatilayapti.
              _ChildCountIndicator(count: childCount, selected: selectedIndex),
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
                  ? AppColors.accent
                  : AppColors.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Bola header'idagi JONLI HOLAT qatori — online / aloqa uzildi / ulanmagan
/// indikatori + batareya. Heartbeat-aware (`Child.isLiveOnline`), shu sababli
/// aloqa uzilsa darhol "Aloqa uzildi" (sariq) ko'rinadi — avval "yashil" edi.
class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Har 30s rebuild — isLiveOnline (DateTime.now() asosli) qayta hisoblanadi
    // va har 60s ro'yxat refetch bo'ladi (statusTickProvider ichida). Busiz
    // status ekranda "muzlab" qolardi.
    ref.watch(statusTickProvider);
    final Color statusColor;
    final String statusKey;
    if (child.isLiveOnline) {
      statusColor = AppColors.success;
      statusKey = 'dashboard.status.online';
    } else if (child.isConnectionLost) {
      statusColor = AppColors.warning;
      statusKey = 'dashboard.status.connectionLost';
    } else {
      statusColor = AppColors.textTertiary;
      statusKey = 'dashboard.status.offline';
    }
    final battery = child.deviceInfo?.batteryLevel;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          statusKey.tr(),
          style: AppTextStyles.bodyS.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (battery != null) ...[
          const SizedBox(width: 12),
          Icon(
            Icons.battery_std_rounded,
            size: 14,
            color: _batteryColor(battery),
          ),
          const SizedBox(width: 4),
          Text(
            '$battery%',
            style: AppTextStyles.bodyS.copyWith(
              color: _batteryColor(battery),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Color _batteryColor(int level) {
    if (level >= 50) return AppColors.success;
    if (level >= 20) return AppColors.warning;
    return AppColors.error;
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
        child: GlassCard(
          padding: const EdgeInsets.all(AppDimensions.xl),
          radius: AppDimensions.radiusL,
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
                  color: AppColors.accent,
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
    final color = (level ?? 0) <= 20 ? AppColors.error : AppColors.accent;

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
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
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
        GlassCard(
          elevation: GlassElevation.raised,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          radius: AppDimensions.radiusL,
          child: Row(
            children: [
              Text(
                '$donBalance',
                style: AppTextStyles.headlineL.copyWith(
                  color: AppColors.accent,
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
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (child.region.isNotEmpty)
                      Text(
                        child.region,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Icon(
                Icons.star_rounded,
                size: 20,
                color: AppColors.featurePurple,
              ),
              const SizedBox(width: 4),
              Text(
                '$xp',
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textPrimary,
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

class _TimeCard extends ConsumerStatefulWidget {
  const _TimeCard({required this.childId, required this.blockAllInitial});

  final String childId;

  /// Backend'dagi joriy "barcha ilovalarni bloklash" holati (child.blockAllApps).
  final bool blockAllInitial;

  @override
  ConsumerState<_TimeCard> createState() => _TimeCardState();
}

class _TimeCardState extends ConsumerState<_TimeCard> {
  late bool _blocked = widget.blockAllInitial;
  bool _saving = false;
  // BUG-05: oxirgi muvaffaqiyatli saqlash vaqti — saqlashdan KEYIN ham
  // qisqa oynada eski in-flight poll-javobi (60s sikl) optimistik holatni
  // qaytarib yubormasligi uchun.
  DateTime? _lastSavedAt;

  @override
  void didUpdateWidget(_TimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Backend yangilangach (children refetch) sinxronlash — saqlash
    // jarayonida VA undan keyingi 70s ichida (poll davri + margin)
    // foydalanuvchi tanlovini ustun qo'yamiz: eski snapshot bilan kelgan
    // javob toggle'ni "o'zi qaytarib" qo'ymasin (BUG-05).
    final recentlySaved = _lastSavedAt != null &&
        DateTime.now().difference(_lastSavedAt!) <
            const Duration(seconds: 70);
    if (!_saving &&
        !recentlySaved &&
        oldWidget.blockAllInitial != widget.blockAllInitial) {
      _blocked = widget.blockAllInitial;
    }
  }

  /// Toggle — optimistik + backend (`setBlockAllApps`) + xatoda qaytarish.
  /// Bola qurilmasi device-policy'ni o'qib barcha ilovani bloklaydi.
  Future<void> _onToggle(bool value) async {
    if (_saving) return;
    final previous = _blocked;
    setState(() {
      _blocked = value;
      _saving = true;
    });
    try {
      await ref
          .read(backendChildRepositoryProvider)
          .setBlockAllApps(widget.childId, value);
      _lastSavedAt = DateTime.now();
      ref.invalidate(childrenProvider);
      if (mounted) {
        AppToast.success(
          context,
          value
              ? 'dashboard.screenTime.blockAllOnSnack'.tr()
              : 'dashboard.screenTime.blockAllOffSnack'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _blocked = previous);
        AppToast.error(context, 'dashboard.screenTime.blockAllErrorSnack'.tr());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childId = widget.childId;
    final day = ref.watch(todayUsageProvider(childId)).valueOrNull;
    // FAQAT foydalanuvchi ilovalari (system/launcher/orqa-fon emas) — ikonka
    // qatori uchun. `filteredApps` system prefixlarni chiqarib tashlaydi.
    final filtered = day?.filteredApps ?? const [];
    final apps = filtered.map((a) => _AppBrief(a.appName, a.iconUrl)).toList();
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

    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      radius: AppDimensions.radiusL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dashboard.screenTime.todayTitle'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isFirstLoad ? '—' : _formatDuration(totalMs),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // Eng ko'p ishlatilgan ilovalar — bir-biriga KIRISHGAN (overlapping
          // facepile, rasmdagidek): 5 tagacha ilova + qolgani "+N". Ixcham,
          // tor telefonda ham overflow bermaydi.
          if (apps.isNotEmpty) _AppFacepile(apps: apps),
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
                AppSwitch(
                  value: _blocked,
                  onChanged: _saving ? null : _onToggle,
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

/// Overlapping facepile — eng ko'p ishlatilgan ilovalar bir-biriga KIRISHGAN
/// (rasmdagidek), oxirida qolganlari "+N". Chap ikonka eng ustda turadi.
class _AppFacepile extends StatelessWidget {
  const _AppFacepile({required this.apps});

  final List<_AppBrief> apps;

  static const double _size = 40; // ikonka (ring bilan)
  static const double _step = 26; // qadam — kirishuv ~35%
  static const int _maxShown = 5; // eng ko'p ishlatilgan 5 ta

  @override
  Widget build(BuildContext context) {
    final shown = apps.take(_maxShown).toList();
    final remaining = apps.length - shown.length;
    final slots = shown.length + (remaining > 0 ? 1 : 0);
    final width = (slots - 1) * _step + _size;

    final layers = <Widget>[
      // Ilovalar TESKARI tartibda (o'ngdagisi pastda) — chap ikonka ustda.
      for (var i = shown.length - 1; i >= 0; i--)
        Positioned(
          left: i * _step,
          child: _AppIcon(
            iconUrl: shown[i].iconUrl,
            name: shown[i].name,
            size: _size,
          ),
        ),
      // "+N" — eng o'ngda, eng ustda (to'liq ko'rinadi).
      if (remaining > 0)
        Positioned(
          left: shown.length * _step,
          child: _PlusBadge(remaining: remaining, size: _size),
        ),
    ];

    return SizedBox(
      height: _size,
      width: width,
      child: Stack(clipBehavior: Clip.none, children: layers),
    );
  }
}

/// Bitta ilova ikonkasi — nozik ring (karta-tusli gap) bilan facepile uchun.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.iconUrl, required this.name, this.size = 40});

  final String? iconUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final inner = size - 5; // 2.5px ring har tomondan
    return Container(
      width: size,
      height: size,
      // Ring — karta foni tusida: overlapping ikonkalar toza ajraladi.
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: iconUrl != null && iconUrl!.isNotEmpty
            ? Image.network(
                iconUrl!,
                width: inner,
                height: inner,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(letter),
              )
            : _fallback(letter),
      ),
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

/// "+N" badge — facepile oxiri (qolgan ilovalar soni), ikonkalar bilan bir xil
/// ring + o'lcham.
class _PlusBadge extends StatelessWidget {
  const _PlusBadge({required this.remaining, this.size = 40});

  final int remaining;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inner = size - 5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: inner,
        height: inner,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '+$remaining',
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
        accentColor: AppColors.accent,
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
        accentColor: AppColors.featurePurple,
        onTap: () => context.push(AppRoutes.appLimitsPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.location_on_outlined,
        label: 'dashboard.quickActions.locationHistory'.tr(),
        accentColor: AppColors.success,
        // Jonli xarita (Command Deck) ochiladi; undan "Tarixni ko'rish" +
        // "Geo-zonalar" tugmalari mavjud. (Avval to'g'ridan tarixga borardi.)
        onTap: () => context.push(AppRoutes.locationPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.calendar_today_outlined,
        label: 'dashboard.quickActions.schedules'.tr(),
        accentColor: AppColors.error,
        onTap: () => context.push(AppRoutes.schedulesPath(childId)),
      ),
      QuickActionTile(
        icon: Icons.insights_rounded,
        label: 'dashboard.quickActions.weeklyReport'.tr(),
        accentColor: AppColors.featureAmber,
        onTap: () => context.push(AppRoutes.weeklyReportPath(childId)),
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
