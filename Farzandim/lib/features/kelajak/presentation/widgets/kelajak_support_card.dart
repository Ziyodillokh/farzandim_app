// ─────────────────────────────────────────────────────────────────────
// KelajakSupportCard — qo'llab-quvvatlash signali (faqat signal bo'lsa)
// ─────────────────────────────────────────────────────────────────────
//
// Ehtiyotkor ohang: raqam, ball va savol yo'q; qizil rang yo'q. Backend
// maslahati ("Bu tashxis emas...") + sohalar + xotirjam suhbat
// uchun qisqa maslahatlar. Maslahat matni kelmasa — ilova matni.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_support.dart';
import 'package:farzandim/features/kelajak/presentation/widgets/kelajak_ui.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Xotirjam suhbat maslahatlari (tartib bilan).
const List<String> kKelajakTalkTipKeys = [
  'kelajak.support.talk1',
  'kelajak.support.talk2',
  'kelajak.support.talk3',
];

class KelajakSupportCard extends StatelessWidget {
  const KelajakSupportCard({required this.support, super.key});

  final KelajakSupport support;

  @override
  Widget build(BuildContext context) {
    final guidance = kelajakText(context, support.guidance);
    final areas = [
      for (final area in support.areas) kelajakText(context, area.name),
    ].where((name) => name.isNotEmpty).toList();
    final day = support.day;
    final title = switch (support.level) {
      KelajakSupportLevel.watch => 'kelajak.support.titleWatch',
      KelajakSupportLevel.support => 'kelajak.support.titleSupport',
    };
    return KelajakSection(
      icon: SolarIconsBold.handHeart,
      iconColor: kelajakAmber,
      title: title.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            guidance.isEmpty ? 'kelajak.support.fallback'.tr() : guidance,
            style: kelajakPop(13.5),
          ),
          if (areas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'kelajak.support.areas'.tr(),
              style: kelajakPop(12.5, w: FontWeight.w600, c: kelajakDim),
            ),
            const SizedBox(height: 6),
            KelajakChipWrap(labels: areas),
          ],
          if (day != null) ...[
            const SizedBox(height: 8),
            Text(
              'kelajak.support.day'.tr(
                namedArgs: {'date': formatSchoolDay(day)},
              ),
              style: kelajakPop(12.5, c: kelajakDim),
            ),
          ],
          const SizedBox(height: 12),
          const _TalkTips(),
        ],
      ),
    );
  }
}

/// "Suhbat uchun maslahat" — uchta qisqa qadam.
class _TalkTips extends StatelessWidget {
  const _TalkTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kelajakChipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                SolarIconsBold.chatRoundLike,
                size: 16,
                color: kelajakDim,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'kelajak.support.talkTitle'.tr(),
                  style: kelajakPop(12.5, w: FontWeight.w600, c: kelajakDim),
                ),
              ),
            ],
          ),
          for (final key in kKelajakTalkTipKeys) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: kelajakPop(13, c: kelajakDim)),
                const SizedBox(width: 8),
                Expanded(child: Text(key.tr(), style: kelajakPop(13))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
