// Hub'dagi test kartasi: nom, qisqa tavsif, bugungi holat, savollar soni va
// taxminiy vaqt. Bosilsa — bugungi test (yakunlangan bo'lsa — natijasi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class KelajakTestCard extends StatelessWidget {
  const KelajakTestCard({super.key, required this.test, required this.onTap});

  final KelajakTestInfo test;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = kelajakDayStateOf(test.today);
    final description = test.description?.inLocale(context).trim() ?? '';
    final meta = kelajakTestMeta(test);
    final title = test.title.inLocale(context);
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: homeCardDecoration(radius: 18),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: homeText(
                        16,
                        weight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (state != null) ...[
                    const SizedBox(width: 8),
                    KelajakStatusChip(state: state),
                  ],
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: homeText(13, color: HomeColors.textDim, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (meta.isNotEmpty) ...[
                    const Icon(
                      SolarIconsOutline.clockCircle,
                      size: 15,
                      color: HomeColors.textDim,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(12.5, color: HomeColors.textDim),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Text(
                    kelajakActionKey(state).tr(),
                    style: homeText(
                      13.5,
                      weight: FontWeight.w700,
                      color: HomeColors.blue,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: HomeColors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
