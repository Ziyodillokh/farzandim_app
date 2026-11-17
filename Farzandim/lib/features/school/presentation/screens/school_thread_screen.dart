// ─────────────────────────────────────────────────────────────────────
// SchoolThreadScreen — maktab xodimi bilan yozishma
// ─────────────────────────────────────────────────────────────────────
//
// Chat ko'rinishi: kun ajratgichlari, mavzu yorlig'i (shablon bilan
// boshlangan xabarda), o'z xabarida "yuborildi / o'qildi". Ochilganda
// xodim javoblari o'qilgan bo'ladi. Xodim endi kontakt bo'lmasa (faol
// emas, sinfdan olingan) — yozish o'chiriladi. Push `SCHOOL_PARENT_MESSAGE`
// shu sahifani ochadi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class SchoolThreadScreen extends ConsumerStatefulWidget {
  const SchoolThreadScreen({required this.threadId, super.key});

  final String threadId;

  @override
  ConsumerState<SchoolThreadScreen> createState() => _SchoolThreadScreenState();
}

class _SchoolThreadScreenState extends ConsumerState<SchoolThreadScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  /// Yuborilgandan keyingi holat (server javobi) — qayta yuklashni kutmaydi.
  SchoolThread? _latest;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<SchoolThread>>(
      schoolThreadProvider(widget.threadId),
      (_, next) {
        final thread = next.valueOrNull;
        if (thread == null) return;
        _latest = null;
        unawaited(ref.read(schoolConnectActionsProvider).markRead(thread));
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(SchoolThread thread) async {
    final text = _input.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final next = await ref
          .read(schoolConnectActionsProvider)
          .send(thread: thread, body: text);
      if (!mounted) return;
      _input.clear();
      setState(() {
        _latest = next;
        _sending = false;
      });
    } on SchoolFailure catch (failure) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.error(context, failure.messageKey.tr());
      if (failure.shouldRefresh) {
        ref.invalidate(schoolThreadProvider(widget.threadId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolThreadProvider(widget.threadId));
    final thread = _latest ?? async.valueOrNull;
    final Widget content;
    if (thread != null) {
      content = Column(
        children: [
          _Header(thread: thread),
          Expanded(child: _Messages(thread: thread)),
          _InputBar(
            controller: _input,
            sending: _sending,
            available: thread.available,
            onSend: () => _send(thread),
          ),
        ],
      );
    } else if (async.hasError) {
      content = Column(
        children: [
          SchoolHeader(title: 'school.connect.title'.tr()),
          Expanded(
            child: SchoolErrorView(
              error: SchoolFailure.fromError(async.error!),
              onRetry: () =>
                  ref.invalidate(schoolThreadProvider(widget.threadId)),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        children: [
          SchoolHeader(title: 'school.connect.title'.tr()),
          const Expanded(child: SchoolLoadingView()),
        ],
      );
    }
    return Scaffold(
      backgroundColor: SK.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: content),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.thread});

  final SchoolThread thread;

  @override
  Widget build(BuildContext context) {
    final staff = thread.staff;
    final color = roleColor(staff.role);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SK.hairline)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'common.back'.tr(),
            child: GestureDetector(
              onTap: () => schoolBack(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: SK.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SK.border),
                ),
                child: const Icon(
                  SolarIconsOutline.arrowLeft,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SkAvatar(name: staff.fullName, color: color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skText(15.5, w: FontWeight.w600, height: 1.3),
                ),
                Text(
                  '${staff.role.labelKey.tr()} · ${thread.student.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skText(12.5, c: SK.dim, height: 1.35),
                ),
              ],
            ),
          ),
          if (staff.role == StaffRole.psychologist)
            const Icon(SolarIconsBold.lockKeyhole, size: 18, color: SK.green),
        ],
      ),
    );
  }
}

/// Xabarlar (yangisi pastda) va kun ajratgichlari.
class _Messages extends StatelessWidget {
  const _Messages({required this.thread});

  final SchoolThread thread;

  @override
  Widget build(BuildContext context) {
    final messages = thread.messages;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'school.connect.threadEmpty'.tr(),
          style: skText(14, c: SK.dim),
        ),
      );
    }
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final m in messages) {
      final at = m.createdAt;
      if (at != null) {
        final day = DateTime(at.year, at.month, at.day);
        if (lastDay == null || day != lastDay) {
          rows.add(_DaySeparator(day: day));
          lastDay = day;
        }
      }
      rows.add(_Bubble(message: m, staffName: thread.staff.fullName));
    }
    if (thread.resolved) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(
            child: SkTag(
              label: 'school.connect.resolved'.tr(),
              color: SK.green,
              icon: SolarIconsBold.checkCircle,
            ),
          ),
        ),
      );
    }
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      children: rows.reversed.toList(growable: false),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'school.announcements.group.today'.tr()
        : day == today.subtract(const Duration(days: 1))
        ? 'school.announcements.group.yesterday'.tr()
        : formatSchoolDate(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: SK.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: SK.hairline),
          ),
          child: Text(label, style: skText(11.5, c: SK.dim, height: 1.3)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.staffName});

  final ThreadMessage message;
  final String staffName;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final at = message.createdAt;
    final topic = message.topic;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(mine ? 20 : 6),
      bottomRight: Radius.circular(mine ? 6 : 20),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (topic != null && topic != ContactTopic.other) ...[
                SkTag(
                  label: topic.titleKey.tr(),
                  color: topicColor(topic),
                  icon: topicIcon(topic),
                ),
                const SizedBox(height: 6),
              ],
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: mine ? null : SK.cardHi,
                  gradient: mine
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2F7BFF), SK.blue],
                        )
                      : null,
                  border: mine ? null : Border.all(color: SK.border),
                ),
                child: SelectableText(
                  message.body,
                  style: skText(14.5, height: 1.45),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (at != null)
                    Text(
                      formatSchoolTime(at),
                      style: skText(11, c: SK.faint, height: 1.2),
                    ),
                  if (mine) ...[
                    const SizedBox(width: 5),
                    Icon(
                      message.seen
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: message.seen ? SK.sky : SK.faint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      (message.seen
                              ? 'school.connect.seen'
                              : 'school.connect.delivered')
                          .tr(),
                      style: skText(
                        11,
                        c: message.seen ? SK.sky : SK.faint,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.available,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool available;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (!available) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        decoration: const BoxDecoration(
          color: SK.sheet,
          border: Border(top: BorderSide(color: SK.hairline)),
        ),
        child: Text(
          'school.connect.unavailable'.tr(),
          textAlign: TextAlign.center,
          style: skText(13, c: SK.dim),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: SK.sheet,
        border: Border(top: BorderSide(color: SK.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: SK.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: SK.border),
              ),
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 5,
                maxLength: kParentMessageMax,
                textCapitalization: TextCapitalization.sentences,
                style: skText(14.5),
                cursorColor: SK.sky,
                decoration: InputDecoration(
                  hintText: 'school.connect.placeholder'.tr(),
                  hintStyle: skText(14.5, c: SK.faint),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final enabled = !sending && value.text.trim().isNotEmpty;
              return Semantics(
                button: true,
                label: 'school.connect.send'.tr(),
                child: GestureDetector(
                  onTap: enabled ? onSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled ? SK.blue : SK.card,
                      border: Border.all(color: enabled ? SK.blue : SK.border),
                    ),
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            SolarIconsBold.plain,
                            size: 22,
                            color: enabled ? Colors.white : SK.faint,
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
