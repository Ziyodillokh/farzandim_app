import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ─────────────────────────────────────────────────────────────────────
// Parvoz onboarding dizayn-tizimi (ko'k + shisha)
// ─────────────────────────────────────────────────────────────────────
//
// Ilovaning teal "Deep Sea" temasidan farq qiladi: chuqur qora-ko'k fon +
// #216BFF ko'k aksent. Onboarding ekranlari (til, welcome, login, register)
// shu komponentlarni qayta ishlatadi. TUGMA QOIDASI: primary = ko'k, secondary
// = shisha.

/// Parvoz brend ranglari.
class ParvozColors {
  ParvozColors._();

  /// Asosiy fon — chuqur qora-ko'k.
  static const Color bg = Color(0xFF02060D);

  /// Asosiy ko'k aksent (primary tugma, tanlangan element).
  static const Color blue = Color(0xFF216BFF);

  /// Ochroq ko'k (gradient yuqori, sheen).
  static const Color blueLight = Color(0xFF3C82FF);

  /// Yog'du ko'ki (radial glow, ambient tint).
  static const Color glow = Color(0xFF508AFF);
}

/// Parvoz brend belgisi — logo + "Parvoz / Parents" so'z belgisi.
class ParvozBrandLogo extends StatelessWidget {
  const ParvozBrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/parvoz_logo_mark.svg',
          width: 50,
          height: 50,
        ),
        const SizedBox(width: 13),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parvoz',
              style: GoogleFonts.unbounded(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.3,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Parents',
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Yumshoq ko'k radial yog'du (logo ortida ishlatiladi).
class ParvozTopGlow extends StatelessWidget {
  const ParvozTopGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            ParvozColors.glow.withValues(alpha: 0.45),
            const Color(0x00508AFF),
          ],
          stops: const [0, 0.72],
        ),
      ),
    );
  }
}

/// Orqaga tugma — yarim-shaffof dumaloq + oq strelka.
class ParvozBackButton extends StatelessWidget {
  const ParvozBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Premium frosted-glass yuzasi (pill).
///
/// Fon deyarli qora bo'lgani uchun shisha qatlamlardan: yo'naltirilgan fill +
/// sheen + tepa specular chiziq + yorqin rim + chuqurlik soyasi. Shisha
/// (non-blue): yorug'lik o'ngdan, chap to'q. `blue: true` — ko'k to'ldirilgan
/// (primary tugma / tanlangan element).
class ParvozGlass extends StatelessWidget {
  const ParvozGlass({
    required this.child,
    this.height = 60,
    this.radius = 999,
    this.blue = false,
    super.key,
  });

  /// Markazlashtirilgan mazmun.
  final Widget child;

  /// Yuza balandligi.
  final double height;

  /// Burchak radiusi (default pill).
  final double radius;

  /// `true` — ko'k to'ldirilgan; `false` — shisha.
  final bool blue;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final sheenBegin = blue ? Alignment.topLeft : Alignment.topRight;
    final sheenAlpha = blue ? 0.22 : 0.07;
    final specularAlpha = blue ? 0.6 : 0.5;
    final rimAlpha = blue ? 0.32 : 0.2;

    return DecoratedBox(
      // Chuqurlik soyasi (clip'dan tashqarida) — yuzani fondan ko'taradi.
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
          if (blue)
            BoxShadow(
              color: ParvozColors.blue.withValues(alpha: 0.5),
              blurRadius: 28,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          // Haqiqiy frost — ortida nimadir bo'lsa xiralashtiradi.
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: blue
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ParvozColors.blueLight, ParvozColors.blue],
                      )
                    : LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Colors.white.withValues(alpha: 0.11),
                          Colors.white.withValues(alpha: 0.025),
                        ],
                      ),
              ),
              child: Stack(
                children: [
                  // Sheen — yumshoq yorug'lik (ko'k: chapdan, shisha: o'ngdan).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: sheenBegin,
                            end: Alignment.center,
                            colors: [
                              Colors.white.withValues(alpha: sheenAlpha),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tepa specular chiziq (~1.5px) — kuchli shisha belgisi.
                  Positioned(
                    top: 0,
                    left: 18,
                    right: 18,
                    child: IgnorePointer(
                      child: SizedBox(
                        height: 1.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: specularAlpha),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Yorqin rim — refraksiya chetini taqlid qiladi.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: br,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: rimAlpha),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asosiy (primary) tugma — ko'k, pill, kerak bo'lsa o'ng strelka.
class ParvozPrimaryButton extends StatelessWidget {
  const ParvozPrimaryButton({
    required this.label,
    required this.onPressed,
    this.showArrow = true,
    this.height = 56,
    this.loading = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool showArrow;
  final double height;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: canTap ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: ParvozGlass(
          blue: true,
          height: height,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    if (showArrow) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        SolarIconsBold.altArrowRight,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Ikkilamchi (secondary) tugma — shisha, pill. `leading` — chap ikon/logo.
class ParvozSecondaryButton extends StatelessWidget {
  const ParvozSecondaryButton({
    required this.label,
    required this.onPressed,
    this.leading,
    this.height = 56,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? leading;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final lead = leading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: ParvozGlass(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 10)],
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

/// Parvoz matn maydoni — yorliq + shisha pill input (fokusda ko'k rim).
class ParvozTextField extends StatefulWidget {
  const ParvozTextField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.hint,
    this.onChanged,
    this.prefix,
    this.inputFormatters,
    this.maxLength,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  @override
  State<ParvozTextField> createState() => _ParvozTextFieldState();
}

class _ParvozTextFieldState extends State<ParvozTextField> {
  final _focus = FocusNode();
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final obscure = widget.obscure && _hidden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: focused
                  ? ParvozColors.blue
                  : Colors.white.withValues(alpha: 0.12),
              width: focused ? 1.5 : 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  // Matn belgilash kursori/tomchilari ko'k (global teal emas).
                  child: TextSelectionTheme(
                    data: const TextSelectionThemeData(
                      cursorColor: ParvozColors.blue,
                      selectionHandleColor: ParvozColors.blue,
                      selectionColor: Color(0x5C216BFF),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      obscureText: obscure,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      maxLength: widget.maxLength,
                      onChanged: widget.onChanged,
                      cursorColor: ParvozColors.blue,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        // Global teal fill'ni o'chiramiz — shisha ko'rinsin.
                        filled: false,
                        isCollapsed: true,
                        counterText: '',
                        // Global teal focusedBorder'ni ham o'chiramiz —
                        // faqat tashqi DecoratedBox rim (ko'k) qoladi.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.obscure)
                  GestureDetector(
                    onTap: () => setState(() => _hidden = !_hidden),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      _hidden ? SolarIconsBold.eyeClosed : SolarIconsBold.eye,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
