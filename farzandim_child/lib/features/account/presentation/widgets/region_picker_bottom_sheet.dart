// ─────────────────────────────────────────────────────────────────────
// RegionPickerBottomSheet — 14 viloyat tanlash modal sheet
// ─────────────────────────────────────────────────────────────────────
//
// `await RegionPickerBottomSheet.show(context, selectedRegion: ...)`
// chaqiriladi va foydalanuvchi tanlagan viloyat string sifatida
// qaytariladi (yoki `null` agar "X" tugma bilan yopilsa).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/constants/uzbekistan_regions.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class RegionPickerBottomSheet extends StatelessWidget {
  const RegionPickerBottomSheet({super.key, this.selectedRegion});

  final String? selectedRegion;

  static Future<String?> show(BuildContext context, {String? selectedRegion}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RegionPickerBottomSheet(selectedRegion: selectedRegion),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'account.regionPicker.title'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    AppIcons.close,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: UzbekistanRegions.all.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                final region = UzbekistanRegions.all[index];
                final isSelected = region == selectedRegion;

                return ListTile(
                  title: Text(
                    region,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: 2,
                      ),
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            AppIcons.check,
                            size: 16,
                            color: Colors.black,
                          )
                        : null,
                  ),
                  onTap: () => Navigator.pop(context, region),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
