// ─────────────────────────────────────────────────────────────────────
// RankingAvatar — reyting/mini-reytingda bola avatari.
//
// Prioritet: HAQIQIY rasm (bola yuklagan) → jins+yoshga mos default avatar
// → bosh harf (eng oxirgi zaxira). Rasm PUBLIC endpoint orqali childId bo'yicha
// olinadi: GET /children/:id/avatar/image (auth kerak emas, @Public). Shu sabab
// reytingdagi HAR bola o'z rasmi bilan (bo'lsa) ko'rinadi — hammasi bir xil
// default emas.
// ─────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:farzandim_child/core/config/env_config.dart';

class RankingAvatar extends StatelessWidget {
  const RankingAvatar({
    required this.name,
    required this.size,
    this.childId,
    this.gender,
    this.age,
    this.color = const Color(0xFF2A2F3A),
    this.borderColor,
    this.borderWidth = 2,
    super.key,
  });

  /// Bola ismi — rasm ham, default ham bo'lmasa bosh harf uchun.
  final String name;

  /// Diametri (kenglik = balandlik).
  final double size;

  /// Bola ID — HAQIQIY rasmni olish uchun (`/children/:id/avatar/image`).
  /// `null`/bo'sh bo'lsa to'g'ridan default avatar.
  final String? childId;

  /// Jinsi ("male"/"female"/null) — default avatar tanlash uchun.
  final String? gender;

  /// Yoshi — qiz bolalar default avatarini yosh guruhiga qarab tanlash uchun.
  final int? age;

  /// Fon rangi (harf zaxirasi orqasida).
  final Color color;

  /// Aylana chegara rangi (`null` — chegarasiz).
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    final id = childId;
    if (id != null && id.isNotEmpty) {
      // Rasm bor-yo'qligini oldindan bilmaymiz — network'dan urinamiz, xato
      // (404 = rasm yo'q) yoki yuklanayotganda default avatarga tushamiz.
      return CachedNetworkImage(
        imageUrl: '${EnvConfig.apiUrl}/children/$id/avatar/image',
        fit: BoxFit.cover,
        memCacheWidth: 240,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => _defaultAvatar(),
        errorWidget: (_, __, ___) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() => Image.asset(
        _defaultAvatarPath(gender, age),
        fit: BoxFit.cover,
        cacheWidth: 240,
        errorBuilder: (_, __, ___) => _letter(),
      );

  Widget _letter() => ColoredBox(
        color: color,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

/// Jins + yoshga mos default avatar asset yo'li (profil/reyting bilan bir xil).
///   - `female` → yoshga qarab 3 xil (6_10 / 10_14 / 14)
///   - aks holda (male yoki noma'lum) → bitta `boy.png`
String _defaultAvatarPath(String? gender, int? age) {
  final isFemale = gender == 'female';
  if (!isFemale) return 'assets/default_avatars/boy.png';
  final a = age ?? 6;
  final band = a >= 14
      ? '14'
      : a >= 10
      ? '10_14'
      : '6_10';
  return 'assets/default_avatars/girl_$band.png';
}
