// Psixologga murojaat shakli bo'laklari: mavzu tanlovi (7 ta), xabar maydoni
// (1000 belgigacha, hisoblagich bilan), "Shoshilinch" kaliti va SOS izohi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/care_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';

/// SOS izohi rangi (xavf).
const _danger = Color(0xFFFF6B6B);

/// Sarlavha ("Nima haqida?", "Xabaringiz").
class CareFieldLabel extends StatelessWidget {
  const CareFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: homeText(15.5, weight: FontWeight.w700));
  }
}

/// Mavzu tanlovi — bittasi tanlanadi.
class CareTopicChips extends StatelessWidget {
  const CareTopicChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CareTopic? selected;
  final ValueChanged<CareTopic> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final topic in selectableCareTopics)
          _TopicChip(
            topic: topic,
            isSelected: topic == selected,
            onTap: () => onSelected(topic),
          ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.topic,
    required this.isSelected,
    required this.onTap,
  });

  final CareTopic topic;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(11, 9, 14, 9),
          decoration: BoxDecoration(
            color: isSelected
                ? HomeColors.primary.withValues(alpha: 0.2)
                : HomeColors.tile,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? HomeColors.primary : HomeColors.tileBorder,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                careTopicIcon(topic),
                size: 17,
                color: isSelected ? HomeColors.text : HomeColors.textDim,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  careTopicLabelKey(topic).tr(),
                  style: homeText(
                    14,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Xabar maydoni: ko'p qatorli, server bilan bir xil chegara (UTF-16
/// belgilar soni) va pastda "123/1000".
class CareMessageField extends StatelessWidget {
  const CareMessageField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: HomeColors.tile,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.tileBorder),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: const [
              MaxUtf16LengthFormatter(kCareMessageMaxLength),
            ],
            cursorColor: HomeColors.primary,
            style: homeText(15, height: 1.4),
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'school.requests.messageHint'.tr(),
              hintStyle: homeText(15, color: HomeColors.textDim, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            '${value.text.length}/$kCareMessageMaxLength',
            textAlign: TextAlign.right,
            style: homeText(12, color: HomeColors.textDim),
          ),
        ),
      ],
    );
  }
}

/// Matnni [max] UTF-16 belgigacha cheklaydi (server `message.length` bilan
/// bir xil); uzun matn joylansa — belgilarni bo'lmasdan qisqartiriladi.
class MaxUtf16LengthFormatter extends TextInputFormatter {
  const MaxUtf16LengthFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= max) return newValue;
    final buffer = StringBuffer();
    for (final char in newValue.text.characters) {
      if (buffer.length + char.length > max) break;
      buffer.write(char);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// "Shoshilinch" kaliti.
class CareUrgentToggle extends StatelessWidget {
  const CareUrgentToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: value
              ? HomeColors.amber.withValues(alpha: 0.1)
              : HomeColors.tile,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? HomeColors.amber.withValues(alpha: 0.45)
                : HomeColors.tileBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              SolarIconsOutline.alarm,
              size: 22,
              color: value ? HomeColors.amber : HomeColors.textDim,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'school.requests.urgentTitle'.tr(),
                    style: homeText(15, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'school.requests.urgentBody'.tr(),
                    style: homeText(
                      12.5,
                      color: HomeColors.textDim,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: HomeColors.amber,
            ),
          ],
        ),
      ),
    );
  }
}

/// Xavf ostida — kutmang: SOS xabar (Chatlar) yoki 112.
class CareSosNote extends StatelessWidget {
  const CareSosNote({super.key, required this.onSos});

  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.siren, size: 22, color: _danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'school.requests.sos'.tr(),
              style: homeText(13, color: HomeColors.textDim, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _danger,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSos,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Text(
                  'chats.sosButton'.tr(),
                  style: homeText(13.5, weight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
