// ─────────────────────────────────────────────────────────────────────
// PairingScreen — bola 5 raqamli oila kodini kiritadi
// ─────────────────────────────────────────────────────────────────────
//
// 5 ta alohida TextField — har biriga 1 raqam.
// Avtomatik:
//   - Raqam kiritilsa → keyingi box'ga fokus
//   - Backspace bosilsa (bo'sh box) → oldingi box'ga fokus
//   - 5-chi raqam kiritilgach → avto-pairing boshlanadi
//
// Pairing muvaffaqiyatli → /permissions ga.
// Xato → SnackBar + box'lar tozalanadi + 1-chi box'ga fokus.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final List<TextEditingController> _controllers =
      List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  bool _isPairing = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _isFull => _code.length == 5;

  /// 5-raqam to'lganda avtomatik chaqiriladi.
  Future<void> _onCodeComplete() async {
    if (!_isFull) return;

    setState(() => _isPairing = true);
    FocusScope.of(context).unfocus();

    final success =
        await ref.read(pairingStateProvider.notifier).tryPair(_code);

    if (!mounted) return;

    setState(() => _isPairing = false);

    if (success) {
      context.go('/permissions');
      return;
    }

    // Backend 0.6.0 — 409 AWAITING_PARENT_CONFIRM → waiting ekran.
    final pairingState = ref.read(pairingStateProvider);
    if (pairingState.status == PairingStatus.awaitingParent &&
        pairingState.pairRequestId != null) {
      context.go('/pair-waiting');
      return;
    }

    // Boshqa xato — SnackBar + box'larni tozalash
    final error = pairingState.errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'pairing.errorFallback'.tr()),
        backgroundColor: AppColors.error,
      ),
    );
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Title
                Text(
                  'pairing.appName'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'pairing.subtitle'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // 5 ta input box
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, _buildCodeBox),
                ),

                const SizedBox(height: 32),

                Text(
                  'pairing.hint'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Help link
                TextButton(
                  onPressed: _showHelp,
                  child: Text(
                    'pairing.helpLink'.tr(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const Spacer(),

                if (_isPairing)
                  const CircularProgressIndicator(color: AppColors.primary),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    final hasValue = _controllers[index].text.isNotEmpty;

    return Container(
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 4) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }

          if (_isFull) {
            _onCodeComplete();
          }

          setState(() {}); // border rangini yangilash uchun
        },
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'pairing.helpTitle'.tr(),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'pairing.helpContent'.tr(),
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('pairing.helpClose'.tr()),
          ),
        ],
      ),
    );
  }
}
