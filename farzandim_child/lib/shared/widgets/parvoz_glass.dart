// ─────────────────────────────────────────────────────────────────────
// parvoz_glass.dart — Parvoz NIGHT/GLASS dizayn-tizim helperlari (SHARED)
// ─────────────────────────────────────────────────────────────────────
//
// Barcha redizayn (night) sahifalar SHU helperlardan foydalanadi — izchillik
// uchun. Ranglar: AppColors.parvoz* (bg #0B1C30, surface #162B45, aqua
// #22D3EE, glass tokenlar). Sahifa NIGHT bo'lishi uchun:
//   Theme(data: AppTheme.darkTheme, child: Scaffold(backgroundColor:
//   AppColors.parvozBg, ...))  — yoki to'g'ridan parvoz ranglar.
//
// Komponentlar:
//   parvozGlass({radius})  — shishali karta dekoratsiyasi (translucent
//                            gradient + yorqin rim + yumshoq soya).
//   ParvozHeader           — night header (orqaga + markazda sarlavha + trailing).
//   ParvozSectionLabel     — kulrang UPPERCASE bo'lim sarlavhasi.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shishali (glass) karta dekoratsiyasi — navy fon ustidan yaqqol ajraladi.
/// Per-card blur YO'Q (uzun ro'yxat/grid'da 60fps). Rasm ustiga qo'yilganda
/// `clipBehavior: Clip.antiAlias` bilan ishlating.
BoxDecoration parvozGlass({double radius = 16, bool dark = true}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [AppColors.parvozGlassTop, AppColors.parvozGlassBottom]
            : const [Color(0xFFFFFFFF), Color(0xFFEEF4FF)],
      ),
      border: Border.all(
        color: dark ? AppColors.parvozGlassRim : const Color(0xFFD3E4FE),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: dark ? const Color(0x59000000) : const Color(0x142170E4),
          blurRadius: 22,
          offset: const Offset(0, 10),
          spreadRadius: -2,
        ),
      ],
    );

/// Soyasiz glass — forma maydonlari, list itemlar uchun (gradient + rim,
/// soya YO'Q — ko'p element ustma-ust kelganda toza).
BoxDecoration parvozGlassFlat({double radius = 14, bool dark = true}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [AppColors.parvozGlassTop, AppColors.parvozGlassBottom]
            : const [Color(0xFFFFFFFF), Color(0xFFEEF4FF)],
      ),
      border: Border.all(
        color: dark ? AppColors.parvozGlassRim : const Color(0xFFD3E4FE),
        width: 1,
      ),
    );

/// Premium night header — orqaga tugma + markazda sarlavha + (ixtiyoriy) trailing.
class ParvozHeader extends StatelessWidget {
  const ParvozHeader({
    required this.title,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Kun/tunga moslashadi (oldin qattiq oq matn edi → yorug' fonda ko'rinmasdi).
    final pv = context.adaptive;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: pv.pvBorder)),
        ),
        child: Row(
          children: [
            if (onBack != null)
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded,
                      color: pv.pvText, size: 24),
                ),
              )
            else
              const SizedBox(width: 40),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pv.pvText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SizedBox(width: 40, child: trailing),
          ],
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi — kulrang UPPERCASE (TIL / HISOB / ...).
class ParvozSectionLabel extends StatelessWidget {
  const ParvozSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.adaptive.pvTextDim,
        ),
      ),
    );
  }
}
