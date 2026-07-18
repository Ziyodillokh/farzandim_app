// Rasmsiz bola uchun default avatar rasmi (aylana ichini to'ldiradi).
//
// Jinsi ma'lum bo'lsa — jinsi+yoshga mos PNG (6 tadan biri). Jinsi noma'lum
// bo'lsa (masalan DON reytingi eski backend javobida gender yo'q) — neytral
// SVG fallback. ClipOval ichida BoxFit.cover bilan ishlatiladi.

import 'package:farzandim/features/child_management/data/models/default_avatar.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Default avatar rasmi. [gender] `null` bo'lsa neytral SVG.
Widget defaultAvatarImage({required Gender? gender, required int? age}) {
  if (gender == null) {
    return SvgPicture.asset(
      'assets/stickers/default_avatar.svg',
      fit: BoxFit.cover,
    );
  }
  return Image.asset(defaultAvatarAsset(gender, age ?? 0), fit: BoxFit.cover);
}
