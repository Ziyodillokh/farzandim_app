// Testdan chiqishni tasdiqlash (javoblar serverda saqlangan — bugun shu
// joydan davom etiladi). Kunlik test dialogi uslubida.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';

/// `true` — chiqish; `false` / yopildi — qolish.
Future<bool> confirmKelajakLeave(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: HomeColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: HomeColors.cardBorder),
      ),
      title: Text(
        'kelajak.leave.title'.tr(),
        style: homeText(18, weight: FontWeight.w800),
      ),
      content: Text(
        'kelajak.leave.body'.tr(),
        style: homeText(14, color: HomeColors.textDim, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'kelajak.leave.leave'.tr(),
            style: homeText(
              14.5,
              weight: FontWeight.w600,
              color: HomeColors.textDim,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: HomeColors.primary,
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'kelajak.leave.stay'.tr(),
            style: homeText(14.5, weight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  return leave ?? false;
}
