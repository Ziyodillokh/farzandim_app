// ─────────────────────────────────────────────────────────────────────
// AgeListDialog — yosh tanlash dialogi (5-18)
// ─────────────────────────────────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AgeListDialog extends StatelessWidget {
  const AgeListDialog({super.key, this.selectedAge});

  final int? selectedAge;

  static const int _minAge = 5;
  static const int _maxAge = 18;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'account.ageDialog.title'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _maxAge - _minAge + 1,
                itemBuilder: (context, index) {
                  final age = index + _minAge;
                  final isSelected = age == selectedAge;

                  return ListTile(
                    title: Text(
                      'account.ageDialog.ageValue'.tr(
                        namedArgs: {'age': '$age'},
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(AppIcons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, age),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
