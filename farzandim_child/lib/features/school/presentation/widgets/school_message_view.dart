// Maktab sahifalaridagi holat xabari: ikon, sarlavha, izoh va ixtiyoriy
// tugma (maktab ulanmagan, yuklash xatosi, "tez orada").

import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:flutter/material.dart';

class SchoolMessageView extends StatelessWidget {
  const SchoolMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.iconColor = HomeColors.textDim,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? title;
  final Color iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final actionLabel = this.actionLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomeColors.tile,
              shape: BoxShape.circle,
              border: Border.all(color: HomeColors.tileBorder),
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 18),
          if (title != null) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: homeText(18, weight: FontWeight.w800, height: 1.3),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: homeText(14, color: HomeColors.textDim, height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: homeText(14.5, weight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
