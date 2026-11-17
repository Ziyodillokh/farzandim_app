// H10 · Mutaxassis tayinlagan shaxsiy so'rov. Anonim monitoringdan alohida:
// kim tayinlagani, javoblarni kim ko'rishi, o'tkazish va chiqish aniq.
// Tashxis, ball yoki mukofot yo'q — bolaga natija qaytmaydi. Yakunlangach
// suhbatni kelishish uchun H04 ga qaytiladi.
//
// Vaqtli yoki xotira savolli testlar bu ekranga kelmaydi (mavjud test
// ekranida yechiladi — `needsLegacyRunner`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Phase { intro, questions, sending, done, failed }

class VoicePersonalScreen extends ConsumerStatefulWidget {
  const VoicePersonalScreen({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  ConsumerState<VoicePersonalScreen> createState() =>
      _VoicePersonalScreenState();
}

class _VoicePersonalScreenState extends ConsumerState<VoicePersonalScreen> {
  var _phase = _Phase.intro;
  var _index = 0;
  var _answers = <String, PsychAnswer>{};
  var _needOne = false;

  void _set(PsychItem item, PsychAnswer? answer) {
    HapticFeedback.selectionClick();
    setState(() {
      _needOne = false;
      _answers = {
        for (final e in _answers.entries)
          if (e.key != item.id) e.key: e.value,
        if (answer != null) item.id: answer,
      };
    });
  }

  void _toggle(PsychMultiItem item, String key) {
    final current = switch (_answers[item.id]) {
      PsychMultiAnswer(:final keys) => keys.toSet(),
      _ => <String>{},
    };
    if (!current.remove(key)) {
      if (current.length >= kMaxMultiChoices) return;
      current.add(key);
    }
    _set(item, current.isEmpty ? null : PsychMultiAnswer(current));
  }

  void _advance(PsychTest test, {required bool skip}) {
    final item = test.items[_index];
    if (skip) _set(item, null);
    if (_index >= test.items.length - 1) {
      _submit(test);
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _submit(PsychTest test) async {
    if (_answers.isEmpty) {
      setState(() => _needOne = true);
      return;
    }
    setState(() => _phase = _Phase.sending);
    try {
      await ref
          .read(schoolRepositoryProvider)
          .submitPsychTest(test, answers: _answers);
      ref.invalidate(psychAssignmentsProvider);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _answers = const {};
      });
    } on SchoolException {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(psychTestProvider(widget.assignmentId));
    final test = async.valueOrNull;
    final summary =
        (ref.watch(psychAssignmentsProvider).valueOrNull ??
                const <PsychAssignmentSummary>[])
            .where((a) => a.assignmentId == widget.assignmentId)
            .firstOrNull;
    final exit = GTopBar.close(
      label: 'g5.voice.personal.exit'.tr(),
      onPressed: () => context.pop(),
    );
    if (_phase == _Phase.done) {
      return _frame(
        top: GTopBar(title: 'g5.voice.personal.title'.tr()),
        dock: GButton(
          label: 'g5.voice.personal.toHelp'.tr(),
          onPressed: () => context.pop(),
        ),
        children: [
          const SizedBox(height: 24),
          const Center(
            child: GTile(icon: GIcons.checkCircle, hue: GHue.green, size: 72),
          ),
          Text(
            'g5.voice.personal.done'.tr(),
            textAlign: TextAlign.center,
            style: GText.h2,
          ),
          Text(
            'g5.voice.personal.doneBody'.tr(),
            textAlign: TextAlign.center,
            style: GText.body,
          ),
        ],
      );
    }
    if (test == null) {
      return _frame(
        top: GTopBar(leading: exit, title: 'g5.voice.personal.title'.tr()),
        children: [
          if (async.isLoading)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else
            GNote(
              text: 'g5.voice.personal.closedNow'.tr(),
              kind: GNoteKind.plain,
            ),
        ],
      );
    }
    if (_phase == _Phase.intro) return _intro(test, summary, exit);
    return _question(test, exit);
  }

  Widget _intro(PsychTest test, PsychAssignmentSummary? summary, Widget exit) {
    final by = summary?.assignedByName;
    final minutes =
        summary?.estimatedMinutes ??
        (test.items.length * 30 / 60).ceil().clamp(1, 60);
    return _frame(
      top: GTopBar(leading: exit, title: 'g5.voice.personal.title'.tr()),
      dock: GButton(
        label: 'g5.voice.personal.start'.tr(),
        trailingIcon: GIcons.arrowRight,
        onPressed: () => setState(() => _phase = _Phase.questions),
      ),
      children: [
        GGlass(
          kind: GGlassKind.feat,
          glowHue: GHue.teal,
          child: Row(
            children: [
              const GTile(icon: GIcons.clipboardText, hue: GHue.teal, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.title.isEmpty
                          ? 'g5.voice.personal.title'.tr()
                          : test.title,
                      style: GText.h3,
                    ),
                    if (by != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'g5.voice.personal.by'.tr(namedArgs: {'name': by}),
                        style: GText.caption,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'g5.voice.personal.meta'.tr(
                        namedArgs: {
                          'count': '${test.items.length}',
                          'min': '$minutes',
                        },
                      ),
                      style: GText.onest(
                        13,
                        weight: FontWeight.w600,
                        color: GColors.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GNote(
          text: 'g5.voice.personal.whoSees'.tr(),
          kind: GNoteKind.info,
          icon: GIcons.lockKey,
        ),
        GNote(text: 'g5.voice.personal.skipNote'.tr(), kind: GNoteKind.plain),
        GNote(
          text: 'g5.voice.personal.noScore'.tr(),
          kind: GNoteKind.plain,
          icon: GIcons.shieldCheck,
        ),
      ],
    );
  }

  Widget _question(PsychTest test, Widget exit) {
    final item = test.items[_index];
    final total = test.items.length;
    final answer = _answers[item.id];
    final last = _index >= total - 1;
    final sending = _phase == _Phase.sending;
    final progress = 'g5.voice.survey.progress'.tr(
      namedArgs: {'n': '${_index + 1}', 'total': '$total'},
    );
    return _frame(
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GTopBar(
            leading: exit,
            title: 'g5.voice.personal.title'.tr(),
            subtitle: progress,
          ),
          const SizedBox(height: 12),
          GProgressBar(value: (_index + 1) / total, semanticLabel: progress),
        ],
      ),
      dock: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_phase == _Phase.failed) ...[
            GNote(
              text: 'g5.voice.personal.failed'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
            ),
            const SizedBox(height: 10),
          ],
          if (_needOne) ...[
            GNote(text: 'g5.voice.survey.needOne'.tr(), kind: GNoteKind.warn),
            const SizedBox(height: 10),
          ],
          GButton(
            label: _phase == _Phase.failed
                ? 'g5.voice.personal.retry'.tr()
                : (last ? 'g5.voice.personal.finish' : 'g5.voice.personal.next')
                      .tr(),
            loading: sending,
            trailingIcon: last ? null : GIcons.arrowRight,
            onPressed: _phase == _Phase.failed
                ? () => _submit(test)
                : (answer == null || sending
                      ? null
                      : () => _advance(test, skip: false)),
          ),
          const SizedBox(height: 8),
          GButton(
            label: 'g5.voice.personal.skip'.tr(),
            kind: GButtonKind.ghost,
            size: GButtonSize.second,
            onPressed: sending ? null : () => _advance(test, skip: true),
          ),
        ],
      ),
      children: [
        Semantics(header: true, child: Text(item.text, style: GText.h2)),
        if (item is PsychMultiItem)
          Text('g5.voice.personal.multiHint'.tr(), style: GText.caption),
        Column(
          children: [
            for (final (i, option) in _options(item).indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              GOption(
                label: option.label,
                selected: option.isSelected(answer),
                onTap: sending
                    ? null
                    : () => switch (item) {
                        PsychMultiItem() => _toggle(item, option.key),
                        PsychLikertItem() => _set(
                          item,
                          PsychLikertAnswer(int.parse(option.key)),
                        ),
                        PsychSingleItem() => _set(
                          item,
                          PsychSingleAnswer(option.key),
                        ),
                      },
              ),
            ],
          ],
        ),
      ],
    );
  }

  List<_Choice> _options(PsychItem item) => switch (item) {
    PsychLikertItem() => [
      for (var v = kLikertMin; v <= kLikertMax; v++)
        _Choice('$v', 'g5.voice.likert.$v'.tr()),
    ],
    PsychSingleItem(:final options) || PsychMultiItem(:final options) => [
      for (final o in options) _Choice(o.key, o.text),
    ],
  };

  Widget _frame({
    required Widget top,
    required List<Widget> children,
    Widget? dock,
  }) => Scaffold(
    backgroundColor: GColors.bg,
    body: GScreen(
      theme: GBgTheme.teal,
      top: top,
      dock: dock,
      children: children,
    ),
  );
}

class _Choice {
  const _Choice(this.key, this.label);

  final String key;
  final String label;

  bool isSelected(PsychAnswer? answer) => switch (answer) {
    PsychLikertAnswer(:final value) => '$value' == key,
    PsychSingleAnswer(key: final k) => k == key,
    PsychMultiAnswer(:final keys) => keys.contains(key),
    null => false,
  };
}
