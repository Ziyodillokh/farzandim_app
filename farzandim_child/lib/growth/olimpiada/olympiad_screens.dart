// U17 · Olimpiada (ro'yxat va kengaytirilgan karta), U18 · musobaqa savoli
// (taymer, yordamchi va tinglash yo'q, javob darhol saqlanadi, vaqt tugasa
// avtomatik topshiriladi) va U19 · kvitansiya (nechta javob saqlangani va
// natija sanasi; mukofot va'da qilinmaydi). Bolalarning ochiq reytingi yo'q.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:farzandim_child/growth/olimpiada/olympiad_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _date(BuildContext context, DateTime at) =>
    DateFormat('d-MMMM', context.locale.languageCode).format(at);

String _dateTime(BuildContext context, DateTime at) =>
    DateFormat('d-MMMM, HH:mm', context.locale.languageCode).format(at);

// ── U17 ────────────────────────────────────────────────────────────────

class OlympiadListScreen extends ConsumerStatefulWidget {
  const OlympiadListScreen({super.key});

  @override
  ConsumerState<OlympiadListScreen> createState() => _OlympiadListScreenState();
}

class _OlympiadListScreenState extends ConsumerState<OlympiadListScreen> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(olympiadsProvider);
    final items = [...?async.valueOrNull]
      ..sort(
        (a, b) => a.phase.index == b.phase.index
            ? a.startTime.compareTo(b.startTime)
            : _order(a.phase).compareTo(_order(b.phase)),
      );
    final open = _open ?? items.firstOrNull?.id;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.olympiad.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(olympiadsProvider),
        children: [
          if (async.hasError && items.isEmpty)
            GNote(
              text: 'g5.olympiad.loadFailed'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
            )
          else if (!async.isLoading && items.isEmpty)
            GNote(
              text: 'g5.olympiad.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.trophy,
            ),
          for (final o in items)
            o.id == open
                ? _Expanded(olympiad: o)
                : GList(
                    children: [
                      GListItem(
                        leading: const GTile(
                          icon: GIcons.trophy,
                          hue: GHue.gold,
                          size: 44,
                        ),
                        title: o.title,
                        subtitle: _phaseText(context, o),
                        onTap: () => setState(() => _open = o.id),
                      ),
                    ],
                  ),
          Text('g5.olympiad.noRanking'.tr(), style: GText.caption),
        ],
      ),
    );
  }

  static int _order(OlympiadPhase p) => switch (p) {
    OlympiadPhase.active => 0,
    OlympiadPhase.scheduled => 1,
    OlympiadPhase.finished => 2,
  };
}

String _phaseText(BuildContext context, Olympiad o) => switch (o.phase) {
  OlympiadPhase.active => 'g5.olympiad.activeUntil'.tr(
    namedArgs: {'date': _date(context, o.endTime)},
  ),
  OlympiadPhase.scheduled => 'g5.olympiad.startsAt'.tr(
    namedArgs: {'date': _date(context, o.startTime)},
  ),
  OlympiadPhase.finished => 'g5.olympiad.finished'.tr(),
};

class _Expanded extends StatelessWidget {
  const _Expanded({required this.olympiad});

  final Olympiad olympiad;

  @override
  Widget build(BuildContext context) {
    final o = olympiad;
    return GGlass(
      glowHue: GHue.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GTile(icon: GIcons.trophy, hue: GHue.gold, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(o.title, style: GText.h3),
                    ),
                    const SizedBox(height: 4),
                    GChip(
                      label: _phaseText(context, o),
                      kind: o.phase == OlympiadPhase.active
                          ? GChipKind.ok
                          : GChipKind.neutral,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            [
              if (o.subject.isNotEmpty) o.subject,
              if (o.ageFrom != null && o.ageTo != null)
                'g5.olympiad.ages'.tr(
                  namedArgs: {'from': '${o.ageFrom}', 'to': '${o.ageTo}'},
                ),
              'g5.olympiad.format'.tr(
                namedArgs: {
                  'minutes': '${o.durationMin}',
                  'count': '${o.questionCount}',
                },
              ),
            ].join(' · '),
            style: GText.body,
          ),
          if (o.description != null) ...[
            const SizedBox(height: 6),
            Text(o.description!, style: GText.caption),
          ],
          const SizedBox(height: 12),
          Text('g5.olympiad.rules'.tr(), style: GText.itemTitle),
          const SizedBox(height: 4),
          Text('g5.olympiad.rulesBody'.tr(), style: GText.body),
          const SizedBox(height: 14),
          switch (o.phase) {
            OlympiadPhase.active => GButton(
              label: 'g5.olympiad.join'.tr(),
              icon: GIcons.play,
              size: GButtonSize.md,
              onPressed: () =>
                  context.push(GrowthV5Routes.olympiadRun(o.id), extra: o),
            ),
            OlympiadPhase.scheduled => GNote(
              text: 'g5.olympiad.startsAt'.tr(
                namedArgs: {'date': _dateTime(context, o.startTime)},
              ),
              kind: GNoteKind.plain,
              icon: GIcons.calendarBlank,
            ),
            OlympiadPhase.finished => GButton(
              label: 'g5.olympiad.myResult'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.md,
              onPressed: () => context.push(GrowthV5Routes.attempts),
            ),
          },
        ],
      ),
    );
  }
}

// ── U18 ────────────────────────────────────────────────────────────────

class OlympiadRunScreen extends ConsumerStatefulWidget {
  const OlympiadRunScreen({super.key, required this.olympiad});

  final Olympiad olympiad;

  @override
  ConsumerState<OlympiadRunScreen> createState() => _OlympiadRunScreenState();
}

class _OlympiadRunScreenState extends ConsumerState<OlympiadRunScreen> {
  OlympiadAttempt? _attempt;
  List<OlympiadQuestion> _questions = const [];
  Map<String, int> _answers = {};
  OlympiadProgressStore? _store;
  var _index = 0;
  int? _selected;
  var _busy = false;
  var _finishing = false;
  String? _error;
  Timer? _tick;
  DateTime? _deadline;

  Olympiad get olympiad => widget.olympiad;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(olympiadRepositoryProvider);
    final childId = ref.read(currentChildIdProvider);
    try {
      final attempt = await repo.start(olympiad.id);
      if (attempt.finished) return _finish(skipConfirm: true);
      final questions = await repo.questions(olympiad.id);
      final store = childId == null ? null : OlympiadProgressStore(childId);
      final answers = await store?.load(attempt.id) ?? {};
      if (!mounted) return;
      final byTime = attempt.startedAt.add(
        Duration(minutes: olympiad.durationMin),
      );
      setState(() {
        _attempt = attempt;
        _questions = questions;
        _answers = answers;
        _store = store;
        _deadline = byTime.isBefore(olympiad.endTime)
            ? byTime
            : olympiad.endTime;
        _index = _firstUnanswered();
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } on OlympiadException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.network
              ? 'g5.olympiad.network'.tr()
              : 'g5.olympiad.cantStart'.tr(),
        );
      }
    }
  }

  int _firstUnanswered() {
    final i = _questions.indexWhere((q) => !_answers.containsKey(q.id));
    return i < 0 ? _questions.length - 1 : i;
  }

  void _onTick() {
    if (!mounted) return;
    final left = _deadline?.difference(DateTime.now());
    if (left != null && left <= Duration.zero) {
      _tick?.cancel();
      unawaited(_finish(skipConfirm: true));
      return;
    }
    setState(() {});
  }

  Future<void> _next() async {
    final attempt = _attempt;
    final selected = _selected;
    if (attempt == null || selected == null || _busy) return;
    final question = _questions[_index];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_answers.containsKey(question.id)) {
        await ref
            .read(olympiadRepositoryProvider)
            .answer(
              attemptId: attempt.id,
              questionId: question.id,
              selectedIndex: selected,
            );
      }
      final answers = {..._answers, question.id: selected};
      await _store?.save(attempt.id, answers);
      if (!mounted) return;
      final last = answers.length >= _questions.length;
      setState(() {
        _answers = answers;
        _selected = null;
        _busy = false;
        if (!last) _index = _firstUnanswered();
      });
      if (last) await _finish(skipConfirm: true);
    } on OlympiadException catch (e) {
      if (!mounted) return;
      if (e.timeUp) {
        await _finish(skipConfirm: true);
        return;
      }
      setState(() {
        _busy = false;
        _error = 'g5.olympiad.notSaved'.tr();
      });
    }
  }

  Future<void> _finish({bool skipConfirm = false}) async {
    if (_finishing) return;
    final attempt = _attempt;
    final left = _questions.length - _answers.length;
    if (!skipConfirm && left > 0) {
      final ok = await showGSheet<bool>(
        context,
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('g5.olympiad.finishTitle'.tr(), style: GText.h2),
            ),
            const SizedBox(height: 6),
            Text(
              'g5.olympiad.finishBody'.tr(namedArgs: {'n': '$left'}),
              style: GText.body,
            ),
            const SizedBox(height: 16),
            GButton(
              label: 'g5.olympiad.finish'.tr(),
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: 10),
            GButton(
              label: 'g5.olympiad.continue'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _finishing = true;
    _tick?.cancel();
    final repo = ref.read(olympiadRepositoryProvider);
    OlympiadReceipt receipt;
    try {
      receipt = attempt == null
          ? OlympiadReceipt(
              saved: _answers.length,
              total: olympiad.questionCount,
            )
          : await repo.finish(attempt.id, total: _questions.length);
      if (attempt != null) await _store?.clear(attempt.id);
    } on OlympiadException {
      // Javoblar serverda allaqachon saqlangan — kvitansiya qurilmadagi
      // ma'lumot bilan; urinish vaqt tugaganda server tomonidan yopiladi.
      receipt = OlympiadReceipt(
        saved: _answers.length,
        total: _questions.length,
        resultsAt: olympiad.endTime,
      );
    }
    if (!mounted) return;
    context.pushReplacement(
      GrowthV5Routes.olympiadDone,
      extra: (olympiad, receipt),
    );
  }

  String _clock(Duration left) {
    final m = left.inMinutes;
    final s = left.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _attempt != null && _questions.isNotEmpty;
    final question = ready ? _questions[_index] : null;
    final left = _deadline?.difference(DateTime.now());
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.close(
            label: 'g5.olympiad.close'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.olympiad.title'.tr(),
          subtitle: left == null
              ? null
              : 'g5.olympiad.timeLeft'.tr(
                  namedArgs: {
                    'time': _clock(left.isNegative ? Duration.zero : left),
                  },
                ),
        ),
        dock: !ready
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GButton(
                    label: 'g5.olympiad.next'.tr(),
                    icon: GIcons.arrowRight,
                    loading: _busy,
                    onPressed: _selected == null || _busy ? null : _next,
                  ),
                  const SizedBox(height: 8),
                  GButton(
                    label: 'g5.olympiad.finish'.tr(),
                    kind: GButtonKind.ghost,
                    size: GButtonSize.second,
                    onPressed: _busy ? null : _finish,
                  ),
                ],
              ),
        children: [
          if (_error != null)
            GNote(
              text: _error!,
              kind: GNoteKind.warn,
              icon: GIcons.warningCircle,
            ),
          if (question == null && _error == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          if (question != null) ...[
            Text(
              'g5.olympiad.progress'.tr(
                namedArgs: {
                  'n': '${_index + 1}',
                  'total': '${_questions.length}',
                },
              ),
              style: GText.caption,
            ),
            GProgressBar(
              value: _answers.length / _questions.length,
              semanticLabel: 'g5.olympiad.title'.tr(),
            ),
            GGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (question.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        question.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(question.text, style: GText.h3),
                ],
              ),
            ),
            for (final (i, option) in question.options.indexed)
              GOption(
                label: option,
                selected: _selected == i,
                onTap: _busy ? () {} : () => setState(() => _selected = i),
              ),
            Text('g5.olympiad.autosave'.tr(), style: GText.caption),
          ],
        ],
      ),
    );
  }
}

// ── U19 ────────────────────────────────────────────────────────────────

class OlympiadDoneScreen extends StatelessWidget {
  const OlympiadDoneScreen({
    super.key,
    required this.olympiad,
    required this.receipt,
  });

  final Olympiad olympiad;
  final OlympiadReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final resultsAt = receipt.resultsAt ?? olympiad.endTime;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.gold,
          dock: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GButton(
                label: 'g5.olympiad.results'.tr(),
                onPressed: () => context.go(GrowthV5Routes.attempts),
              ),
              const SizedBox(height: 8),
              GButton(
                label: 'g5.olympiad.backToLearn'.tr(),
                kind: GButtonKind.ghost,
                size: GButtonSize.second,
                onPressed: () => context.go(GrowthV5Routes.learn),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 32),
            const Center(
              child: GTile(icon: GIcons.sealCheck, hue: GHue.green, size: 72),
            ),
            Semantics(
              header: true,
              child: Text(
                'g5.olympiad.submitted'.tr(),
                textAlign: TextAlign.center,
                style: GText.h2,
              ),
            ),
            Text(
              olympiad.title,
              textAlign: TextAlign.center,
              style: GText.body,
            ),
            GGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'g5.olympiad.saved'.tr(
                      namedArgs: {
                        'saved': '${receipt.saved}',
                        'total': '${receipt.total}',
                      },
                    ),
                    style: GText.itemTitle,
                  ),
                  if (receipt.finishedAt != null)
                    Text(
                      _dateTime(context, receipt.finishedAt!),
                      style: GText.caption,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'g5.olympiad.announce'.tr(
                      namedArgs: {'date': _date(context, resultsAt)},
                    ),
                    style: GText.body,
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
