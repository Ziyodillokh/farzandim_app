// part of dashboard_screen — private nomlar saqlanadi (ARCH-13:
// 1300-qatorli monolit 3 faylga bo'lindi, import/vizual o'zgarish YO'Q).
part of 'dashboard_screen.dart';

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
        // Avatar bosilsa — bola ma'lumotlarini tahrirlash sahifasi.
        GestureDetector(
          onTap: () => context.push(AppRoutes.editChildPath(child.id)),
          child: ChildAvatar(child: child),
        ),
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
        Flexible(
          child: Text(
            statusKey.tr(),
            style: AppTextStyles.bodyS.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '$donBalance',
                  style: AppTextStyles.headlineL.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              Flexible(
                child: Text(
                  '$xp',
                  style: AppTextStyles.bodyM.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
