// ARCH-13: monolit ekran fayli `part` fayllarga bo'lindi — private nomlar
// va vizual xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'location_history_screen.dart';

// ════════════════════════ TOP BAR ════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            elevation: 4,
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.lg,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'locationHistory.headerTitle'.tr(),
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    childName,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ BOTTOM PANEL ════════════════════════

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.fromDt,
    required this.toDt,
    required this.onCustomDateTap,
    required this.stops,
    required this.onPlaceTap,
    required this.distanceKm,
  });

  final DateTime fromDt;
  final DateTime toDt;
  final VoidCallback onCustomDateTap;
  final List<LocationStop> stops;
  final void Function(LatLng target) onPlaceTap;
  final double distanceKm;

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.'
      '${dt.month.toString().padLeft(2, '0')}.'
      '${(dt.year % 100).toString().padLeft(2, '0')}';

  bool get _isSameDay =>
      fromDt.year == toDt.year &&
      fromDt.month == toDt.month &&
      fromDt.day == toDt.day;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        MediaQuery.of(context).padding.bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium drag handle.
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── Tashrif buyurilgan joylar (backend to'xtashlari) ──
          if (stops.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'locationHistory.places.title'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: stops.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _PlaceCard(
                  index: i,
                  stop: stops[i],
                  onTap: () => onPlaceTap(stops[i].latLng),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // Faqat sana filtri — premium lime pill (3 ta preset chip
          // olib tashlandi, foydalanuvchi so'rovi 4.4.32).
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCustomDateTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isSameDay
                          ? _formatDate(fromDt)
                          : '${_formatDate(fromDt)}  —  ${_formatDate(toDt)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          // Stats row — premium pill kartalar.
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.place_rounded,
                  value: 'locationHistory.stats.places'.tr(
                    namedArgs: {'count': '${stops.length}'},
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatItem(
                  icon: Icons.straighten_rounded,
                  value: 'locationHistory.stats.distance'.tr(
                    namedArgs: {'km': distanceKm.toStringAsFixed(1)},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ PLACE CARD ════════════════════════

class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({
    required this.index,
    required this.stop,
    required this.onTap,
  });

  final int index;
  final LocationStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '${stop.latitude.toStringAsFixed(5)},'
        '${stop.longitude.toStringAsFixed(5)}';
    final address = ref.watch(_placeAddressProvider(key)).valueOrNull;

    final radius = BorderRadius.circular(AppDimensions.radiusM);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.info,
                        AppColors.info.withValues(alpha: 0.75),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.bodyS.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        address ?? 'locationHistory.places.unknown'.tr(),
                        style: AppTextStyles.bodyS.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stop.durationLabel,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stop.timeRange,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
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

// ════════════════════════ EMPTY STATE ════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.20),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.route_rounded,
                size: 52,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              'locationHistory.empty.title'.tr(),
              style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'locationHistory.empty.subtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
