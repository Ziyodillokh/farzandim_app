// 3-qurilma kirish so'rovi — "ruxsat so'rash" + tasdiqni kutish (poll).
//
// Login 2-qurilma limitiga tushganda bu ekranga o'tiladi (pendingToken bilan).
// Ruxsat so'rash → 2 qurilmaga push → tasdiq + slot bo'shashini kutadi →
// APPROVED + tokenlar kelsa avtomatik kiradi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/data/repositories/backend_session_access_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Phase { intro, waiting, waitingSlot, rejected, expired, error }

class SessionAccessRequestScreen extends ConsumerStatefulWidget {
  const SessionAccessRequestScreen({required this.pendingToken, super.key});

  final String pendingToken;

  @override
  ConsumerState<SessionAccessRequestScreen> createState() =>
      _SessionAccessRequestScreenState();
}

class _SessionAccessRequestScreenState
    extends ConsumerState<SessionAccessRequestScreen> {
  _Phase _phase = _Phase.intro;
  bool _busy = false;
  String? _requestId;
  String? _pollToken;
  int _pollSec = 3;
  Timer? _timer;
  bool _polling = false;
  String _error = '';

  BackendSessionAccessRepository get _repo =>
      ref.read(backendSessionAccessRepositoryProvider);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await _repo.requestAccess(widget.pendingToken);
      if (!mounted) return;
      setState(() {
        _requestId = r.requestId;
        _pollToken = r.pollToken;
        _pollSec = r.pollIntervalSec;
        _phase = _Phase.waiting;
        _busy = false;
      });
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phase = _Phase.error;
        _error = 'auth.sessionAccess.requestFailed'.tr();
      });
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _pollSec.clamp(2, 10)),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    if (_polling || _requestId == null || _pollToken == null) return;
    _polling = true;
    try {
      final res = await _repo.pollStatus(_requestId!, _pollToken!);
      if (!mounted) return;
      switch (res.status) {
        case SessionAccessStatus.pending:
          break;
        case SessionAccessStatus.approvedWaitingSlot:
          if (_phase != _Phase.waitingSlot) {
            setState(() => _phase = _Phase.waitingSlot);
          }
        case SessionAccessStatus.approvedReady:
          _timer?.cancel();
          final s = res.session!;
          await ref
              .read(backendAuthProvider.notifier)
              .onLoggedIn(s.tokens, s.user);
          if (!mounted) return;
          context.go(AppRoutes.dashboard);
          return;
        case SessionAccessStatus.rejected:
          _timer?.cancel();
          setState(() => _phase = _Phase.rejected);
        case SessionAccessStatus.expired:
          _timer?.cancel();
          setState(() => _phase = _Phase.expired);
      }
    } catch (_) {
      // Tarmoq xatosi — keyingi poll'da qayta urinadi.
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: Center(child: ParvozTopGlow()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(alignment: Alignment.centerLeft, child: _backButton()),
                  const Spacer(),
                  _content(),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => GestureDetector(
    onTap: () => context.pop(),
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    ),
  );

  Widget _content() {
    switch (_phase) {
      case _Phase.intro:
        return _card(
          icon: Icons.devices_rounded,
          iconColor: ParvozColors.blue,
          title: 'auth.sessionAccess.intro.title'.tr(),
          body: 'auth.sessionAccess.intro.body'.tr(),
          button: ParvozPrimaryButton(
            label: 'auth.sessionAccess.intro.requestButton'.tr(),
            loading: _busy,
            onPressed: _request,
          ),
        );
      case _Phase.waiting:
        return _card(
          icon: Icons.notifications_active_rounded,
          iconColor: ParvozColors.blue,
          title: 'auth.sessionAccess.waiting.title'.tr(),
          body: 'auth.sessionAccess.waiting.body'.tr(),
          showSpinner: true,
        );
      case _Phase.waitingSlot:
        return _card(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF22C55E),
          title: 'auth.sessionAccess.waitingSlot.title'.tr(),
          body:
              'Endi ulangan qurilmalardan biri chiqarilishini kuting. '
              'Chiqarilishi bilan avtomatik kirasiz.',
          showSpinner: true,
        );
      case _Phase.rejected:
        return _card(
          icon: Icons.cancel_rounded,
          iconColor: const Color(0xFFFF453A),
          title: 'auth.sessionAccess.rejected.title'.tr(),
          body: 'auth.sessionAccess.rejected.body'.tr(),
          button: ParvozPrimaryButton(
            label: 'common.back'.tr(),
            showArrow: false,
            onPressed: () => context.pop(),
          ),
        );
      case _Phase.expired:
        return _card(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFFF2B233),
          title: 'auth.sessionAccess.expired.title'.tr(),
          body: 'auth.sessionAccess.expired.body'.tr(),
          button: ParvozPrimaryButton(
            label: 'auth.sessionAccess.expired.retry'.tr(),
            showArrow: false,
            onPressed: () => context.pop(),
          ),
        );
      case _Phase.error:
        return _card(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFF2B233),
          title: 'common.error'.tr(),
          body: _error,
          button: ParvozPrimaryButton(
            label: 'common.retry'.tr(),
            showArrow: false,
            onPressed: () => setState(() => _phase = _Phase.intro),
          ),
        );
    }
  }

  Widget _card({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    Widget? button,
    bool showSpinner = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withValues(alpha: 0.14),
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 44),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        if (showSpinner) ...[
          const SizedBox(height: 28),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: ParvozColors.blue,
              strokeWidth: 2.6,
            ),
          ),
        ],
        if (button != null) ...[const SizedBox(height: 32), button],
      ],
    );
  }
}
