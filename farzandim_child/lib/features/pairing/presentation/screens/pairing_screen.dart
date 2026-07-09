// ─────────────────────────────────────────────────────────────────────
// PairingScreen — bola 5 raqamli oila kodini kiritadi (Parvoz ko'k redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// 5 ta oval katak — har biriga 1 raqam (bo'sh bo'lsa o'rin raqami ko'rinadi).
// Kataklar ekran kengligiga moslashadi (hamma telefonda bir xil, overflow yo'q).
// Avtomatik: raqam kiritilsa keyingi katak; backspace → oldingi; 5-chi raqamda
// avto-pairing. Muvaffaqiyat → /splash; 409 → /pair-waiting; xato → SnackBar +
// tozalash. "Kirish" (QR) → /qr-scan; "Bu qanday ishlaydi?" → help.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal, ko'k) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF);
const _error = Color(0xFFFF4B4B);

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final List<TextEditingController> _controllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
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
    if (_isPairing) return;

    setState(() => _isPairing = true);
    FocusScope.of(context).unfocus();

    final success = await ref
        .read(pairingStateProvider.notifier)
        .tryPair(_code);

    if (!mounted) return;
    setState(() => _isPairing = false);

    if (success) {
      context.go('/splash');
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
        backgroundColor: _error,
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
      body: Stack(
        children: [
          // Yog'du — YUQORIDA (markazda).
          const Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _TopGlow())),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Katak o'lchamini kenglikka moslashtiramiz (hamma telefonda
                // bir xil, overflow/siqilish yo'q). 24*2 padding hisobga olinadi.
                final contentW = constraints.maxWidth - 48;
                final side = ((contentW - 40) / 5).clamp(40.0, 58.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          Text(
                            'pairing.enterCodeTitle'.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.unbounded(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.6,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'pairing.enterCodeSubtitle'.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.5,
                              color: _dim,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              5,
                              (i) => _buildCodeBox(i, side),
                            ),
                          ),
                          const SizedBox(height: 44),
                          _GlassButton(
                            icon: Icons.qr_code_2_rounded,
                            label: 'pairing.enterButton'.tr(),
                            onTap: () => context.push('/qr-scan'),
                          ),
                          const SizedBox(height: 12),
                          _GlassButton(
                            icon: Icons.help_outline_rounded,
                            label: 'pairing.howItWorks'.tr(),
                            onTap: _showHelp,
                          ),
                          const Spacer(flex: 3),
                          if (_isPairing)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBox(int index, double side) {
    final hasValue = _controllers[index].text.isNotEmpty;
    final height = side * 1.2; // sal oval (bo'yi eniga nisbatan uzunroq)
    return Container(
      width: side,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: hasValue ? 0.06 : 0.03),
        borderRadius: BorderRadius.all(Radius.elliptical(side / 2, height / 2)),
        border: Border.all(
          color: hasValue ? _blue : Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
      ),
      // TextField butun ovalni to'ldiradi (hamma joyi bosiladi) + matn aniq
      // markazda (expands + textAlignVertical.center). Default raqam yo'q.
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        expands: true,
        maxLines: null,
        minLines: null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 1,
        cursorColor: Colors.white,
        style: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 4) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_isFull) _onCodeComplete();
          setState(() {});
        },
      ),
    );
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12171E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Text(
          'pairing.helpTitle'.tr(),
          style: GoogleFonts.unbounded(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'pairing.helpContent'.tr(),
          style: GoogleFonts.poppins(color: _dim, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'pairing.helpClose'.tr(),
              style: GoogleFonts.poppins(
                color: _blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Shisha tugma (yozuv MARKAZDA, ikon chapda) ════════════
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
          ),
          border: Border.all(color: const Color(0x1FFFFFFF), width: 1.2),
        ),
        // Ikon + yozuv guruh sifatida markazda (ikon yozuv YONIDA).
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Yuqori ko'k yog'du ════════════
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x4D216BFF), Color(0x00216BFF)],
          stops: [0, 0.72],
        ),
      ),
    );
  }
}
