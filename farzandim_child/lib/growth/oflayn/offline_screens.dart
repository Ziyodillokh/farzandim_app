// U10 · Oflayn to'plam (yuklab olish, qurilmadagi mashqlar, yuborish
// navbati) va oflayn mashq: savol → tekshirish (to'plamdagi to'g'ri javob
// va izoh) → natija; urinish navbatga tushadi va internet bo'lganda serverga
// yuboriladi (u yerda qayta baholanadi, DON faqat bir marta).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oflayn/offline_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OfflinePackScreen extends ConsumerStatefulWidget {
  const OfflinePackScreen({super.key});

  @override
  ConsumerState<OfflinePackScreen> createState() => _OfflinePackScreenState();
}

class _OfflinePackScreenState extends ConsumerState<OfflinePackScreen> {
  var _downloading = false;
  var _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Ekran ochilganda navbatdagilar yuborib ko'riladi (internet bo'lsa).
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(quiet: true));
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await ref.read(offlineProvider.notifier).download();
    } on Object {
      if (mounted) _error = 'g5.offline.downloadFailed'.tr();
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _sync({bool quiet = false}) async {
    await ref.read(offlineProvider.future);
    if (!mounted) return;
    setState(() => _syncing = true);
    try {
      await ref.read(offlineProvider.notifier).sync();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineProvider).valueOrNull;
    final pack = state?.pack;
    final now = DateTime.now();
    final usable = pack != null && !pack.isExpired(now);
    final language = context.locale.languageCode;
    final pending = state?.pending ?? const <OfflineAttempt>[];
    final done = [
      for (final a in state?.queue ?? const <OfflineAttempt>[])
        if (a.state != OfflineUploadState.pending) a,
    ];
    String day(DateTime d) =>
        DateFormat('d-MMMM', language).format(d.toLocal());
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.blue,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.offline.title'.tr(),
        ),
        children: [
          GGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const GTile(
                      icon: GIcons.downloadSimple,
                      hue: GHue.sky,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'g5.offline.weekly'.tr(),
                            style: GText.itemTitle,
                          ),
                          Text(
                            pack == null
                                ? 'g5.offline.none'.tr()
                                : 'g5.offline.range'.tr(
                                    namedArgs: {
                                      'from': day(pack.issuedAt),
                                      'to': day(pack.expiresAt),
                                      'v': '${pack.version}',
                                    },
                                  ),
                            style: GText.caption,
                          ),
                        ],
                      ),
                    ),
                    if (usable)
                      GChip(
                        label: 'g5.offline.saved'.tr(),
                        kind: GChipKind.ok,
                        icon: GIcons.checkCircle,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GButton(
                  label: 'g5.offline.download'.tr(),
                  icon: GIcons.downloadSimple,
                  kind: usable ? GButtonKind.ghost : GButtonKind.primary,
                  size: GButtonSize.md,
                  loading: _downloading,
                  onPressed: _downloading ? null : _download,
                ),
              ],
            ),
          ),
          if (_error != null)
            GNote(text: _error!, kind: GNoteKind.warn, icon: GIcons.wifiSlash),
          if (pack != null && !usable)
            GNote(
              text: 'g5.offline.expired'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.clockCountdown,
            ),
          if (usable)
            GList(
              children: [
                for (final set in pack.sets)
                  GListItem(
                    leading: GTile(
                      icon: set.subject.gIcon,
                      hue: set.subject.gHue,
                      size: 44,
                    ),
                    title: set.subject.label,
                    subtitle: 'g5.offline.questions'.tr(
                      namedArgs: {'n': '${set.questions.length}'},
                    ),
                    onTap: () => context.push(
                      GrowthV5Routes.offlinePractice(set.subject.name),
                    ),
                  ),
              ],
            ),
          if (pending.isNotEmpty)
            GSection(
              title: 'g5.offline.queue'.tr(),
              actionLabel: _syncing ? null : 'g5.offline.retry'.tr(),
              onAction: _syncing ? null : _sync,
              child: GList(
                children: [
                  for (final a in pending)
                    GListItem(
                      leading: GTile(
                        icon: a.subject.gIcon,
                        hue: a.subject.gHue,
                        size: 40,
                      ),
                      title: '${a.subject.label} · ${a.correct}/${a.total}',
                      trailing: GChip(
                        label: 'g5.offline.waiting'.tr(),
                        kind: GChipKind.warn,
                      ),
                    ),
                ],
              ),
            ),
          if (done.isNotEmpty)
            GList(
              children: [
                for (final a in done.reversed)
                  GListItem(
                    leading: GTile(
                      icon: a.subject.gIcon,
                      hue: a.subject.gHue,
                      size: 40,
                    ),
                    title: '${a.subject.label} · ${a.correct}/${a.total}',
                    subtitle: a.state == OfflineUploadState.rejected
                        ? 'g5.offline.rejected'.tr()
                        : (a.don ?? 0) > 0
                        ? 'g5.offline.acceptedDon'.tr(
                            namedArgs: {'don': '${a.don}'},
                          )
                        : 'g5.offline.accepted'.tr(),
                  ),
              ],
            ),
          GNote(
            text: 'g5.offline.note'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.info,
          ),
        ],
      ),
    );
  }
}

class OfflinePracticeScreen extends ConsumerStatefulWidget {
  const OfflinePracticeScreen({super.key, required this.subject});

  final String subject;

  @override
  ConsumerState<OfflinePracticeScreen> createState() =>
      _OfflinePracticeScreenState();
}

class _OfflinePracticeScreenState extends ConsumerState<OfflinePracticeScreen> {
  final _answers = <String, int>{};
  var _index = 0;
  int? _selected;
  var _checked = false;
  OfflineAttempt? _result;

  Future<void> _finish(OfflinePack pack, OfflineSet set) async {
    final notifier = ref.read(offlineProvider.notifier);
    final attempt = await notifier.record(
      pack: pack,
      set: set,
      answers: _answers,
    );
    if (!mounted) return;
    setState(() => _result = attempt);
    unawaited(notifier.sync());
  }

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final pack = ref.watch(offlineProvider).valueOrNull?.pack;
    final set = pack?.sets
        .where((s) => s.subject.name == widget.subject)
        .firstOrNull;
    final result = _result;
    if (pack == null || set == null) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: GTopBar(
            leading: GTopBar.close(
              label: 'g5.common.back'.tr(),
              onPressed: () => context.pop(),
            ),
            title: 'g5.offline.title'.tr(),
          ),
          children: [
            GNote(
              text: 'g5.offline.none'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.info,
            ),
          ],
        ),
      );
    }
    final question = set.questions[_index];
    final last = _index == set.questions.length - 1;
    final correct = _selected == question.correctIndex;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.blue,
        top: GTopBar(
          leading: GTopBar.close(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: set.subject.label,
          subtitle: 'g5.offline.mode'.tr(),
        ),
        dock: result != null
            ? GButton(
                label: 'g5.offline.backToPack'.tr(),
                onPressed: () => context.pop(),
              )
            : GButton(
                label: !_checked
                    ? 'g5.offline.check'.tr()
                    : last
                    ? 'g5.offline.finish'.tr()
                    : 'g5.offline.next'.tr(),
                onPressed: _selected == null
                    ? null
                    : () {
                        if (!_checked) {
                          setState(() {
                            _checked = true;
                            _answers[question.id] = _selected!;
                          });
                        } else if (last) {
                          unawaited(_finish(pack, set));
                        } else {
                          setState(() {
                            _index++;
                            _selected = null;
                            _checked = false;
                          });
                        }
                      },
              ),
        children: result != null
            ? [
                const SizedBox(height: 24),
                const Center(
                  child: GTile(
                    icon: GIcons.checkCircle,
                    hue: GHue.green,
                    size: 72,
                  ),
                ),
                Text(
                  'g5.offline.result'.tr(
                    namedArgs: {
                      'correct': '${result.correct}',
                      'total': '${result.total}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: GText.h2,
                ),
                GNote(
                  text: 'g5.offline.queued'.tr(),
                  kind: GNoteKind.plain,
                  icon: GIcons.paperPlaneTilt,
                ),
              ]
            : [
                Text(
                  'g5.offline.progress'.tr(
                    namedArgs: {
                      'n': '${_index + 1}',
                      'total': '${set.questions.length}',
                    },
                  ),
                  style: GText.caption,
                ),
                GProgressBar(
                  value: (_index + (_checked ? 1 : 0)) / set.questions.length,
                  semanticLabel: set.subject.label,
                ),
                GGlass(
                  child: Text(question.prompt.of(language), style: GText.h3),
                ),
                for (final (i, option) in question.options.indexed)
                  GOption(
                    label: option.of(language),
                    selected: _selected == i,
                    onTap: _checked
                        ? () {}
                        : () => setState(() => _selected = i),
                  ),
                if (_checked)
                  GNote(
                    text: [
                      if (correct)
                        'g5.offline.right'.tr()
                      else
                        'g5.offline.wrong'.tr(
                          namedArgs: {
                            'answer': question.options[question.correctIndex]
                                .of(language),
                          },
                        ),
                      if (question.explanation != null)
                        question.explanation!.of(language),
                    ].join(' '),
                    kind: correct ? GNoteKind.ok : GNoteKind.warn,
                    icon: correct ? GIcons.checkCircle : GIcons.info,
                  ),
              ],
      ),
    );
  }
}
