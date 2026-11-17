// K06 · Xavfsizlik darslari (ro'yxat va jarayon) va K05 · bitta dars:
// yoshga mos ssenariy, bir nechta xavfsiz javob qabul qilinadi, izoh shu
// yerda. Baholanadi, lekin DON berilmaydi; shaxsiy hodisa haqida xabar
// so'ralmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kelajak/kelajak_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class KelajakSafetyListScreen extends ConsumerWidget {
  const KelajakSafetyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(safetyProgressProvider).valueOrNull ?? {};
    final next = SafetyLesson.values
        .where((l) => !done.contains(l))
        .firstOrNull;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kelajak.safety.title'.tr(),
        ),
        children: [
          GGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'g5.kelajak.safety.progress'.tr(
                    namedArgs: {
                      'done': '${done.length}',
                      'total': '${SafetyLesson.values.length}',
                    },
                  ),
                  style: GText.itemTitle,
                ),
                const SizedBox(height: 8),
                GProgressBar(
                  value: done.length / SafetyLesson.values.length,
                  semanticLabel: 'g5.kelajak.safety.title'.tr(),
                ),
                const SizedBox(height: 8),
                Text('g5.kelajak.safety.noDon'.tr(), style: GText.caption),
              ],
            ),
          ),
          GList(
            children: [
              for (final lesson in SafetyLesson.values)
                GListItem(
                  leading: GTile(icon: lesson.icon, hue: lesson.hue, size: 44),
                  title: '${lesson.key}.title'.tr(),
                  trailing: GChip(
                    label: done.contains(lesson)
                        ? 'g5.kelajak.safety.done'.tr()
                        : lesson == next
                        ? 'g5.kelajak.safety.current'.tr()
                        : 'g5.kelajak.safety.new'.tr(),
                    kind: done.contains(lesson)
                        ? GChipKind.ok
                        : lesson == next
                        ? GChipKind.info
                        : GChipKind.neutral,
                  ),
                  onTap: () =>
                      context.push(GrowthV5Routes.kelajakLesson(lesson.name)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class KelajakSafetyLessonScreen extends ConsumerStatefulWidget {
  const KelajakSafetyLessonScreen({super.key, required this.lesson});

  final SafetyLesson lesson;

  @override
  ConsumerState<KelajakSafetyLessonScreen> createState() =>
      _KelajakSafetyLessonScreenState();
}

class _KelajakSafetyLessonScreenState
    extends ConsumerState<KelajakSafetyLessonScreen> {
  final _selected = <String>{};

  /// Tekshirilgan: `true` — faqat xavfsiz javoblar, `false` — xavfli bor.
  bool? _checked;

  SafetyLesson get lesson => widget.lesson;

  void _toggle(String option) => setState(() {
    _selected.contains(option)
        ? _selected.remove(option)
        : _selected.add(option);
    _checked = null;
  });

  void _check() => setState(
    () => _checked =
        _selected.isNotEmpty && _selected.every(lesson.safe.contains),
  );

  Future<void> _finish() async {
    await ref.read(safetyProgressProvider.notifier).complete(lesson);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _checked == true;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kelajak.safety.title'.tr(),
        ),
        dock: GButton(
          label: ok
              ? 'g5.kelajak.safety.finish'.tr()
              : 'g5.kelajak.safety.check'.tr(),
          icon: ok ? GIcons.checkCircle : null,
          onPressed: _selected.isEmpty ? null : (ok ? _finish : _check),
        ),
        children: [
          GGlass(
            glowHue: lesson.hue,
            child: Row(
              children: [
                GTile(icon: lesson.icon, hue: lesson.hue, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('${lesson.key}.question'.tr(), style: GText.h3),
                  ),
                ),
              ],
            ),
          ),
          Text('g5.kelajak.safety.pickAll'.tr(), style: GText.caption),
          for (final option in lesson.options)
            GOption(
              label: '${lesson.key}.$option'.tr(),
              selected: _selected.contains(option),
              showRadio: false,
              leading: GIcon(
                _selected.contains(option)
                    ? GIcons.checkCircle
                    : GIcons.circleDashed,
                size: 22,
                color: _selected.contains(option)
                    ? GColors.primary
                    : GColors.textFaint,
              ),
              onTap: () => _toggle(option),
            ),
          if (_checked != null)
            GNote(
              text: ok
                  ? '${lesson.key}.explain'.tr()
                  : 'g5.kelajak.safety.unsafe'.tr(),
              kind: ok ? GNoteKind.ok : GNoteKind.warn,
              icon: ok ? GIcons.sealCheck : GIcons.warningCircle,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: GLink(
              label: 'g5.kelajak.safety.worried'.tr(),
              onPressed: () => context.push(GrowthV5Routes.family),
            ),
          ),
        ],
      ),
    );
  }
}
