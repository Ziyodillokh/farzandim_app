// ─────────────────────────────────────────────────────────────────────
// StatusCardsGrid — joylashuv / batareya / Wi-Fi cards
// ─────────────────────────────────────────────────────────────────────
//
// Real-vaqt ma'lumot DeviceInfoService → Firestore → stream orqali
// keladi. Wi-Fi yoki batareya kelmagan bo'lsa "—" ko'rsatiladi
// (mock ishlatilmaydi).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class StatusCardsGrid extends StatelessWidget {
  const StatusCardsGrid({
    required this.region,
    required this.deviceInfo,
    super.key,
  });

  final String region;
  final Map<String, dynamic>? deviceInfo;

  String get _battery {
    final lvl = deviceInfo?['batteryLevel'] as int?;
    return lvl == null ? '—' : '$lvl%';
  }

  bool get _isCharging => deviceInfo?['isCharging'] as bool? ?? false;

  String get _wifi {
    final name = deviceInfo?['wifiName'] as String?;
    if (name == null || name.isEmpty) return '—';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatusCard(
            icon: AppIcons.mapPin,
            label: 'dashboard.statusLocation'.tr(),
            value: region,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusCard(
            icon: Icons.battery_full,
            label: 'dashboard.statusBattery'.tr(),
            value: _battery,
            trailing: _isCharging
                ? const Icon(Icons.bolt,
                    color: AppColors.warning, size: 16)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusCard(
            icon: Icons.wifi,
            label: 'dashboard.statusWifi'.tr(),
            value: _wifi,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
