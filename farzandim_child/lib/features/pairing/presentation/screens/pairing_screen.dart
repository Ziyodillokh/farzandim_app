// ─────────────────────────────────────────────────────────────────────
// PairingScreen — bola 5 raqamli oila kodini kiritadi
// ─────────────────────────────────────────────────────────────────────
//
// Figma dizayni — dark fon, 5 ta katta yumshoq kvadrat box, ko'k link.
// Theme'ga bog'liq emas (har doim dark) — onboarding ekrani.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  // ─── Figma palitrasi ─────────────────────────────────────────────
  static const Color _bg = Color(0xFF0B0B12);
  static const Color _boxFill = Color(0xFF2A2A33);
  static const Color _titleColor = Color(0xFFFFFFFF);
  static const Color _hintColor = Color(0xFFB5B5BD);
  static const Color _linkColor = Color(0xFF6B70F5);

  final List<TextEditingController> _controllers =
      List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  bool _isPairing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

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

    final pairingState = ref.read(pairingStateProvider);
    if (pairingState.status == PairingStatus.awaitingParent &&
        pairingState.pairRequestId != null) {
      context.go('/pair-waiting');
      return;
    }

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
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yuqoridan ekran balandligining ~14% bo'sh joy — kontent
              // optik markazga yaqinroq tushadi.
              SizedBox(height: MediaQuery.of(context).size.height * 0.14),

              // ─── Title (Figma: "Farzandim:" + 2-line subtitle, white bold) ───
              Text(
                '${'pairing.appName'.tr()}\n${'pairing.subtitle'.tr()}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 56),

              // ─── 5 ta code box ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, _buildCodeBox),
              ),

              const SizedBox(height: 28),

              // ─── Hint matn ───
              Text(
                'pairing.hint'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  color: _hintColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ─── Help link (ko'k underlined) ───
              Center(
                child: GestureDetector(
                  onTap: _showHelp,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Text(
                      'pairing.helpLink'.tr(),
                      style: const TextStyle(
                        color: _linkColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: _linkColor,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              if (_isPairing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: _linkColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 56,
      height: 64,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        cursorColor: _titleColor,
        cursorWidth: 2,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _titleColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _boxFill,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
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
          setState(() {});
        },
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: Text(
          'pairing.helpTitle'.tr(),
          style: const TextStyle(color: _titleColor),
        ),
        content: Text(
          'pairing.helpContent'.tr(),
          style: const TextStyle(color: _hintColor, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'pairing.helpClose'.tr(),
              style: const TextStyle(color: _linkColor),
            ),
          ),
        ],
      ),
    );
  }
}
