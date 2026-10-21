// Ochiq javob maydoni: ko'p qatorli, server bilan bir xil chegara (UTF-16
// belgilar soni, standart 1000) va pastda "123/1000" hisoblagichi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/care_request_fields.dart';
import 'package:flutter/material.dart';

class KelajakTextAnswer extends StatelessWidget {
  const KelajakTextAnswer({
    super.key,
    required this.controller,
    required this.maxLength,
    this.enabled = true,
  });

  final TextEditingController controller;
  final int maxLength;
  final bool enabled;

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
            enabled: enabled,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [MaxUtf16LengthFormatter(maxLength)],
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            cursorColor: HomeColors.primary,
            style: homeText(15, height: 1.4),
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: 'kelajak.session.textHint'.tr(),
              hintStyle: homeText(15, color: HomeColors.textDim, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => Text(
            'kelajak.session.counter'.tr(
              namedArgs: {'count': '${value.text.length}', 'max': '$maxLength'},
            ),
            textAlign: TextAlign.right,
            style: homeText(12, color: HomeColors.textDim),
          ),
        ),
      ],
    );
  }
}
