// A07 · Ulanish holati va A08 · Sinfni tuzatish. Ikki mustaqil slot —
// o'quvchi va ota-ona. O'quvchi tasdiqlanmaguncha maktab nomi
// ko'rsatilmaydi; tasdiqlangach maktab va sinf «To'g'rimi?» bilan. Tuzatish
// so'ralganda tekshiruv tugaguncha maktab bo'limi yopiq.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final linkStatusProvider = FutureProvider.autoDispose<LinkStatus>(
  (ref) => ref.watch(kirishRepositoryProvider).linkStatus(),
);

class KirishLinkStatusScreen extends ConsumerWidget {
  const KirishLinkStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(linkStatusProvider);
    final status = async.valueOrNull;
    final confirmed = status?.student == StudentLinkState.confirmed;
    final studentChip = switch (status?.student) {
      StudentLinkState.confirmed => (
        'g5.kirish.status.confirmed'.tr(),
        GChipKind.ok,
      ),
      StudentLinkState.underReview => (
        'g5.kirish.status.underReview'.tr(),
        GChipKind.info,
      ),
      StudentLinkState.correction => (
        'g5.kirish.status.correction'.tr(),
        GChipKind.warn,
      ),
      _ => ('g5.kirish.status.none'.tr(), GChipKind.neutral),
    };
    final parentChip = switch (status?.parent) {
      ParentLinkState.confirmed => (
        'g5.kirish.status.confirmed'.tr(),
        GChipKind.ok,
      ),
      ParentLinkState.pending => (
        'g5.kirish.status.pending'.tr(),
        GChipKind.info,
      ),
      ParentLinkState.underReview => (
        'g5.kirish.status.underReview'.tr(),
        GChipKind.info,
      ),
      ParentLinkState.expired => (
        'g5.kirish.status.expired'.tr(),
        GChipKind.warn,
      ),
      _ => ('g5.kirish.status.none'.tr(), GChipKind.neutral),
    };
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.close(
            label: 'g5.kirish.status.close'.tr(),
            onPressed: () => leaveKirish(context, ref),
          ),
          title: 'g5.kirish.status.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(linkStatusProvider),
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (confirmed) ...[
              GButton(
                label: 'g5.kirish.status.toSchool'.tr(),
                icon: GIcons.backpack,
                onPressed: () =>
                    leaveKirish(context, ref, target: GrowthV5Routes.school),
              ),
              const SizedBox(height: 8),
              GButton(
                label: 'g5.kirish.status.fix'.tr(),
                kind: GButtonKind.ghost,
                size: GButtonSize.second,
                onPressed: () => context.push(
                  kirishPath(context, GrowthV5Routes.kirishCorrection),
                ),
              ),
            ] else
              GButton(
                label: 'g5.kirish.status.practice'.tr(),
                onPressed: () =>
                    leaveKirish(context, ref, target: GrowthV5Routes.learn),
              ),
            if (confirmed)
              Center(
                child: GLink(
                  label: 'g5.kirish.status.practice'.tr(),
                  onPressed: () =>
                      leaveKirish(context, ref, target: GrowthV5Routes.learn),
                ),
              ),
          ],
        ),
        children: [
          if (async.isLoading && status == null)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (status == null)
            GNote(
              text: 'g5.kirish.login.network'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(linkStatusProvider),
              ),
            )
          else ...[
            _Slot(
              icon: GIcons.student,
              hue: GHue.blue,
              title: 'g5.kirish.status.student'.tr(),
              chip: studentChip,
              body: switch (status.student) {
                StudentLinkState.confirmed =>
                  '${[status.schoolName, status.className].nonNulls.join(' · ')}\n${'g5.kirish.status.check'.tr()}',
                StudentLinkState.underReview =>
                  'g5.kirish.status.reviewBody'.tr(),
                StudentLinkState.correction =>
                  'g5.kirish.status.correctionBody'.tr(),
                StudentLinkState.none => null,
              },
            ),
            _Slot(
              icon: GIcons.users,
              hue: GHue.rose,
              title: 'g5.kirish.status.parent'.tr(),
              chip: parentChip,
              body: switch (status.parent) {
                ParentLinkState.confirmed => null,
                ParentLinkState.underReview =>
                  'g5.kirish.status.parentReviewBody'.tr(),
                _ => 'g5.kirish.status.parentBody'.tr(),
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.icon,
    required this.hue,
    required this.title,
    required this.chip,
    this.body,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final (String, GChipKind) chip;
  final String? body;

  @override
  Widget build(BuildContext context) => GGlass(
    child: MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GTile(icon: icon, hue: hue, size: 40),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: GText.itemTitle)),
              GChip(label: chip.$1, kind: chip.$2),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(body!, style: GText.body),
          ],
        ],
      ),
    ),
  );
}

enum _SendState { idle, sending, received, failed }

class KirishCorrectionScreen extends ConsumerStatefulWidget {
  const KirishCorrectionScreen({super.key});

  @override
  ConsumerState<KirishCorrectionScreen> createState() =>
      _KirishCorrectionScreenState();
}

class _KirishCorrectionScreenState
    extends ConsumerState<KirishCorrectionScreen> {
  final _note = TextEditingController();

  /// Qayta yuborishda ikkinchi so'rov ochilmasin — bir xil id.
  final _requestId = newRequestId();
  var _state = _SendState.idle;
  var _tooMany = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _state = _SendState.sending);
    try {
      await ref
          .read(kirishRepositoryProvider)
          .requestCorrection(note: _note.text, clientRequestId: _requestId);
      ref.invalidate(linkStatusProvider);
      if (mounted) setState(() => _state = _SendState.received);
    } on KirishException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _SendState.failed;
        _tooMany = e.error == KirishError.rateLimited;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final received = _state == _SendState.received;
    final sending = _state == _SendState.sending;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kirish.correction.title'.tr(),
        ),
        dock: received
            ? GButton(
                label: 'g5.kirish.correction.back'.tr(),
                onPressed: () => context.pop(),
              )
            : GButton(
                label: switch (_state) {
                  _SendState.sending => 'g5.kirish.correction.sending'.tr(),
                  _SendState.failed => 'g5.kirish.correction.retry'.tr(),
                  _ => 'g5.kirish.correction.submit'.tr(),
                },
                loading: sending,
                onPressed: sending ? null : _send,
              ),
        children: [
          GOption(
            label: 'g5.kirish.correction.reason'.tr(),
            selected: true,
            onTap: null,
          ),
          GTextField(
            label: 'g5.kirish.correction.note'.tr(),
            hint: 'g5.kirish.correction.noteHint'.tr(),
            controller: _note,
            multiline: true,
            maxLength: 300,
            enabled: !sending && !received,
          ),
          GNote(
            text: 'g5.kirish.correction.warning'.tr(),
            kind: GNoteKind.warn,
            icon: GIcons.lockKey,
          ),
          if (received)
            GNote(
              text:
                  '${'g5.kirish.correction.received'.tr()}. ${'g5.kirish.correction.receivedBody'.tr()}',
              kind: GNoteKind.ok,
              icon: GIcons.checkCircle,
            ),
          if (_state == _SendState.failed)
            GNote(
              text: _tooMany
                  ? 'g5.kirish.correction.tooMany'.tr()
                  : 'g5.kirish.correction.failed'.tr(),
              kind: GNoteKind.warn,
              icon: _tooMany ? GIcons.hourglassMedium : GIcons.wifiSlash,
            ),
        ],
      ),
    );
  }
}
