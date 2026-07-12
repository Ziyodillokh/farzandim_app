// ─────────────────────────────────────────────────────────────────────
// ParvozSearchField — Parvoz dark uslubidagi qidiruv maydoni
// ─────────────────────────────────────────────────────────────────────
//
// Videolar + Audiokitoblar feed'ida ishlatiladi. Berilgan `StateProvider<String>`
// ga yozadi/o'qiydi (controller provider'dan init bo'ladi — ekranga qaytganda
// joriy qidiruv ko'rinadi). Shisha fon + qidiruv ikonka + tozalash (✕) tugma.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    // Joriy qidiruvdan boshlaymiz (ekranga qaytganda matn saqlanadi).
    _controller = TextEditingController(text: ref.read(widget.queryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(widget.queryProvider.notifier).state = '';
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = ref.watch(widget.queryProvider).isNotEmpty;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (v) =>
                  ref.read(widget.queryProvider.notifier).state = v,
              textInputAction: TextInputAction.search,
              cursorColor: widget.accent,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _clear();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
