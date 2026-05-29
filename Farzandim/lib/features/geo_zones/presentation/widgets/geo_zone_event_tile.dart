import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/geo_zones/data/models/geo_zone_event.dart';
import 'package:flutter/material.dart';

/// Bitta geo-zona event tile (kirdi/chiqdi).
///
/// Chap tomonda yashil/sariq dumaloq icon (kirdi/chiqdi), keyin
/// `RichText` jumla: bola ismi (qalin), zona nomi (lime green qalin),
/// keyin "ga keldi/ketdi". Pastda Bugun/Kecha/sana + soat.
class GeoZoneEventTile extends StatelessWidget {
  /// `GeoZoneEventTile` konstruktor.
  const GeoZoneEventTile({required this.event, super.key});

  /// Ko'rsatiladigan event.
  final GeoZoneEvent event;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(eventDay).inDays;

    if (diff == 0) return 'geoZoneEvents.tile.dateToday'.tr();
    if (diff == 1) return 'geoZoneEvents.tile.dateYesterday'.tr();
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEnter = event.eventType == GeoZoneEventType.enter;
    final color = isEnter ? AppColors.success : AppColors.warning;
    final icon = isEnter ? Icons.login : Icons.logout;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppDimensions.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (_) {
                    final name = event.childName.isEmpty
                        ? 'geoZoneEvents.tile.fallbackChildName'.tr()
                        : event.childName;
                    final key = event.eventType == GeoZoneEventType.enter
                        ? 'geoZoneEvents.tile.eventLine.enter'
                        : 'geoZoneEvents.tile.eventLine.exit';
                    return Text(
                      key.tr(
                        namedArgs: {
                          'name': name,
                          'zone': event.zoneName,
                        },
                      ),
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(event.timestamp)} · '
                  '${_formatTime(event.timestamp)}',
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
    );
  }
}
