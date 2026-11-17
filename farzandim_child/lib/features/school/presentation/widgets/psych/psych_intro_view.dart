// Psixologik test — kirish: turi, nomi, savollar soni, vaqt, oxirgi kun,
// tavsif va ko'rsatma; vaqt chegarasi bo'lsa — avtomatik yuborish haqida
// ogohlantirish. "Boshlash" bosilgandan keyin vaqt ketadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/psych_display.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class PsychIntroView extends StatelessWidget {
  const PsychIntroView({super.key, required this.test, required this.onStart});

  final PsychTest test;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final title = test.title.trim();
    final description = test.description.trim();
    final instructions = test.instructions.trim();
    final minutes = test.timeLimitMin;
    final closesAt = test.closesAt;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _KindChip(kind: test.kind),
              ),
              const SizedBox(height: 14),
              Text(
                title.isEmpty ? psychKindLabelKey(test.kind).tr() : title,
                style: homeDisplay(24, letterSpacing: -0.3, height: 1.2),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Fact(
                    icon: SolarIconsOutline.clipboardList,
                    text: 'home.questions'.plural(test.items.length),
                  ),
                  _Fact(
                    icon: SolarIconsOutline.stopwatch,
                    text: minutes == null
                        ? 'school.psych.noLimit'.tr()
                        : 'school.psych.minutes'.tr(
                            namedArgs: {'count': '$minutes'},
                          ),
                  ),
                  if (closesAt != null)
                    _Fact(
                      icon: SolarIconsOutline.calendarMark,
                      text: 'school.psych.until'.tr(
                        namedArgs: {
                          'date': localizedDayMonth(psychLastDay(closesAt)),
                        },
                      ),
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  description,
                  style: homeText(
                    14.5,
                    color: HomeColors.textDim,
                    height: 1.45,
                  ),
                ),
              ],
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Instructions(text: instructions),
              ],
              const SizedBox(height: 16),
              SchoolNote(text: 'school.psych.introNote'.tr()),
              if (minutes != null) ...[
                const SizedBox(height: 10),
                SchoolNote(
                  icon: SolarIconsOutline.stopwatch,
                  color: HomeColors.amber,
                  iconColor: HomeColors.amber,
                  text: 'school.psych.timeNote'.tr(
                    namedArgs: {'count': '$minutes'},
                  ),
                ),
              ],
            ],
          ),
        ),
        SchoolBottomBar(
          children: [
            SetupButton(label: 'school.psych.start'.tr(), onTap: onStart),
          ],
        ),
      ],
    );
  }
}

/// Test turi belgisi (ko'k fonli).
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final PsychKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
      decoration: BoxDecoration(
        color: HomeColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(psychKindIcon(kind), size: 16, color: HomeColors.blue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              psychKindLabelKey(kind).tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeText(
                12.5,
                weight: FontWeight.w700,
                color: HomeColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: HomeColors.textDim),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: homeText(13.5, weight: FontWeight.w600, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// O'quvchi uchun ko'rsatma (psixolog yozgan).
class _Instructions extends StatelessWidget {
  const _Instructions({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: HomeColors.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'school.psych.instructions'.tr(),
            style: homeText(
              12.5,
              weight: FontWeight.w700,
              color: HomeColors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Text(text, style: homeText(15, height: 1.45)),
        ],
      ),
    );
  }
}
