// M01 (ulanmagan holat): maktab bo'limi yopiq bo'lganda nima uchun yopiqligi va
// keyingi qadam. Kod kiritilmagan — "Maktab kodini kiritish"; kod kiritilgan,
// tasdiq kutilmoqda — "Tasdiq kutilmoqda" (maktab nomi aytilmaydi); tuzatish
// so'rovi ochiq — "Tekshirilmoqda". Holat — `GET /child/school/link-status`.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:farzandim_child/growth/kirish/link_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _fromMaktab(String path) => Uri(
  path: path,
  queryParameters: const {kirishFromParam: kirishFromMaktab},
).toString();

class SchoolLinkStateCard extends ConsumerWidget {
  const SchoolLinkStateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(linkStatusProvider).valueOrNull?.student;
    final (icon, hue, title, body) = switch (state) {
      StudentLinkState.underReview => (
        GIcons.hourglassMedium,
        GHue.gold,
        'g5.school.link.reviewTitle'.tr(),
        'g5.school.link.reviewBody'.tr(),
      ),
      StudentLinkState.correction => (
        GIcons.shieldCheck,
        GHue.gold,
        'g5.school.link.correctionTitle'.tr(),
        'g5.school.link.correctionBody'.tr(),
      ),
      _ => (
        GIcons.backpack,
        GHue.green,
        'g5.school.notLinkedTitle'.tr(),
        'g5.school.notLinkedBody'.tr(),
      ),
    };
    final waiting =
        state == StudentLinkState.underReview ||
        state == StudentLinkState.correction;
    return GGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GTile(icon: icon, hue: hue, size: 48),
          ),
          const SizedBox(height: 12),
          Text(title, style: GText.h3),
          const SizedBox(height: 6),
          Text(body, style: GText.body),
          const SizedBox(height: 16),
          if (waiting)
            GButton(
              label: 'g5.school.link.status'.tr(),
              icon: GIcons.info,
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              onPressed: () =>
                  context.push(_fromMaktab(GrowthV5Routes.kirishStatus)),
            ),
          if (state != StudentLinkState.correction) ...[
            if (waiting) const SizedBox(height: 8),
            GButton(
              label: waiting
                  ? 'g5.school.link.otherCode'.tr()
                  : 'g5.school.link.enterCode'.tr(),
              icon: GIcons.password,
              kind: waiting ? GButtonKind.ghost : GButtonKind.primary,
              size: waiting ? GButtonSize.second : GButtonSize.lg,
              onPressed: () =>
                  context.push(_fromMaktab(GrowthV5Routes.kirishCode)),
            ),
          ],
          if (!waiting) ...[
            const SizedBox(height: 10),
            Text(
              'g5.school.link.codeHint'.tr(),
              style: GText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
