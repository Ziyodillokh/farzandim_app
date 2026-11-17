// H07 · Murojaat holati va H08 · Psixolog bilan muloqot.
//
// Holat kartasi faqat sodir bo'lgan hodisalarni vaqt bilan ko'rsatadi:
// qurilma navbati (hali yuborilmadi) → qabul qilindi → psixolog ochmagan /
// ko'rib chiqmoqda → javob. Javob kelgach yozishma va javob yozish maydoni
// ochiladi. Yozishma faqat xotirada (qurilmaga yozilmaydi); yuborilmagan
// xabar «Yuborilmadi · qayta urinish» bilan qoladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_outbox.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:farzandim_child/growth/ovoz/voice_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String _at(DateTime at) => '${localizedDayMonth(at)}, ${voiceClock(at)}';

class VoiceRequestScreen extends ConsumerWidget {
  const VoiceRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(voiceOutboxProvider);
    final pending = outbox.valueOrNull
        ?.where((p) => p.id == requestId)
        .firstOrNull;
    if (pending != null) return _PendingView(pending: pending);
    if (outbox.isLoading) return const _Loading();
    return _ServerView(requestId: requestId);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GColors.bg,
    body: GScreen(
      theme: GBgTheme.teal,
      top: GTopBar(
        leading: GTopBar.back(
          label: 'g5.common.back'.tr(),
          onPressed: () => context.pop(),
        ),
        title: 'g5.voice.list.title'.tr(),
      ),
      children: [
        Text(
          'g5.common.loading'.tr(),
          textAlign: TextAlign.center,
          style: GText.caption,
        ),
      ],
    ),
  );
}

/// H07 boshlang'ich holati: murojaat qurilmada, internet yo'q.
class _PendingView extends ConsumerStatefulWidget {
  const _PendingView({required this.pending});

  final PendingVoiceRequest pending;

  @override
  ConsumerState<_PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends ConsumerState<_PendingView> {
  var _sending = false;

  Future<void> _retry() async {
    setState(() => _sending = true);
    try {
      final request = await ref
          .read(voiceOutboxProvider.notifier)
          .send(widget.pending.id);
      if (!mounted) return;
      GrowthLinks.voiceRequest(context, request.id, replace: true);
    } on SchoolException {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = ref.watch(voiceContactProvider).valueOrNull;
    final hours = contact?.hours;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: voiceRequestTitle(widget.pending.createdAt),
        ),
        dock: GButton(
          label: 'g5.voice.status.back'.tr(),
          kind: GButtonKind.ghost,
          onPressed: () => context.pop(),
        ),
        children: [
          GGlass(
            kind: GGlassKind.feat,
            glowHue: GHue.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const GTile(
                      icon: GIcons.wifiSlash,
                      hue: GHue.gold,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('g5.voice.status.notSent'.tr(), style: GText.h3),
                          const SizedBox(height: 4),
                          Text(
                            'g5.voice.status.notSentBody'.tr(),
                            style: GText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GButton(
                  label: _sending
                      ? 'g5.voice.status.sending'.tr()
                      : 'g5.voice.status.retry'.tr(),
                  icon: GIcons.arrowClockwise,
                  size: GButtonSize.md,
                  loading: _sending,
                  onPressed: _sending ? null : _retry,
                ),
              ],
            ),
          ),
          if (widget.pending.urgent) const _UrgentAdvice(),
          GGlass(
            child: GSteps(
              items: [
                GStepItem(
                  title: 'g5.voice.status.received'.tr(),
                  subtitle: 'g5.voice.status.waiting'.tr(),
                ),
                GStepItem(
                  title: 'g5.voice.status.notOpened'.tr(),
                  subtitle: hours == null
                      ? null
                      : 'g5.voice.status.hoursSub'.tr(
                          namedArgs: {'start': hours.start, 'end': hours.end},
                        ),
                ),
                GStepItem(
                  title: 'g5.voice.status.reply'.tr(),
                  subtitle: 'g5.voice.status.replyNone'.tr(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentAdvice extends StatelessWidget {
  const _UrgentAdvice();

  @override
  Widget build(BuildContext context) => GNote(
    text: 'g5.voice.status.urgentAdvice'.tr(),
    kind: GNoteKind.sos,
    icon: GIcons.warningCircle,
    action: GLink(
      label: 'g5.today.sos'.tr(),
      onPressed: () => GrowthLinks.sos(context),
    ),
  );
}

/// Yuborilmagan (yoki yuborilayotgan) bola xabari.
class _LocalMessage {
  const _LocalMessage({
    required this.id,
    required this.text,
    this.failed = false,
  });

  final String id;
  final String text;
  final bool failed;
}

class _ServerView extends ConsumerStatefulWidget {
  const _ServerView({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_ServerView> createState() => _ServerViewState();
}

class _ServerViewState extends ConsumerState<_ServerView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  var _local = <_LocalMessage>[];
  var _lastCount = 0;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send({String? retryId}) async {
    final retry = retryId == null
        ? null
        : _local.where((m) => m.id == retryId).firstOrNull;
    final text = retry?.text ?? _text.text.trim();
    if (text.isEmpty) return;
    final id = retry?.id ?? newRequestId();
    setState(() {
      _local = [
        ..._local.where((m) => m.id != id),
        _LocalMessage(id: id, text: text),
      ];
      if (retry == null) _text.clear();
    });
    try {
      final message = await ref
          .read(voiceRepositoryProvider)
          .sendMessage(
            requestId: widget.requestId,
            text: text,
            clientMessageId: id,
          );
      if (!mounted) return;
      setState(() => _local = _local.where((m) => m.id != id).toList());
      ref.invalidate(voiceRequestProvider(widget.requestId));
      // Server ro'yxati yangilanguncha xabar yo'qolib qolmasin.
      _pendingEcho = message;
    } on SchoolException catch (e) {
      if (!mounted) return;
      if (e.code == SchoolErrorCode.alreadyAnswered) {
        // Murojaat yopilgan — holat yangilanadi.
        setState(() => _local = _local.where((m) => m.id != id).toList());
        ref.invalidate(voiceRequestProvider(widget.requestId));
        return;
      }
      setState(
        () => _local = [
          for (final m in _local)
            m.id == id ? _LocalMessage(id: id, text: text, failed: true) : m,
        ],
      );
    }
  }

  VoiceMessage? _pendingEcho;

  void _scrollToEndSoon(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(voiceRequestProvider(widget.requestId));
    var request = async.valueOrNull;
    final echo = _pendingEcho;
    if (request != null && echo != null) {
      if (request.messages.any((m) => m.id == echo.id)) {
        _pendingEcho = null;
      } else {
        request = request.withMessage(echo);
      }
    }
    final contact = ref.watch(voiceContactProvider).valueOrNull;
    final back = GTopBar.back(
      label: 'g5.common.back'.tr(),
      onPressed: () => context.pop(),
    );
    if (request == null) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.teal,
          top: GTopBar(leading: back, title: 'g5.voice.list.title'.tr()),
          onRefresh: () async =>
              ref.invalidate(voiceRequestProvider(widget.requestId)),
          children: [
            if (async.isLoading)
              Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              )
            else
              GNote(
                text: 'g5.school.loadError'.tr(),
                kind: GNoteKind.warn,
                icon: GIcons.wifiSlash,
                action: GLink(
                  label: 'g5.common.retry'.tr(),
                  onPressed: () =>
                      ref.invalidate(voiceRequestProvider(widget.requestId)),
                ),
              ),
          ],
        ),
      );
    }
    final staff = request.messages.where((m) => !m.fromChild).toList();
    final chat = staff.isNotEmpty;
    final closed = request.stage == VoiceStage.closed;
    final handler =
        request.handlerName ??
        voicePsychologistName(contact ?? VoiceContact.unknown);
    _scrollToEndSoon(request.messages.length + _local.length);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        controller: _scroll,
        top: GTopBar(
          leading: back,
          title: chat ? handler : voiceRequestTitle(request.createdAt),
          subtitle: chat
              ? (request.handlerIsDeputy
                        ? 'g5.voice.help.deputyRole'
                        : 'g5.voice.help.role')
                    .tr()
              : null,
        ),
        onRefresh: () async =>
            ref.invalidate(voiceRequestProvider(widget.requestId)),
        dock: closed
            ? GButton(
                label: 'g5.voice.list.newRequest'.tr(),
                icon: GIcons.chatCircleText,
                onPressed: () => GrowthLinks.voiceCompose(context),
              )
            : chat
            ? _Composer(controller: _text, onSend: _send)
            : GButton(
                label: 'g5.voice.status.back'.tr(),
                kind: GButtonKind.ghost,
                onPressed: () => context.pop(),
              ),
        children: [
          if (!chat) ...[
            if (request.urgent && request.stage == VoiceStage.received)
              const _UrgentAdvice(),
            GGlass(child: GSteps(items: _steps(request, contact))),
          ] else
            Text(
              'g5.voice.thread.replyAt'.tr(
                namedArgs: {
                  'date': localizedDayMonth(staff.first.createdAt),
                  'time': voiceClock(staff.first.createdAt),
                },
              ),
              textAlign: TextAlign.center,
              style: GText.caption,
            ),
          if (request.handlerIsDeputy && request.handlerName != null)
            GNote(
              text: 'g5.voice.status.deputy'.tr(
                namedArgs: {'name': request.handlerName!},
              ),
              kind: GNoteKind.info,
            ),
          if (request.meetingAt != null)
            GNote(
              text: 'g5.voice.status.meeting'.tr(
                namedArgs: {
                  'date': localizedDayMonth(request.meetingAt!),
                  'time': voiceClock(request.meetingAt!),
                },
              ),
              kind: GNoteKind.ok,
              icon: GIcons.calendarDots,
            ),
          if (chat) ...[
            for (final m in request.messages)
              _Bubble(
                text: m.text,
                mine: m.fromChild,
                meta: voiceClock(m.createdAt),
                semanticAuthor: m.fromChild
                    ? 'g5.voice.thread.you'.tr()
                    : (m.authorName ?? handler),
              ),
            for (final m in _local)
              _Bubble(
                text: m.text,
                mine: true,
                meta: m.failed
                    ? 'g5.voice.thread.unsent'.tr()
                    : 'g5.voice.status.sending'.tr(),
                failed: m.failed,
                semanticAuthor: 'g5.voice.thread.you'.tr(),
                onRetry: m.failed ? () => _send(retryId: m.id) : null,
              ),
          ],
          if (closed)
            GNote(text: 'g5.voice.thread.closed'.tr(), kind: GNoteKind.plain),
        ],
      ),
    );
  }

  List<GStepItem> _steps(VoiceRequest r, VoiceContact? contact) {
    final hours = contact?.hours;
    final opened = r.openedAt;
    return [
      GStepItem(
        title: 'g5.voice.status.received'.tr(),
        subtitle: _at(r.createdAt),
        state: GStepState.done,
        stateLabel: 'g5.voice.status.done'.tr(),
      ),
      if (opened == null)
        GStepItem(
          title: 'g5.voice.status.notOpened'.tr(),
          subtitle: hours == null
              ? null
              : 'g5.voice.status.hoursSub'.tr(
                  namedArgs: {'start': hours.start, 'end': hours.end},
                ),
          state: GStepState.now,
          stateLabel: 'g5.voice.status.now'.tr(),
        )
      else
        GStepItem(
          title: 'g5.voice.status.reviewing'.tr(),
          subtitle: _at(opened),
          state: GStepState.now,
          stateLabel: 'g5.voice.status.now'.tr(),
        ),
      // Eski murojaatda yozishma matni berilmaydi — javob vaqti baribir ko'rinadi.
      if (r.repliedAt != null)
        GStepItem(
          title: 'g5.voice.status.replied'.tr(),
          subtitle: _at(r.repliedAt!),
          state: GStepState.done,
          stateLabel: 'g5.voice.status.done'.tr(),
        )
      else
        GStepItem(
          title: 'g5.voice.status.reply'.tr(),
          subtitle: 'g5.voice.status.replyNone'.tr(),
        ),
      if (r.resolvedAt != null)
        GStepItem(
          title: 'g5.voice.status.closed'.tr(),
          subtitle: _at(r.resolvedAt!),
          state: GStepState.done,
          stateLabel: 'g5.voice.status.done'.tr(),
        ),
    ];
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.meta,
    required this.semanticAuthor,
    this.failed = false,
    this.onRetry,
  });

  final String text;
  final bool mine;
  final String meta;
  final String semanticAuthor;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bubble = Semantics(
      label: semanticAuthor,
      child: GBubble(
        mine: mine,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text),
            const SizedBox(height: 4),
            Text(
              meta,
              style: GText.onest(
                12,
                color: failed ? GColors.warning : GColors.textFaint,
                weight: failed ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    if (onRetry == null) return bubble;
    return GPressable(onTap: onRetry, pressedScale: .98, child: bubble);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: GColors.fieldFill,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: GColors.fieldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: kVoiceMessageMaxLength,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: GColors.link,
                style: GText.onest(15, color: GColors.text, height: 1.4),
                decoration: InputDecoration.collapsed(
                  hintText: 'g5.voice.thread.hint'.tr(),
                  hintStyle: GText.onest(15, color: GColors.textFaint),
                ).copyWith(counterText: ''),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GPressable(
            onTap: onSend,
            semanticLabel: 'g5.voice.thread.send'.tr(),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: GEffects.primaryGradient,
              ),
              child: const GIcon(
                GIcons.paperPlaneRight,
                size: 20,
                color: GColors.white,
                secondaryOpacity: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
