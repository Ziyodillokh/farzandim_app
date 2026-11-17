// F03 · SOS yordami: bola o'zi boshlaydigan, ko'zga tashlanadigan SOS —
// tasdiqlangan oilaga (joylashuv ham boradi, ruxsat bo'lsa). 3 soniya bosib
// turiladi (tasodifan yuborilmasin). Bosqichlar: hali yuborilmadi → xabar
// yetkazildi → ota-ona qabul qildi (faqat haqiqiy tasdiqdan keyin, server
// `sos:resolved`). 2 daqiqada hech kim qabul qilmasa — qayta yuborish.
// Favqulodda xizmatlar chaqirildi deb ko'rsatilmaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/sos/presentation/providers/sos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Javob kutish muddati — keyin qayta yuborish taklif qilinadi.
const kSosAckTimeout = Duration(minutes: 2);
const _holdDuration = Duration(seconds: 3);

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  late final _hold = AnimationController(vsync: this, duration: _holdDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) unawaited(_send());
    });
  StreamSubscription<dynamic>? _resolvedSub;
  Timer? _ackTimer;
  DateTime? _acceptedAt;
  var _noAnswer = false;

  @override
  void initState() {
    super.initState();
    _resolvedSub = ref
        .read(socketClientProvider)
        .eventStream('sos:resolved')
        .listen(_onResolved);
  }

  @override
  void dispose() {
    _hold.dispose();
    _ackTimer?.cancel();
    unawaited(_resolvedSub?.cancel());
    super.dispose();
  }

  void _onResolved(dynamic payload) {
    final id = payload is Map ? payload['id'] : null;
    final mine = ref.read(sosStateProvider).lastAlertId;
    if (id == null || id != mine || !mounted) return;
    _ackTimer?.cancel();
    setState(() {
      _acceptedAt = DateTime.now();
      _noAnswer = false;
    });
  }

  Future<void> _send() async {
    unawaited(HapticFeedback.heavyImpact());
    setState(() {
      _acceptedAt = null;
      _noAnswer = false;
    });
    await ref.read(sosStateProvider.notifier).send();
    _hold.reset();
    if (!mounted) return;
    if (ref.read(sosStateProvider).status == SosStatus.sent) {
      _ackTimer?.cancel();
      _ackTimer = Timer(kSosAckTimeout, () {
        if (mounted && _acceptedAt == null) setState(() => _noAnswer = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paired = ref.watch(pairingStateProvider).childId != null;
    final sos = ref.watch(sosStateProvider);
    final parent = ref.watch(parentNameProvider).valueOrNull;
    final who = (parent == null || parent.trim().isEmpty)
        ? 'g5.oila.parent'.tr()
        : parent.trim();
    final sent = sos.status == SosStatus.sent;
    final failed = sos.status == SosStatus.error;
    final sending = sos.status == SosStatus.sending;
    final accepted = sent && _acceptedAt != null;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.rose,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.oila.sos.title'.tr(),
        ),
        children: [
          if (!paired)
            GNote(
              text: 'g5.oila.noFamily'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.users,
            )
          else ...[
            const SizedBox(height: 8),
            Center(
              child: _HoldButton(
                controller: _hold,
                enabled: !sending && !(sent && !_noAnswer && !accepted),
                label: _noAnswer || failed
                    ? 'g5.oila.sos.again'.tr()
                    : 'g5.oila.sos.send'.tr(),
              ),
            ),
            Text(
              'g5.oila.sos.hold'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            ),
            GGlass(
              child: GSteps(
                items: [
                  GStepItem(
                    title: failed
                        ? 'g5.oila.sos.failed'.tr()
                        : 'g5.oila.sos.notSent'.tr(),
                    state: failed
                        ? GStepState.warn
                        : sent || sending
                        ? GStepState.done
                        : GStepState.now,
                  ),
                  GStepItem(
                    title: 'g5.oila.sos.delivered'.tr(),
                    state: sent
                        ? GStepState.done
                        : sending
                        ? GStepState.now
                        : GStepState.todo,
                  ),
                  GStepItem(
                    title: 'g5.oila.sos.accepted'.tr(namedArgs: {'name': who}),
                    subtitle: accepted
                        ? DateFormat.Hm().format(_acceptedAt!)
                        : null,
                    state: accepted
                        ? GStepState.done
                        : sent
                        ? GStepState.now
                        : GStepState.todo,
                  ),
                ],
              ),
            ),
            if (_noAnswer || failed)
              GNote(
                text: failed
                    ? 'g5.oila.sos.failedHint'.tr()
                    : 'g5.oila.sos.noAnswer'.tr(),
                kind: GNoteKind.warn,
                icon: GIcons.warningCircle,
              ),
            GNote(
              text: 'g5.oila.sos.what'.tr(namedArgs: {'name': who}),
              kind: GNoteKind.plain,
              icon: GIcons.mapPin,
            ),
          ],
        ],
      ),
    );
  }
}

/// 3 soniya bosib turiladigan katta SOS tugmasi (atrofida to'lib boruvchi
/// halqa). Ekran o'quvchida — uzoq bosish bilan.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.controller,
    required this.enabled,
    required this.label,
  });

  final AnimationController controller;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    const size = 196.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: 'g5.oila.sos.hold'.tr(),
      onLongPress: enabled ? () => controller.forward(from: 1) : null,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => controller.forward() : null,
        onLongPressEnd: enabled
            ? (_) {
                if (!controller.isCompleted) controller.reverse();
              }
            : null,
        onLongPressCancel: enabled
            ? () {
                if (!controller.isCompleted) controller.reverse();
              }
            : null,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => CustomPaint(
            painter: GProgressRingPainter(
              controller.value,
              colors: [GHue.rose.icon, GHue.rose.base],
            ),
            child: child,
          ),
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? GHue.rose.base
                      : GHue.rose.base.withValues(alpha: .35),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GIcon(
                          GIcons.siren,
                          size: 40,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: GText.itemTitle.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
