// "Kelajagim" umumiy bo'laklari (Growth uslubida, gradientsiz): belgi
// kvadrati, holat belgisi, mavzu chipi, tugmalar va bo'lim sarlavhasi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:flutter/material.dart';

/// Kelajak belgisi rangi (Growth ko'k aksenti).
const kKelajakAccent = HomeColors.blue;

/// Rangli fonli kvadrat belgi.
class KelajakIconSquare extends StatelessWidget {
  const KelajakIconSquare({
    super.key,
    required this.icon,
    this.color = kKelajakAccent,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(icon, size: size * 0.52, color: color),
    );
  }
}

/// Bugungi holat belgisi: "Yangi" / "Davom etmoqda" / "Bajarildi ✓".
class KelajakStatusChip extends StatelessWidget {
  const KelajakStatusChip({super.key, required this.state});

  final KelajakDayState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      KelajakDayState.fresh => HomeColors.blue,
      KelajakDayState.unfinished => HomeColors.amber,
      KelajakDayState.done => HomeColors.green,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == KelajakDayState.done) ...[
            Icon(Icons.check_rounded, size: 14, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            kelajakStatusKey(state).tr(),
            maxLines: 1,
            style: homeText(12, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Neytral chip (mavzu, kuchli tomon, qiziqish).
class KelajakChip extends StatelessWidget {
  const KelajakChip(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 11, 6),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: HomeColors.blue),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: homeText(13, weight: FontWeight.w600, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chiplar qatori (o'ralib boradi).
class KelajakChipWrap extends StatelessWidget {
  const KelajakChipWrap({super.key, required this.labels, this.icon});

  final List<String> labels;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final l in labels) KelajakChip(l, icon: icon)],
    );
  }
}

/// Pill tugma: asosiy (ko'k) yoki ikkilamchi (plitka rangida).
class KelajakPillButton extends StatelessWidget {
  const KelajakPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = true,
    this.height = 44,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isPrimary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: isPrimary ? HomeColors.primary : HomeColors.tile,
        shape: StadiumBorder(
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: HomeColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FitText(
                      label,
                      style: homeText(14, weight: FontWeight.w700, height: 1.2),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18, color: Colors.white),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi (sahifa ichida, kartadan tashqarida).
class KelajakHeading extends StatelessWidget {
  const KelajakHeading(this.text, {super.key, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: homeDisplay(19, letterSpacing: -0.2)),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint,
              style: homeText(13, color: HomeColors.textDim, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

/// Xira izoh matni (ogohlantirish, eslatma).
class KelajakNote extends StatelessWidget {
  const KelajakNote(this.text, {super.key, this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: homeText(12.5, color: HomeColors.textDim, height: 1.45),
    );
  }
}
