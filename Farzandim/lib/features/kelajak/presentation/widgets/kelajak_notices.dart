// ─────────────────────────────────────────────────────────────────────
// kelajak_notices — yosh, bo'sh holat va ogohlantirish (disclaimer)
// ─────────────────────────────────────────────────────────────────────
//
// Yosh kiritilmagan (`AGE_REQUIRED`) yoki 7–18 dan tashqari bo'lsa —
// tushuntirish va mavjud "Shaxsiy ma'lumotlar" (bola tahrirlash)
// sahifasiga tugma: yosh taxmin qilinmaydi, ota-ona o'zi kiritadi.
// Bo'sh holat — savollar Parvoz Growth'dagi "Bugungi testlar"da.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/growth/presentation/widgets/growth_header.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_text.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Yosh kiritilmagan yoki mos emas (holat `ok` bo'lsa chizilmaydi).
class KelajakAgeNotice extends StatelessWidget {
  const KelajakAgeNotice({
    required this.status,
    required this.onEditAge,
    super.key,
  });

  final KelajakAgeStatus status;
  final VoidCallback onEditAge;

  @override
  Widget build(BuildContext context) {
    final keys = switch (status) {
      KelajakAgeStatus.ageRequired => (
        title: 'kelajak.age.requiredTitle',
        body: 'kelajak.age.requiredBody',
        action: 'kelajak.age.requiredAction',
      ),
      KelajakAgeStatus.ageOutOfRange => (
        title: 'kelajak.age.outOfRangeTitle',
        body: 'kelajak.age.outOfRangeBody',
        action: 'kelajak.age.outOfRangeAction',
      ),
      KelajakAgeStatus.ok || KelajakAgeStatus.unknown => null,
    };
    if (keys == null) return const SizedBox.shrink();
    return GrowthNoticeCard(
      icon: SolarIconsBold.calendarMark,
      title: keys.title.tr(),
      body: keys.body.tr(),
      actionLabel: keys.action.tr(),
      onAction: onEditAge,
    );
  }
}

/// Hali javob yo'q.
class KelajakEmptyNotice extends StatelessWidget {
  const KelajakEmptyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return GrowthNoticeCard(
      icon: SolarIconsBold.compass,
      title: 'kelajak.empty.title'.tr(),
      body: 'kelajak.empty.body'.tr(),
    );
  }
}

/// Natijalar tavsiya ekani, tashxis va qat'iy kasb hukmi emasligi.
class KelajakDisclaimer extends StatelessWidget {
  const KelajakDisclaimer({required this.text, super.key});

  final LocalizedText? text;

  @override
  Widget build(BuildContext context) {
    final server = kelajakText(context, text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(SolarIconsBold.infoCircle, size: 16, color: kelajakDim),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            server.isEmpty ? 'kelajak.disclaimer'.tr() : server,
            style: kelajakPop(12, c: kelajakDim),
          ),
        ),
      ],
    );
  }
}
