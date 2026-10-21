// "Maktabim" — "Bola ovozi" bo'limlari:
//   • so'rovnoma kartasi — faol so'rovnoma bo'lsa "Javob berish", javob
//     berilgan bo'lsa — rahmat; so'rovnoma yo'q bo'lsa karta ko'rinmaydi;
//   • psixolog kartasi — "Psixologga yozish", "Murojaatlarim" va eng yaqin
//     belgilangan suhbat (push kelmaydi — shu yerda eslatiladi).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// "Bola ovozi" so'rovnomasi kartasi.
class CareSurveyCard extends ConsumerWidget {
  const CareSurveyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careSurveyProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum holat ko'rinadi.
    final survey = state.valueOrNull?.survey;
    final isAnswered = state.valueOrNull?.isAnswered ?? false;
    if (survey == null && !isAnswered) {
      if (!state.hasError || state.isLoading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: kSchoolSectionGap),
        child: SchoolSectionError(
          onRetry: () => ref.invalidate(careSurveyProvider),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: kSchoolSectionGap),
      child: SchoolSectionCard(
        icon: SolarIconsBold.chatRoundLike,
        color: SchoolColors.accent,
        title: 'school.survey.title'.tr(),
        children: survey == null
            ? const [SizedBox(height: 10), _AnsweredRow()]
            : [
                if (survey.title.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    survey.title.trim(),
                    style: homeText(15.5, weight: FontWeight.w700, height: 1.3),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'school.survey.hubBody'.tr(
                    namedArgs: {
                      'questions': 'home.questions'.plural(
                        survey.questions.length,
                      ),
                    },
                  ),
                  style: homeText(13.5, color: HomeColors.textDim, height: 1.4),
                ),
                const SizedBox(height: 10),
                SchoolNote(
                  icon: SolarIconsOutline.lockKeyhole,
                  color: SchoolColors.accent,
                  iconColor: SchoolColors.accent,
                  text: 'school.survey.privacyShort'.tr(),
                ),
                const SizedBox(height: 12),
                SchoolPillButton(
                  label: 'school.survey.answer'.tr(),
                  icon: SolarIconsOutline.pen,
                  onTap: () => openCareSurvey(context),
                ),
              ],
      ),
    );
  }
}

class _AnsweredRow extends StatelessWidget {
  const _AnsweredRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          SolarIconsBold.checkCircle,
          size: 20,
          color: HomeColors.green,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'school.survey.answered'.tr(),
            style: homeText(14, color: HomeColors.textDim, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// "Psixolog bilan gaplashing" kartasi.
class CareHelpCard extends ConsumerWidget {
  const CareHelpCard({super.key, this.clock = DateTime.now});

  /// Joriy vaqt (testda — soxta soat).
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests =
        ref.watch(careRequestsProvider).valueOrNull ?? const <CareRequest>[];
    final meeting = nextMeeting(requests, clock());
    final meetingAt = meeting?.meetingAt;
    return Padding(
      padding: const EdgeInsets.only(top: kSchoolSectionGap),
      child: SchoolSectionCard(
        icon: SolarIconsBold.userSpeak,
        color: HomeColors.orange,
        title: 'school.requests.hubTitle'.tr(),
        children: [
          const SizedBox(height: 8),
          Text(
            'school.requests.hubBody'.tr(),
            style: homeText(13.5, color: HomeColors.textDim, height: 1.4),
          ),
          if (meetingAt != null) ...[
            const SizedBox(height: 10),
            SchoolNote(
              icon: SolarIconsOutline.calendarMark,
              color: SchoolColors.accent,
              iconColor: SchoolColors.accent,
              text: 'school.requests.nextMeeting'.tr(
                namedArgs: {'date': tashkentDateTime(meetingAt)},
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SchoolPillButton(
                  label: 'school.requests.write'.tr(),
                  onTap: () => openNewCareRequest(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SchoolPillButton(
                  label: 'school.requests.title'.tr(),
                  isPrimary: false,
                  onTap: () => openCareRequests(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
