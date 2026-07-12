// ─────────────────────────────────────────────────────────────────────
// ParvozSearchField — ota-ona chat input uslubidagi qidiruv maydoni
// ─────────────────────────────────────────────────────────────────────
//
// Videolar + Audiokitoblar feed'ida ishlatiladi. Ko'rinishi ota-ona chat
// input formasidek: KATTA, OVAL (pill) toza input + o'ngda ALOHIDA dumaloq
// qidiruv tugma (kamera o'rniga search ikonka). Berilgan `StateProvider<String>`
// ga yozadi/o'qiydi (controller provider'dan init — ekranga qaytganda joriy
// qidiruv ko'rinadi). Matn kiritilsa ichida ✕ (tozalash).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const _fieldBg = Color(0xFF161B22); // pill + tugma foni (chat input dark)

class ParvozSearchField extends ConsumerStatefulWidget {
  const ParvozSearchField({
    required this.queryProvider,
    this.hintText = 'Qidirish...',
    this.accent = const Color(0xFF216BFF),
    super.key,
  });

  /// Qidiruv matnini saqlovchi provider (ekranga xos).
  final StateProvider<String> queryProvider;
  final String hintText;
  final Color accent;

  @override
  ConsumerState<ParvozSearchField> createState() => _ParvozSearchFieldState();
}

class _ParvozSearchFieldState extends ConsumerState<ParvozSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Joriy qidiruvdan boshlaymiz (ekranga qaytganda matn saqlanadi).
    _controller = TextEditingController(text: ref.read(widget.queryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(widget.queryProvider.notifier).state = '';
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = ref.watch(widget.queryProvider).isNotEmpty;
    return Row(
      children: [
        // Toza, oval (pill) input — chat input formasidek katta.
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.only(left: 20, right: 8),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(27),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (v) =>
                        ref.read(widget.queryProvider.notifier).state = v,
                    textInputAction: TextInputAction.search,
                    cursorColor: widget.accent,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                    // App temasidagi InputDecorationTheme fokus/enabled bordi
                    // (ko'k oval) chiqmasin — HAMMA holatni none qilamiz. Fon
                    // ham to'ldirilmasin, ichki padding yo'q → matn to'liq
                    // pill kengligida yoziladi.
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ),
                // Matn bo'lsa — ichida ✕ (tozalash).
                if (hasText)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _clear();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Alohida dumaloq qidiruv tugma (kamera o'rniga search ikonka).
        GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(_focusNode),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: _fieldBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.search_rounded,
              size: 24,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
