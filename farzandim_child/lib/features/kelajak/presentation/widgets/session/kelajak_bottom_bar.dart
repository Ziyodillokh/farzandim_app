// Kelajak testi pastki qatori: xato / izoh qatori, "O'tkazib yuborish"
// (ixtiyoriy savolda), "Orqaga" va "Keyingi" / "Yakunlash".

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

const _danger = Color(0xFFFF8A80);

class KelajakBottomBar extends StatelessWidget {
  const KelajakBottomBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
    this.busy = false,
    this.onSkip,
    this.hint,
    this.error,
    this.onDismissError,
  });

  final String primaryLabel;

  /// `null` — tugma yopiq (javob tanlanmagan).
  final VoidCallback? onPrimary;

  /// `null` — birinchi savol.
  final VoidCallback? onBack;
  final bool busy;

  /// `null` — o'tkazib yuborib bo'lmaydi.
  final VoidCallback? onSkip;

  /// Nega tugma yopiq (masalan, "javoblardan birini tanlang").
  final String? hint;
  final String? error;
  final VoidCallback? onDismissError;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final error = this.error;
    final hint = this.hint;
    final onSkip = this.onSkip;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 14),
      decoration: const BoxDecoration(
        color: HomeColors.bg,
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            _ErrorLine(text: error, onDismiss: onDismissError)
          else if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: homeText(13, color: HomeColors.textDim, height: 1.35),
              ),
            ),
          if (onSkip != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextButton(
                onPressed: onSkip,
                child: Text(
                  'kelajak.session.skip'.tr(),
                  style: homeText(
                    14.5,
                    weight: FontWeight.w700,
                    color: HomeColors.blue,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _BackButton(onTap: busy ? null : onBack),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: SetupButton(
                  label: primaryLabel,
                  onTap: onPrimary,
                  busy: busy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: HomeColors.tile,
        shape: const StadiumBorder(
          side: BorderSide(color: HomeColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FitText(
                  'kelajak.session.back'.tr(),
                  style: homeText(15.5, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text, required this.onDismiss});

  final String text;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final onDismiss = this.onDismiss;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.dangerCircle, size: 18, color: _danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: homeText(13, color: HomeColors.text, height: 1.35),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'common.close'.tr(),
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: HomeColors.textDim,
              ),
            ),
        ],
      ),
    );
  }
}
