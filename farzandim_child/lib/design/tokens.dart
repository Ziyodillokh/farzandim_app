// Growth v5 "tungi shisha" dizayn tokenlari.
//
// Manba: dizayn kanvasidagi kit (shared.css, v5). Qiymatlar 1:1 ko'chirilgan —
// o'zgartirish kerak bo'lsa avval kanvasdagi kit, keyin shu fayl.

import 'package:flutter/painting.dart';

/// Ranglar.
abstract final class GColors {
  static const bg = Color(0xFF050915);
  static const text = Color(0xFFEDF2FF);
  static const textBody = Color(0xFFD6DEF0);
  static const textMuted = Color(0xFF97A5C4);
  static const textFaint = Color(0xFF8592B2);
  static const textLabel = Color(0xFFC3CDE6);
  static const chevron = Color(0xFF7F8DAD);
  static const link = Color(0xFFA9C4FF);
  static const white = Color(0xFFFFFFFF);

  static const primary = Color(0xFF4F86FF);
  static const primaryMid = Color(0xFF2F5BEA);
  static const primaryDeep = Color(0xFF2448C9);
  static const sky = Color(0xFF7DD3FC);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFF5B13D);
  static const danger = Color(0xFFE11D48);
  static const errorText = Color(0xFFFFC2CD);

  /// Ichki ajratgich chiziq (ro'yxat qatorlari orasida).
  static const divider = Color(0x0FFFFFFF);

  /// Shisha yuzasi: rgba(11,16,34,.62).
  static const glassFill = Color(0x9E0B1022);

  /// Ajratilgan (feat) shisha yuzasi: rgba(11,17,38,.66).
  static const featFill = Color(0xA80B1126);

  /// Maydon va segment fonlari: rgba(255,255,255,.045).
  static const fieldFill = Color(0x0BFFFFFF);
  static const fieldBorder = Color(0x1FFFFFFF);
  static const focusBorder = Color(0xBF8CB4FF);
  static const focusRing = Color(0x244F86FF);
  static const errorBorder = Color(0xBFFB7185);
  static const errorRing = Color(0x1FF43F5E);
}

/// Bir rangli "tile" va urg'u ranglari: fon rangi (`base`) va ikon rangi (`icon`).
enum GHue {
  blue(Color(0xFF4F86FF), Color(0xFFA0C0FF)),
  green(Color(0xFF10B981), Color(0xFF80E4BA)),
  orange(Color(0xFFF97316), Color(0xFFFFB88C)),
  rose(Color(0xFFF43F5E), Color(0xFFFFA0B4)),
  gold(Color(0xFFF59E0B), Color(0xFFFFD480)),
  teal(Color(0xFF14B8A6), Color(0xFF70E8D8)),
  sky(Color(0xFF0EA5E9), Color(0xFF92DAFF)),
  slate(Color(0xFF94A3B8), Color(0xFFB2BED6));

  const GHue(this.base, this.icon);

  final Color base;
  final Color icon;
}

/// Ekran fonidagi yorug'lik "orb"lari mavzusi.
enum GBgTheme { blue, green, gold, rose, teal }

/// Bo'shliqlar (8pt to'r, kanvasdagi qiymatlar).
abstract final class GSpace {
  static const screenH = 20.0;
  static const screenTop = 22.0;
  static const gap = 14.0;
  static const sectionGap = 10.0;
  static const cardPad = 16.0;
  static const minTap = 48.0;

  /// Dock (pastki tugmalar) ostidagi kontent zaxirasi: 56 tugma + 40 + 28.
  static const dockReserve = 136.0;
}

/// Burchak radiuslari.
abstract final class GRadius {
  static const card = 22.0;
  static const option = 20.0;
  static const button = 18.0;
  static const field = 16.0;
  static const segment = 12.0;
  static const sheet = 30.0;
  static const chip = 13.0;
}

/// Gradientlar va soyalar.
abstract final class GEffects {
  static const primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GColors.primary, GColors.primaryMid, GColors.primaryDeep],
    stops: [0, .55, 1],
  );

  static const progressGradient = LinearGradient(
    colors: [GColors.primary, GColors.sky],
  );

  /// Radius qisqa tomonga nisbatan: keng tugmada ham nur butun yuzaga yoyiladi.
  static const sosGradient = RadialGradient(
    center: Alignment(-.3, -.4),
    radius: 2.2,
    colors: [Color(0xFFFF6B86), Color(0xFFE11D48), Color(0xFF9E0F33)],
    stops: [0, .58, 1],
  );

  /// Shisha ustidagi och qatlam: oq .05 → .014.
  static const glassSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0DFFFFFF), Color(0x04FFFFFF)],
  );

  /// Shisha cheti (1px halqa), 165°.
  static const glassRing = LinearGradient(
    begin: Alignment(-.26, -.97),
    end: Alignment(.26, .97),
    colors: [
      Color(0x2BFFFFFF),
      Color(0x0BFFFFFF),
      Color(0x05FFFFFF),
      Color(0x12FFFFFF),
    ],
    stops: [0, .30, .70, 1],
  );

  /// Ajratilgan karta halqasi (ko'kroq), 160°.
  static const featRing = LinearGradient(
    begin: Alignment(-.34, -.94),
    end: Alignment(.34, .94),
    colors: [
      Color(0x8096B9FF),
      Color(0x1A96B9FF),
      Color(0x08FFFFFF),
      Color(0x2E96B9FF),
    ],
    stops: [0, .32, .68, 1],
  );

  static const glassShadow = [
    BoxShadow(
      color: Color(0xD9000000),
      offset: Offset(0, 18),
      blurRadius: 40,
      spreadRadius: -22,
    ),
  ];

  static const primaryShadow = [
    BoxShadow(
      color: Color(0xCC2F63F5),
      offset: Offset(0, 14),
      blurRadius: 28,
      spreadRadius: -12,
    ),
  ];

  static const sosShadow = [
    BoxShadow(
      color: Color(0xBFE11D48),
      offset: Offset(0, 18),
      blurRadius: 36,
      spreadRadius: -12,
    ),
  ];

  /// Dock foni: shaffofdan quyuq fonga.
  static const dockFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00050915), Color(0xF0050915)],
    stops: [0, .45],
  );
}

/// Gradientni yarim shaffof asos ustiga aralashtiradi.
///
/// Flutter `BoxDecoration`da `gradient` berilsa `color` chizilmaydi (CSS'da esa
/// fon qatlamlari ustma-ust tushadi) — shu sabab asos rang gradient ranglariga
/// «over» qoidasi bilan qo'shiladi. Natija kanvasdagi qatlamlar bilan bir xil.
Gradient? gradientOver(Gradient? gradient, Color? base) {
  if (gradient == null || base == null) return gradient;
  List<Color> blend(List<Color> colors) => [
    for (final c in colors) Color.alphaBlend(c, base),
  ];
  return switch (gradient) {
    LinearGradient(:final begin, :final end, :final colors, :final stops) =>
      LinearGradient(
        begin: begin,
        end: end,
        colors: blend(colors),
        stops: stops,
      ),
    RadialGradient(:final center, :final radius, :final colors, :final stops) =>
      RadialGradient(
        center: center,
        radius: radius,
        colors: blend(colors),
        stops: stops,
      ),
    _ => gradient,
  };
}
