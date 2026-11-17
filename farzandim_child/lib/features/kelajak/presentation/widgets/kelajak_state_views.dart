// "Kelajagim" holat sahifalari: yosh kiritilmagan (profilga yo'naltirish —
// yosh taxmin qilinmaydi), yosh oraliqdan tashqarida, bo'lim hali yo'q va
// yuklash xatosi ("Qayta urinish").

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_error.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// `AGE_REQUIRED`: profil sahifasida yosh kiritiladi.
class KelajakAgeRequiredView extends ConsumerWidget {
  const KelajakAgeRequiredView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SchoolMessageView(
      icon: SolarIconsOutline.userId,
      iconColor: HomeColors.blue,
      title: 'kelajak.age.requiredTitle'.tr(),
      message: 'kelajak.age.requiredBody'.tr(),
      actionLabel: 'kelajak.age.requiredAction'.tr(),
      onAction: () => openKelajakAgeEdit(context, ref),
    );
  }
}

/// `AGE_OUT_OF_RANGE`: bo'lim 7–18 yoshdagilar uchun.
class KelajakOutOfRangeView extends StatelessWidget {
  const KelajakOutOfRangeView({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SchoolMessageView(
      icon: SolarIconsOutline.compass,
      iconColor: HomeColors.blue,
      title: 'kelajak.age.outOfRangeTitle'.tr(),
      message: 'kelajak.age.outOfRangeBody'.tr(),
      actionLabel: onClose == null ? null : 'common.close'.tr(),
      onAction: onClose,
    );
  }
}

/// Xato yoki bo'lim yo'q: xabar va "Qayta urinish" (bo'lmasa — "Yopish").
class KelajakErrorView extends StatelessWidget {
  const KelajakErrorView({
    super.key,
    required this.code,
    this.onRetry,
    this.onClose,
  });

  final KelajakErrorCode code;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  /// Qayta urinish ma'nosiz (natija o'zgarmaydi).
  static bool isFinal(KelajakErrorCode code) =>
      code == KelajakErrorCode.unavailable ||
      code == KelajakErrorCode.unknownType;

  @override
  Widget build(BuildContext context) {
    final retry = isFinal(code) ? null : onRetry;
    return SchoolMessageView(
      icon: switch (code) {
        KelajakErrorCode.network => Icons.wifi_off_rounded,
        KelajakErrorCode.unavailable => SolarIconsOutline.compass,
        _ => SolarIconsOutline.dangerCircle,
      },
      iconColor: code == KelajakErrorCode.unavailable
          ? HomeColors.blue
          : HomeColors.textDim,
      message: kelajakErrorKey(code).tr(),
      actionLabel: retry != null
          ? 'common.retry'.tr()
          : (onClose == null ? null : 'common.close'.tr()),
      onAction: retry ?? onClose,
    );
  }
}

/// Yuklanmoqda (sahifa o'rtasida).
class KelajakLoading extends StatelessWidget {
  const KelajakLoading({super.key, this.top = 96});

  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 24),
      child: const Center(
        child: CircularProgressIndicator(color: HomeColors.primary),
      ),
    );
  }
}
