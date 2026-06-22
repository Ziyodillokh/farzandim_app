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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (_isPairing) return; // ikki marta yuborishni oldini olamiz

    setState(() => _isPairing = true);
    FocusScope.of(context).unfocus();

    final success =
        await ref.read(pairingStateProvider.notifier).tryPair(_code);

    if (!mounted) return;

    setState(() => _isPairing = false);

    if (success) {
      // Kod kiritilib pair tugagach — markaziy /splash router'ga.
      // U birinchi marta bo'lsa onboarding (qiziqishlar), keyin sistema
      // ruxsatlari ekrani yoki dashboard'ga yo'naltiradi.
      context.go('/splash');
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

  // Parvoz NIGHT dizayn-tizimi (navy fon + aqua aksent) — butun ilova bilan
  // izchil. Pairing bola ilovasining birinchi ekranlaridan biri, shuning uchun
  // qolgan NIGHT ekranlar bilan bir xil palitra (oldin qora+binafsha edi).
  static const Color _bgDark = AppColors.parvozBg;
  static const Color _boxFill = AppColors.parvozSurface;
  static const Color _linkColor = AppColors.parvozGreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 150),

              // Title — ikki qatorli qalin sarlavha (UI mockup'ga 1:1).
              // appName birinchi qator, subtitle ikkinchi qator — ikkalasi
              // ham bir xil og'irlikda (FontWeight.bold).
              Text(
                '${'pairing.appName'.tr()}\n${'pairing.subtitle'.tr()}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // 5 ta input box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, _buildCodeBox),
              ),

              const SizedBox(height: 28),

              Text(
                'pairing.hint'.tr(),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Help link — binafsha, underline.
              TextButton(
                onPressed: _showHelp,
                style: TextButton.styleFrom(
                  foregroundColor: _linkColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
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

              const SizedBox(height: 8),

              // ─── YOKI ajratuvchi ───
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white24,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'yoki',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ─── QR orqali ulash tugmasi ───
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/qr-scan'),
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  label: const Text(
                    'QR kod orqali ulash',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _linkColor,
                    // Aqua fon ustida navy matn — yuqori kontrast.
                    foregroundColor: AppColors.parvozOnGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              if (_isPairing)
                const CircularProgressIndicator(color: _linkColor),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    final hasValue = _controllers[index].text.isNotEmpty;

    return Container(
      width: 58,
      height: 64,
      decoration: BoxDecoration(
        color: _boxFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue ? _linkColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        // Raqamni katakcha o'rtasida (vertikal) joylash — aks holda
        // matn yuqoriga yopishib qoladi.
        textAlignVertical: TextAlignVertical.center,
        // Faqat raqam — fizik klaviatura yoki paste orqali harf kirmasin.
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        cursorColor: Colors.white,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          // App theme'da inputDecorationTheme oq fill bersa ham,
          // shu yerda majburiy shaffof — Container fonidan keladi.
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
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
        backgroundColor: AppColors.parvozSurface,
        title: Text(
          'pairing.helpTitle'.tr(),
          style: const TextStyle(color: AppColors.parvozText),
        ),
        content: Text(
          'pairing.helpContent'.tr(),
          style: const TextStyle(color: AppColors.parvozTextDim, height: 1.5),
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
