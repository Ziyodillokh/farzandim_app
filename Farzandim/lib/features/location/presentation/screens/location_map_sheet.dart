// ARCH-13: monolit ekran fayli `part` fayllarga bo'lindi — private nomlar
// va vizual xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'location_map_screen.dart';

// ═══════════════ LOCATION SHEET (Command Deck) ═══════════════

/// Premium "boshqaruv paneli" pastki varaq (DraggableScrollableSheet ichida).
///
/// Tuzilma (ota-ona savollari tartibida): HERO (avatar + ism + JONLI puls) →
/// MANZIL kartasi ("qayerda") → 3 metrika (holat / batareya / aniqlik) →
/// 2 ta katta amal tugmasi (Geo-zonalar to'liq-rang CTA + Tarixni ko'rish).
/// Faqat origin/main'da mavjud tokenlar ishlatiladi (GlassCard/glass token YO'Q).
class _LocationSheet extends ConsumerWidget {
  const _LocationSheet({
    required this.child,
    required this.location,
    required this.scrollController,
  });

  final Child child;
  final ChildLocation location;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(childAddressProvider(child.id)).valueOrNull;
    final battery = child.deviceInfo?.batteryLevel;
    final isCharging = child.deviceInfo?.isCharging ?? false;
    final isMoving = location.isMoving;
    const topRadius = BorderRadius.vertical(
      top: Radius.circular(AppDimensions.radiusL),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: topRadius,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.elevated,
      ),
      child: ClipRRect(
        borderRadius: topRadius,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.sm,
            AppDimensions.md,
            MediaQuery.of(context).padding.bottom + AppDimensions.md,
          ),
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── HERO: avatar (mint halqa) + ism + JONLI puls (ixcham) ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                  child: ChildAvatar(child: child, size: 42, showBorder: false),
                ),
                const SizedBox(width: AppDimensions.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.headlineL.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _LivePill(live: _isLive(ref, location.updatedAt)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${'location.command.now'.tr()} · '
                        '${formatRelativeTime(location.updatedAt)}',
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.sm + 2),

            // Bola qurilmasida "Har doim" lokatsiya ruxsati yo'q —
            // fon kuzatuv ishlamasligining eng keng tarqalgan sababi.
            if (child.deviceInfo?.locationPermission == false) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_disabled_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'location.command.permissionWarning'.tr(),
                        style: AppTextStyles.bodyS.copyWith(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
            ],

            // ── MANZIL kartasi ("qayerda" — eng muhim ma'lumot) ──
            _AddressCard(address: address),

            const SizedBox(height: AppDimensions.sm + 2),

            // ── 3 metrika: holat / batareya / aniqlik ──
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: isMoving
                        ? Icons.directions_walk_rounded
                        : Icons.check_circle_rounded,
                    tint: isMoving ? AppColors.accent : AppColors.success,
                    value: isMoving
                        ? 'location.command.statusMoving'.tr()
                        : 'location.command.statusStationary'.tr(),
                    label: 'location.command.statusLabel'.tr(),
                    valueColored: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: isCharging
                        ? Icons.bolt_rounded
                        : Icons.battery_full_rounded,
                    tint: battery == null
                        ? AppColors.textTertiary
                        : battery >= 50
                        ? AppColors.success
                        : battery >= 20
                        ? AppColors.warning
                        : AppColors.error,
                    value: battery == null ? '—' : '$battery%',
                    label: 'location.command.batteryLabel'.tr(),
                    valueColored: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.gps_fixed_rounded,
                    tint: AppColors.info,
                    value: 'location.command.accuracyValue'.tr(
                      namedArgs: {'meters': '${location.accuracy.round()}'},
                    ),
                    label: 'location.command.accuracyLabel'.tr(),
                    valueColored: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.sm + 2),

            // Amal tugmalari — bitta qatorda, kompakt: chapda Geo-zonalar
            // (to'liq-rang CTA), o'ngda Tarixni ko'rish (outline).
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.fence_rounded,
                    label: 'location.geoZonesButton'.tr(),
                    filled: true,
                    compact: true,
                    onTap: () => context.push(AppRoutes.geoZonesPath(child.id)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.route_rounded,
                    label: 'location.command.historyButton'.tr(),
                    compact: true,
                    onTap: () =>
                        context.push(AppRoutes.locationHistoryPath(child.id)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Jonli puls indikatori (real-vaqt signali) ───

/// Haqiqatan jonlimi: socket ulangan VA nuqta 2 daqiqadan yangi.
/// Avval pill shartsiz "JONLI" deb yonib turardi — ma'lumot soatlab eski
/// bo'lsa ham, bu testchini chalg'itgan.
bool _isLive(WidgetRef ref, DateTime updatedAt) {
  // 30s puls — vaqt o'tishi bilan qayta hisoblanib tursin.
  ref.watch(statusTickProvider);
  final socketState = ref.watch(socketConnectionProvider).valueOrNull;
  return socketState == SocketConnectionState.connected &&
      DateTime.now().difference(updatedAt) < const Duration(minutes: 2);
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.live});

  /// false — kulrang "kechikkan" rejim (puls yo'q).
  final bool live;

  @override
  Widget build(BuildContext context) {
    final tint = live ? AppColors.accent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            _PulseDot(color: tint, size: 7)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            live
                ? 'location.command.live'.tr()
                : 'location.command.stale'.tr(),
            style: AppTextStyles.label.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yumshoq nafas oluvchi puls nuqtasi — o'z AnimationController'ini saqlaydi
/// (StatefulWidget, shunda stream qayta-build qilganda controller buzilmaydi).
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.20 + 0.35 * (1 - t)),
                blurRadius: 3 + 5 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Manzil kartasi ───

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null && address!.isNotEmpty;
    // Ixcham qator — kichik ikon + bitta-ikki qatorli matn.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.place_rounded, size: 15, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: hasAddress
                ? Text(
                    address!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  )
                : Text(
                    'location.command.addressLoading'.tr(),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Metrika plitkasi (holat / batareya / aniqlik) ───

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    required this.valueColored,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final bool valueColored;

  @override
  Widget build(BuildContext context) {
    // Ixcham plitka — kichik ikon, zich oraliqlar (avval ancha baland edi).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: tint),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.headlineL.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColored ? tint : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Katta amal tugmasi (to'liq-rang CTA yoki outline) ───

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  /// Kompakt rejim — bitta qatorda yonma-yon (icon+matn markazda, chevronsiz).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : null,
          color: filled ? null : AppColors.surfaceVariant,
          borderRadius: radius,
          border: filled
              ? null
              : Border.all(color: AppColors.border, width: 1.4),
          boxShadow: filled ? AppShadows.glow(AppColors.primary) : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: compact ? 44 : 56,
            child: compact
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 17,
                        color: filled ? AppColors.onPrimary : AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyM.copyWith(
                            color: filled
                                ? AppColors.onPrimary
                                : AppColors.textPrimary,
                            fontWeight: filled
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: filled
                              ? AppColors.onPrimary
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyM.copyWith(
                                    color: filled
                                        ? AppColors.onPrimary
                                        : AppColors.textPrimary,
                                    fontWeight: filled
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: filled
                              ? AppColors.onPrimary.withValues(alpha: 0.75)
                              : AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
