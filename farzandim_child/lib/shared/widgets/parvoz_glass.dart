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
BoxDecoration parvozGlass({double radius = 16}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.parvozGlassTop, AppColors.parvozGlassBottom],
      ),
      border: Border.all(color: AppColors.parvozGlassRim, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 22,
          offset: Offset(0, 10),
          spreadRadius: -2,
        ),
      ],
    );

/// Soyasiz glass — forma maydonlari, list itemlar uchun (gradient + rim,
/// soya YO'Q — ko'p element ustma-ust kelganda toza).
BoxDecoration parvozGlassFlat({double radius = 14}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.parvozGlassTop, AppColors.parvozGlassBottom],
      ),
      border: Border.all(color: AppColors.parvozGlassRim, width: 1),
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
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.parvozBorder)),
        ),
        child: Row(
          children: [
            if (onBack != null)
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded,
                      color: AppColors.parvozText, size: 24),
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
                style: const TextStyle(
                  color: AppColors.parvozText,
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.parvozTextDim,
        ),
      ),
    );
  }
}
