import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/dashboard/presentation/providers/selected_child_index_provider.dart';
import 'package:farzandim/features/dashboard/presentation/widgets/quick_action_tile.dart';
import 'package:farzandim/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final children = ref.watch(childrenListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: children.isEmpty
              ? const _EmptyState()
              : _DashboardBody(children: children),
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
                child: const Icon(
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

          // ─── Pastki bar ───
          Row(
            children: [
              Expanded(
                child: _UsageTimePill(
                  onTap: () => context.push(AppRoutes.addChild),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              _SettingsGear(onTap: () => context.push(AppRoutes.settings)),
            ],
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
              return SingleChildScrollView(
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
          child: Row(
            children: [
              Expanded(
                child: _UsageTimePill(
                  onTap: () => context.push(
                    AppRoutes.appRestrictionsPath(children[selectedIndex].id),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              _SettingsGear(onTap: () => context.push(AppRoutes.settings)),
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
        Image.asset(
          'assets/icons/parent_logo_icon.png',
          height: 44,
          width: 44,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        const _NotificationBell(),
      ],
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
        _ChildAvatar(child: child, size: 64, highlighted: true),
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
                child: const Icon(
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

class _ChildAvatar extends StatelessWidget {
  const _ChildAvatar({
    required this.child,
    required this.size,
    this.highlighted = false,
  });

  final Child child;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.border,
          width: highlighted ? 2.5 : 1,
        ),
      ),
      child: ClipOval(
        child: child.photoUrl != null && child.photoUrl!.isNotEmpty
            ? Image.network(
                child.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _sticker(),
              )
            : _sticker(),
      ),
    );
  }

  Widget _sticker() {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SvgPicture.asset(child.defaultStickerPath),
      ),
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
                  const Icon(
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
                  color: AppColors.background,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              _ChildAvatar(child: child, size: 44),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (child.region.isNotEmpty)
                      Text(
                        child.region,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.background.withValues(alpha: 0.7),
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
                  color: AppColors.background,
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
    final apps = day == null
        ? const <_AppBrief>[]
        : (day.apps.toList()
              ..sort((a, b) => b.totalTimeMs.compareTo(a.totalTimeMs)))
            .map((a) => _AppBrief(a.appName, a.iconUrl))
            .toList();
    final totalMs =
        day?.apps.fold<int>(0, (sum, a) => sum + a.totalTimeMs) ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
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
            _formatDuration(totalMs),
            style: AppTextStyles.headlineXL.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // Ilova ikonkalari (top 6).
          if (apps.isNotEmpty)
            Row(
              children: [
                for (final app in apps.take(6)) ...[
                  _AppIcon(iconUrl: app.iconUrl, name: app.name),
                  const SizedBox(width: AppDimensions.sm),
                ],
                if (apps.length > 6)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+${apps.length - 6}',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
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
      decoration: const BoxDecoration(
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
        icon: Icons.chat_bubble_outline_rounded,
        label: 'dashboard.quickActions.messenger'.tr(),
        accentColor: AppColors.primary,
        onTap: () => context.push(AppRoutes.qaVoicePath(childId)),
      ),
      QuickActionTile(
        icon: Icons.timer_outlined,
        label: 'dashboard.quickActions.appRestrictions'.tr(),
        accentColor: AppColors.warning,
        onTap: () => context.push(AppRoutes.appRestrictionsPath(childId)),
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.05,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: tiles,
    );
  }
}

// ════════════════════════ BOTTOM BAR ════════════════════════

class _UsageTimePill extends StatelessWidget {
  const _UsageTimePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: Material(
        color: AppColors.primary,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pie_chart_rounded,
                  size: 20,
                  color: AppColors.background,
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  'dashboard.usageTime'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.background,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGear extends StatelessWidget {
  const _SettingsGear({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.settings_outlined,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
