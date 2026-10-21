// ─────────────────────────────────────────────────────────────────────
// IqTestScreen — IQ test yechish (`/iq/test`)
// ─────────────────────────────────────────────────────────────────────
//
// Savollar bittadan: matritsa + 6 ta variant. Javob darhol serverda
// saqlanadi — chiqib ketib, 24 soat ichida davom ettirish mumkin (tasdiq
// so'ralmaydi). Vaqt cheklanmagan. Oxirgi savolda hamma javob berilgan
// bo'lsa "Yakunlash"; natija shu sahifada.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/iq/data/iq_repository.dart';
import 'package:farzandim_child/features/iq/domain/iq_models.dart';
import 'package:farzandim_child/features/iq/presentation/iq_display.dart';
import 'package:farzandim_child/features/iq/presentation/providers/iq_test_provider.dart';
import 'package:farzandim_child/features/iq/presentation/widgets/iq_matrix.dart';
import 'package:farzandim_child/features/iq/presentation/widgets/iq_result_card.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class IqTestScreen extends ConsumerWidget {
  const IqTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(iqTestProvider);
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: SafeArea(
          child: state.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: HomeColors.primary),
            ),
            error: (error, _) => _ErrorView(
              error: error is IqException ? error : null,
              onRetry: () => ref.invalidate(iqTestProvider),
            ),
            data: (s) => s.session.isOpen
                ? _Runner(state: s)
                : _Done(session: s.session),
          ),
        ),
      ),
    );
  }
}

class _Runner extends ConsumerWidget {
  const _Runner({required this.state});

  final IqRunState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(iqTestProvider.notifier);
    final s = state;
    final total = s.session.items.length;
    final answered = s.session.answeredCount;
    final error = s.error;
    return Column(
      children: [
        _TopBar(index: s.index, total: total, answered: answered),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                'iq.test.prompt'.tr(),
                textAlign: TextAlign.center,
                style: homeText(15, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              IqMatrixGrid(svg: s.current.gridSvg),
              const SizedBox(height: 16),
              IqOptions(
                options: s.current.options,
                selected: s.current.choice,
                onSelect: s.isCompleting
                    ? null
                    : (key) => unawaited(notifier.select(key)),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  iqErrorText(error),
                  textAlign: TextAlign.center,
                  style: homeText(12.5, color: HomeColors.amber),
                ),
              ],
            ],
          ),
        ),
        _BottomBar(state: s, notifier: notifier),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.total,
    required this.answered,
  });

  final int index;
  final int total;
  final int answered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'common.close'.tr(),
            onPressed: () => closeIqPage(context),
            icon: const Icon(Icons.close_rounded, color: HomeColors.chevron),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : answered / total,
                minHeight: 6,
                color: HomeColors.primary,
                backgroundColor: HomeColors.ringTrack,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'iq.test.position'.tr(
              namedArgs: {'n': '${index + 1}', 'total': '$total'},
            ),
            style: homeText(13, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.notifier});

  final IqRunState state;
  final IqTestNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final firstMissing = s.session.items.indexWhere((i) => i.choice == null);
    final Widget primary;
    if (!s.isLast) {
      primary = KelajakPillButton(
        label: 'iq.test.next'.tr(),
        icon: SolarIconsOutline.arrowRight,
        onTap: s.current.choice == null
            ? null
            : () => notifier.goTo(s.index + 1),
      );
    } else if (firstMissing >= 0) {
      primary = KelajakPillButton(
        label: 'iq.test.toMissing'.tr(),
        onTap: () => notifier.goTo(firstMissing),
      );
    } else {
      primary = KelajakPillButton(
        label: s.isCompleting
            ? 'iq.test.finishing'.tr()
            : 'iq.test.finish'.tr(),
        icon: SolarIconsOutline.checkCircle,
        onTap: s.isCompleting ? null : () => unawaited(notifier.complete()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          if (!s.isFirst) ...[
            KelajakPillButton(
              label: 'common.back'.tr(),
              isPrimary: false,
              onTap: s.isCompleting ? null : () => notifier.goTo(s.index - 1),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: primary),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.session});

  final IqSession session;

  @override
  Widget build(BuildContext context) {
    final result = session.result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Text(
          'iq.test.doneTitle'.tr(),
          textAlign: TextAlign.center,
          style: homeText(22, weight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (result != null)
          IqResultCard(result: result)
        else
          KelajakNote('iq.error.sessionClosed'.tr(), align: TextAlign.center),
        const SizedBox(height: 20),
        KelajakPillButton(
          label: 'iq.test.done'.tr(),
          onTap: () => closeIqPage(context),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final IqException? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final code = error?.code ?? IqErrorCode.unknown;
    final next = error?.nextAvailableAt;
    final canRetry = code == IqErrorCode.network || code == IqErrorCode.unknown;
    final text = code == IqErrorCode.retakeTooSoon && next != null
        ? 'iq.hub.nextAt'.tr(namedArgs: {'date': iqDate(context, next)})
        : iqErrorText(code);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: homeText(15, color: HomeColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (canRetry) ...[
            KelajakPillButton(label: 'common.retry'.tr(), onTap: onRetry),
            const SizedBox(height: 10),
          ],
          KelajakPillButton(
            label: 'common.close'.tr(),
            isPrimary: false,
            onTap: () => closeIqPage(context),
          ),
        ],
      ),
    );
  }
}
