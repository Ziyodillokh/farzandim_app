// ARCH-13: monolit ekran fayli `part` fayllarga bo'lindi.
// REDIZAYN (Figma): pastki varaq endi FAQAT "Harakatlar tarixi" timeline.
// HERO (avatar/jonli), manzil kartasi, 3 metrika va Geo-zonalar tugmasi
// olib tashlandi — manzil/holat suzuvchi `_StatusCard`ga, geo-zonalar
// top-bar "qatlamlar" ikoniga ko'chdi.
part of 'location_map_screen.dart';

/// Sheet foni — dashboard fonidan biroz ochiqroq qora-ko'k shisha.
const Color _sheetBg = Color(0xFF0A1018);

/// Pastki varaq — "Harakatlar tarixi" timeline (+ kerak bo'lsa joylashuv
/// ruxsati ogohlantirishi).
class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.child, required this.scrollController});

  final Child child;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    const topRadius = BorderRadius.vertical(top: Radius.circular(_radius));
    final lackPermission = child.deviceInfo?.locationPermission == false;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: topRadius,
        border: Border(top: BorderSide(color: _cardBorder)),
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
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Bola qurilmasida "Har doim" lokatsiya ruxsati yo'q (shartli).
            if (lackPermission) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(_radiusSm),
                  border: Border.all(color: _warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      SolarIconsOutline.mapPointRemove,
                      size: 18,
                      color: _warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'location.command.permissionWarning'.tr(),
                        style: _lpop(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],

            // ── HARAKATLAR TARIXI (timeline) ──
            _HistoryTimeline(child: child),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ HARAKATLAR TARIXI (timeline) ═══════════════

/// Bugungi to'xtashlar (stops) vertikal timeline sifatida — har bir to'xtash
/// geo-zonaga moslab nomlanadi (Uy/Maktab/... yoki "Noma'lum").
class _HistoryTimeline extends ConsumerWidget {
  const _HistoryTimeline({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stopsAsync = ref.watch(locationStopsProvider(_todayQuery(child.id)));
    final zones =
        ref.watch(geoZonesProvider(child.id)).valueOrNull ?? const <GeoZone>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Harakatlar tarixi', style: _lunb(15, w: FontWeight.w700)),
        const SizedBox(height: AppDimensions.sm + 2),
        stopsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _blue,
                ),
              ),
            ),
          ),
          error: (_, __) => _emptyHistory("Tarixni yuklab bo'lmadi"),
          data: (stops) {
            if (stops.isEmpty) {
              return _emptyHistory('Bugun harakat qayd etilmadi');
            }
            // Eng yangisi tepada.
            final ordered = [...stops]
              ..sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
            return Column(
              children: [
                for (var i = 0; i < ordered.length; i++)
                  _HistoryTile(
                    stop: ordered[i],
                    zone: _zoneForStop(ordered[i].latLng, zones),
                    isLast: i == ordered.length - 1,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _emptyHistory(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_radiusSm),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.mapPointRemove, size: 18, color: _dim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: _lpop(13, c: _dim)),
          ),
        ],
      ),
    );
  }
}

/// Bitta to'xtash qatori — chap relsda doira ikon + ulovchi chiziq,
/// o'ngda vaqt + joy nomi + ko'cha + "Bordi"/"Kechikdi" belgisi.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.stop,
    required this.zone,
    required this.isLast,
  });

  final LocationStop stop;
  final GeoZone? zone;
  final bool isLast;

  IconData get _icon {
    // Figma Dev Mode'dagi AYNAN Solar nomlari:
    //   Noma'lum = Streets Map Point, Maktab = Calculator Minimalistic,
    //   Uy = Home 2.
    if (zone == null) return SolarIconsBold.streetsMapPoint;
    if (zone!.type == GeoZoneType.home) return SolarIconsBold.home2;
    if (zone!.type == GeoZoneType.school) {
      return SolarIconsBold.calculatorMinimalistic;
    }
    return SolarIconsBold.mapPoint;
  }

  String get _place => zone?.name ?? "Noma'lum";

  String get _time {
    final h = stop.arrivedAt.hour.toString().padLeft(2, '0');
    final m = stop.arrivedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chap rels: doira ikon (oq ikon, neytral doira) + ulovchi chiziq.
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: _cardBorder),
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 24, color: Colors.white),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Kontent kartasi.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(_radiusSm),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$_time,',
                                style: _lunb(14, w: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _place,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _lpop(14, w: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stop.isOngoing
                                ? 'Hozir shu yerda'
                                : stop.durationLabel,
                            style: _lpop(12, c: _dim),
                          ),
                        ],
                      ),
                    ),
                    // Har tugagan to'xtash uchun yashil "Bordi" belgisi
                    // (zonadan tashqari "Noma'lum" ham).
                    const SizedBox(width: 8),
                    const _StatusBadge(
                      label: 'Bordi',
                      color: _success,
                      icon: SolarIconsBold.checkCircle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Holat belgisi (yumshoq rangli pill).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: _lpop(11.5, w: FontWeight.w700, c: color),
          ),
        ],
      ),
    );
  }
}
