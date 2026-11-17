// H03 · Anonim savol → H09 · So'rov yakunlandi.
//
// Bitta savol, oldindan tanlanmagan variantlar (1..5 server shkalasi),
// «Keyingi savol» javob tanlanmaguncha yopiq, «O'tkazib yuborish» doim ochiq —
// o'tkazilgan savol yuborilmaydi (0 deb hisoblanmaydi). Javoblar faqat
// xotirada; «Rahmat!» faqat server qabul qilgandan keyin.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Phase { questions, sending, done, failed, already }

class VoiceSurveyScreen extends ConsumerStatefulWidget {
  const VoiceSurveyScreen({super.key});

  @override
  ConsumerState<VoiceSurveyScreen> createState() => _VoiceSurveyScreenState();
}

class _VoiceSurveyScreenState extends ConsumerState<VoiceSurveyScreen> {
  /// Ochilgan so'rov — yangilanish paytida ham savollar almashmasin.
  VoiceSurvey? _survey;
  var _index = 0;
  var _answers = <String, int>{};
  var _phase = _Phase.questions;
  var _needOne = false;

  VoiceQuestion get _question => _survey!.questions[_index];
  bool get _isLast => _index >= _survey!.questions.length - 1;

  void _choose(int value) {
    HapticFeedback.selectionClick();
    setState(() {
      _answers = {..._answers, _question.id: value};
      _needOne = false;
    });
  }

  void _advance({required bool skip}) {
    if (skip) {
      setState(() {
        _answers = {
          for (final e in _answers.entries)
            if (e.key != _question.id) e.key: e.value,
        };
      });
    }
    if (_isLast) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _finish() async {
    final survey = _survey!;
    if (_answers.isEmpty) {
      setState(() => _needOne = true);
      return;
    }
    setState(() => _phase = _Phase.sending);
    try {
      await ref.read(voiceRepositoryProvider).submitSurvey(survey.id, _answers);
      ref.invalidate(voiceSurveyProvider);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        // Javoblar yuborildi — xotirada ham qolmasin.
        _answers = const {};
      });
    } on SchoolException catch (e) {
      if (!mounted) return;
      setState(
        () => _phase = e.code == SchoolErrorCode.alreadyAnswered
            ? _Phase.already
            : _Phase.failed,
      );
    }
  }

  Future<void> _close() async {
    if (_answers.isEmpty || _phase != _Phase.questions) {
      context.pop();
      return;
    }
    final leave = await showGSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('g5.voice.survey.exitTitle'.tr(), style: GText.h2),
          ),
          const SizedBox(height: 6),
          Text('g5.voice.survey.exitBody'.tr(), style: GText.body),
          const SizedBox(height: 16),
          GButton(
            label: 'g5.voice.survey.stay'.tr(),
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
          const SizedBox(height: 10),
          GButton(
            label: 'g5.voice.survey.exit'.tr(),
            kind: GButtonKind.ghost,
            size: GButtonSize.second,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(voiceSurveyProvider);
    _survey ??= async.valueOrNull?.survey;
    final survey = _survey;
    if (_phase == _Phase.done) return const _DoneView();
    if (survey == null) {
      final state = async.valueOrNull;
      return _Shell(
        onClose: () => context.pop(),
        children: [
          if (async.isLoading)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else
            GNote(
              text: state?.answered == true
                  ? 'g5.voice.survey.already'.tr()
                  : 'g5.voice.intro.noneBody'.tr(),
              kind: GNoteKind.plain,
            ),
        ],
      );
    }
    if (_phase == _Phase.already) {
      return _Shell(
        onClose: () => context.pop(),
        children: [
          GNote(text: 'g5.voice.survey.already'.tr(), kind: GNoteKind.plain),
        ],
      );
    }
    final selected = _answers[_question.id];
    final total = survey.questions.length;
    final sending = _phase == _Phase.sending;
    return PopScope(
      canPop: _answers.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: _Shell(
        onClose: _close,
        progress: (_index + 1) / total,
        progressLabel: 'g5.voice.survey.progress'.tr(
          namedArgs: {'n': '${_index + 1}', 'total': '$total'},
        ),
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_phase == _Phase.failed) ...[
              GNote(
                text:
                    '${'g5.voice.survey.failed'.tr()}. ${'g5.voice.survey.failedBody'.tr()}',
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
                  ? 'g5.voice.survey.retry'.tr()
                  : (_isLast
                            ? 'g5.voice.survey.finish'
                            : 'g5.voice.survey.next')
                        .tr(),
              loading: sending,
              trailingIcon: _isLast ? null : GIcons.arrowRight,
              onPressed: _phase == _Phase.failed
                  ? _finish
                  : (selected == null || sending
                        ? null
                        : () => _advance(skip: false)),
            ),
            const SizedBox(height: 8),
            GButton(
              label: 'g5.voice.survey.skip'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              onPressed: sending ? null : () => _advance(skip: true),
            ),
          ],
        ),
        children: [
          Semantics(header: true, child: Text(_question.text, style: GText.h2)),
          Column(
            children: [
              for (var v = kVoiceScoreMin; v <= kVoiceScoreMax; v++) ...[
                if (v > kVoiceScoreMin) const SizedBox(height: 10),
                GOption(
                  label: 'g5.voice.scale.$v'.tr(),
                  selected: selected == v,
                  onTap: sending ? null : () => _choose(v),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Savol ekrani qobig'i: «Yopish», progress va dock.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.onClose,
    required this.children,
    this.progress,
    this.progressLabel,
    this.dock,
  });

  final VoidCallback onClose;
  final List<Widget> children;
  final double? progress;
  final String? progressLabel;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GTopBar(
              leading: GTopBar.close(
                label: 'g5.voice.survey.close'.tr(),
                onPressed: onClose,
              ),
              title: 'g5.voice.intro.title'.tr(),
              subtitle: progressLabel,
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              GProgressBar(value: progress!, semanticLabel: progressLabel),
            ],
          ],
        ),
        dock: dock,
        children: children,
      ),
    );
  }
}

/// H09 · So'rov yakunlandi (server qabul qilgandan keyin). Orqaga tugmasi
/// yo'q; shaxsiy yordam — alohida karta, javoblar unga ko'chirilmaydi.
class _DoneView extends StatelessWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(GrowthV5Routes.school);
      },
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.teal,
          dock: GButton(
            label: 'g5.voice.survey.back'.tr(),
            kind: GButtonKind.ghost,
            onPressed: () => context.go(GrowthV5Routes.school),
          ),
          children: [
            const SizedBox(height: 32),
            const Center(
              child: GTile(icon: GIcons.checkCircle, hue: GHue.green, size: 72),
            ),
            Semantics(
              header: true,
              child: Text(
                'g5.voice.survey.thanks'.tr(),
                textAlign: TextAlign.center,
                style: GText.display(32),
              ),
            ),
            Text(
              'g5.voice.survey.saved'.tr(),
              textAlign: TextAlign.center,
              style: GText.body,
            ),
            const SizedBox(height: 8),
            GGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const GTile(
                        icon: GIcons.handHeart,
                        hue: GHue.sky,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'g5.voice.survey.talkTitle'.tr(),
                              style: GText.itemTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'g5.voice.survey.talkBody'.tr(),
                              style: GText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GButton(
                    label: 'g5.voice.survey.talkButton'.tr(),
                    size: GButtonSize.md,
                    onPressed: () => GrowthLinks.psychologist(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
