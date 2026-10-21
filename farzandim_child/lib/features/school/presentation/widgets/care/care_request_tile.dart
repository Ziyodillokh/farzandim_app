// "Murojaatlarim" qatori: mavzu (shoshilinch belgisi bilan), holat,
// yuborilgan vaqt va belgilangan suhbat (Toshkent vaqtida). Matn
// ko'rsatilmaydi — u faqat psixologda.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class CareRequestTile extends StatelessWidget {
  const CareRequestTile({super.key, required this.request});

  final CareRequest request;

  @override
  Widget build(BuildContext context) {
    final meetingAt = request.meetingAt;
    final statusColor = careStatusColor(request.status);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: homeCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SchoolIconSquare(
                icon: careTopicIcon(request.topic),
                color: HomeColors.blue,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Holat faqat sarlavha qatorida — sana to'liq enda.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            careTopicLabelKey(request.topic).tr(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: homeText(
                              15.5,
                              weight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: careStatusLabelKey(request.status).tr(),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'school.requests.sentAt'.tr(
                        namedArgs: {
                          'date': tashkentDateTime(request.createdAt),
                        },
                      ),
                      style: homeText(12.5, color: HomeColors.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.urgency == CareUrgency.urgent) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusChip(
                label: 'school.requests.urgentTitle'.tr(),
                color: HomeColors.amber,
                icon: SolarIconsBold.alarm,
              ),
            ),
          ],
          if (meetingAt != null) ...[
            const SizedBox(height: 10),
            SchoolNote(
              icon: SolarIconsOutline.calendarMark,
              color: SchoolColors.accent,
              iconColor: SchoolColors.accent,
              text: 'school.requests.meeting'.tr(
                namedArgs: {'date': tashkentDateTime(meetingAt)},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeText(
                12,
                weight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
