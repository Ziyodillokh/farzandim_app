// ─────────────────────────────────────────────────────────────────────
// PairWaitingScreen — Parent tasdiqini kutish (Backend 0.6.0)
// ─────────────────────────────────────────────────────────────────────
//
// Bola POST /auth/child-pair → 409 AWAITING_PARENT_CONFIRM olgandan keyin
// shu ekran ko'rsatiladi. Har 3 sek GET /child-pair-status/:id polling.
// Status:
//   PENDING  → kutamiz, countdown ko'rsatamiz
//   APPROVED → JWT saqlangan, dashboard'ga
//   REJECTED → error UI + qaytishga taklif
//   EXPIRED  → error UI + qaytishga taklif

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/pairing/data/repositories/pairing_repository.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PairWaitingScreen extends ConsumerStatefulWidget {
  const PairWaitingScreen({super.key});

  @override
  ConsumerState<PairWaitingScreen> createState() =>
      _PairWaitingScreenState();
}

class _PairWaitingScreenState extends ConsumerState<PairWaitingScreen> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Duration _left = const Duration(minutes: 5);
  bool _polling = false;
  String? _result; // 'REJECTED' | 'EXPIRED' | error message

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPolling();
      _startCountdown();
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final exp = ref
          .read(pairingStateProvider)
          .pairRequestExpiresAt;
      if (exp == null) return;
      final diff = exp.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _left = diff.isNegative ? Duration.zero : diff;
      });
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_poll()),
    );
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    final state = ref.read(pairingStateProvider);
    final pairRequestId = state.pairRequestId;
    if (pairRequestId == null) {
      _polling = false;
      return;
    }

    final result = await ref
        .read(pairingRepositoryProvider)
        .checkPairStatus(pairRequestId);
    if (!mounted) {
      _polling = false;
      return;
    }

    switch (result) {
      case PairStatusPending():
        // Kutamiz, hech narsa qilmaymiz.
        break;
      case PairStatusApproved(
            :final parentUid,
            :final childId,
            :final currentUserId,
          ):
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        await ref
            .read(pairingStateProvider.notifier)
            .completeFromApprovedPair(
              parentUid: parentUid,
              childId: childId,
              currentUserId: currentUserId,
            );
        if (!mounted) return;
        // Pair tasdiqlangach markaziy /splash router'ga — birinchi marta
        // bo'lsa onboarding (qiziqishlar), keyin permission/dashboard.
        context.go('/splash');
      case PairStatusRejected():
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() => _result = 'REJECTED');
        }
      case PairStatusExpired():
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() => _result = 'EXPIRED');
        }
      case PairStatusError(:final message):
        // Tarmoq xato — keyingi polling'da qayta urinamiz.
        debugPrint('PairWaiting polling xato: $message');
    }
    _polling = false;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatLeft(Duration d) {
    if (d <= Duration.zero) return '0:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _backToPairing() {
    ref.read(pairingStateProvider.notifier).resetToNotPaired();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isError = _result != null;
    final accent = isError ? AppColors.error : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isError
                    ? Icon(
                        _result == 'REJECTED'
                            ? AppIcons.block
                            : AppIcons.scheduleActive,
                        color: accent,
                        size: 56,
                      )
                    : const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
              ),
              const SizedBox(height: 32),
              Text(
                _titleFor(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _subtitleFor(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isError) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AppIcons.scheduleActive,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Qolgan vaqt: ${_formatLeft(_left)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (isError)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _backToPairing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Qaytadan urinish',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _backToPairing,
                  child: const Text(
                    'Bekor qilish',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor() {
    if (_result == 'REJECTED') return 'Rad etildi';
    if (_result == 'EXPIRED') return 'Muddat tugadi';
    return "Ota-onangiz tasdiqini kutmoqdamiz";
  }

  String _subtitleFor() {
    if (_result == 'REJECTED') {
      return 'Ota-onangiz ulanish so\'rovingizni rad etdi.\n'
          "Yangi kod kiriting yoki ota-onangiz bilan bog'laning.";
    }
    if (_result == 'EXPIRED') {
      return '5 daqiqa ichida tasdiq olinmadi.\n'
          'Qaytadan urinib ko\'ring.';
    }
    return 'Ota-onangiz Parent App\'da bildirishnomani ko\'rib '
        'tasdiqlashi kerak. Bu ekran avtomatik yangilanadi.';
  }
}
