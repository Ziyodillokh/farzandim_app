// ─────────────────────────────────────────────────────────────────────
// AvatarMarkerBuilder — Yandex/2GIS stilidagi premium pin
// ─────────────────────────────────────────────────────────────────────
//
// Reference dizayn: yumaloq kvadrat avatar + pastki uchburchak quyruq.
// Anchor (0.5, 1.0) — uchburchak uchini aniq joyga to'g'rilaydi.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AvatarMarkerBuilder {
  AvatarMarkerBuilder._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Yandex pin stilidagi marker yaratish.
  ///
  /// `pinWidth` — pin (kvadrat) eni, default 72 px.
  /// `pinHeight` — quyruq bilan birga balandlik, default 92 px.
  /// `accent` — pin fon va border rangi.
  static Future<BitmapDescriptor> build({
    required String? avatarUrl,
    required String fallbackKey,
    double pinWidth = 72,
    double pinHeight = 92,
    // Marker xaritada — fixed lime (default param const bo'lishi shart).
    Color accent = const Color(0xFF235347),
  }) async {
    final cacheKey = '${avatarUrl ?? "null"}_$fallbackKey'
        '_${accent.toARGB32().toRadixString(16)}_${pinWidth.toInt()}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    ui.Image? avatarImage;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        avatarImage = await _loadNetworkImage(avatarUrl);
      } catch (_) {
        avatarImage = null;
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Geometry — pin shape (rounded rect + downward triangle tail)
    final cornerRadius = pinWidth * 0.20;
    final headHeight = pinWidth; // kvadrat
    final centerX = pinWidth / 2;
    final headRect = Rect.fromLTWH(0, 0, pinWidth, headHeight);

    // Quyruq eni — yangi kichikroq pin uchun proportional.
    final tailHalfWidth = pinWidth * 0.13;

    // Soft shadow ostida
    final shadowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          headRect.shift(const Offset(0, 3)),
          Radius.circular(cornerRadius),
        ),
      )
      ..moveTo(centerX - tailHalfWidth, headHeight - 6)
      ..lineTo(centerX, pinHeight + 3)
      ..lineTo(centerX + tailHalfWidth, headHeight - 6)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Pin fon (rounded rect bosh + uchburchak quyruq)
    final pinPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          headRect,
          Radius.circular(cornerRadius),
        ),
      )
      ..moveTo(centerX - tailHalfWidth, headHeight - 1)
      ..lineTo(centerX, pinHeight)
      ..lineTo(centerX + tailHalfWidth, headHeight - 1)
      ..close();
    canvas.drawPath(
      pinPath,
      Paint()..color = accent,
    );

    // Inner avatar slot — pin ichida 5 px padding (kichikroq pin uchun)
    const padding = 5.0;
    final avatarRect = Rect.fromLTWH(
      padding,
      padding,
      pinWidth - padding * 2,
      headHeight - padding * 2,
    );
    final avatarRRect = RRect.fromRectAndRadius(
      avatarRect,
      Radius.circular(cornerRadius - padding * 0.5),
    );

    canvas.save();
    canvas.clipRRect(avatarRRect);

    if (avatarImage != null) {
      paintImage(
        canvas: canvas,
        rect: avatarRect,
        image: avatarImage,
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    } else {
      // Fallback — bg + harf
      canvas.drawRect(
        avatarRect,
        Paint()..color = AppColors.surfaceVariant,
      );
      final initial =
          fallbackKey.isNotEmpty ? fallbackKey[0].toUpperCase() : '?';
      final tp = TextPainter(
        text: TextSpan(
          text: initial,
          style: TextStyle(
            color: accent,
            fontSize: avatarRect.width * 0.55,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          avatarRect.center.dx - tp.width / 2,
          avatarRect.center.dy - tp.height / 2,
        ),
      );
    }
    canvas.restore();

    // Highlight strip ichida — premium feel (Yandex pinning'ga o'xshash)
    canvas.drawRRect(
      avatarRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      pinWidth.toInt(),
      pinHeight.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;

    final descriptor = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
    );
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  static Future<ui.Image> _loadNetworkImage(String url) async {
    final completer = Completer<ui.Image>();
    final config = ImageConfiguration.empty;
    final provider = NetworkImage(url);
    final stream = provider.resolve(config);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (err, _) {
        completer.completeError(err);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// Cache'ni tozalash (avatar o'zgarganda).
  static void invalidate({String? cacheKey}) {
    if (cacheKey == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((k, _) => k.startsWith(cacheKey));
    }
  }
}

/// Premium map style — DEPRECATED (foydalanuvchi default'ga qaytarishni so'radi).
/// Hozircha API saqlab qolinyapti, lekin LocationMapScreen ishlatmaydi.
class MapStyleLoader {
  MapStyleLoader._();

  static Future<String> loadDarkPremium() async {
    return rootBundle.loadString('assets/map_styles/dark_premium.json');
  }
}

/// Dwell label marker — vaqt range pill xaritada doim ko'rinadi.
class DwellLabelMarker {
  DwellLabelMarker._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Multi-line label (`\n` bilan ajratiladi). Misol:
  /// ```
  /// 08:00–13:00 (5 s)
  /// 16:00–18:00 (2 s)
  /// Jami: 7 s
  /// ```
  /// `subtitle` — sana, masalan "16.05.26".
  static Future<BitmapDescriptor> build({
    required String label,
    required String subtitle,
    // Fixed info ko'k (default param const bo'lishi shart).
    Color accent = const Color(0xFF60A5FA),
  }) async {
    final cacheKey = '${label}__$subtitle';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final lines = label.split('\n');
    final linePainters = lines
        .map((l) => TextPainter(
              text: TextSpan(
                text: l,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout())
        .toList();

    final subTp = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padding = 16.0;
    const lineSpacing = 6.0;
    const dotSize = 18.0;

    var maxLineWidth = subTp.width;
    var totalLinesHeight = 0.0;
    for (final tp in linePainters) {
      if (tp.width > maxLineWidth) maxLineWidth = tp.width;
      totalLinesHeight += tp.height + lineSpacing;
    }
    totalLinesHeight -= lineSpacing; // oxirgi line uchun spacing kerak emas

    final pillWidth = maxLineWidth + padding * 2;
    final pillHeight = padding * 2 +
        totalLinesHeight +
        4 +
        subTp.height +
        dotSize +
        6;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final pillRect = Rect.fromLTWH(
      0,
      0,
      pillWidth,
      pillHeight - dotSize - 6,
    );
    final pillRRect = RRect.fromRectAndRadius(
      pillRect,
      const Radius.circular(14),
    );

    canvas.drawRRect(
      pillRRect.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(pillRRect, Paint()..color = accent);

    // Lines
    var y = padding;
    for (final tp in linePainters) {
      tp.paint(canvas, Offset((pillWidth - tp.width) / 2, y));
      y += tp.height + lineSpacing;
    }
    // Subtitle (sana) — ozgina ajratib chiqamiz
    subTp.paint(
      canvas,
      Offset((pillWidth - subTp.width) / 2, y - lineSpacing + 2),
    );

    // Bottom dot
    canvas.drawCircle(
      Offset(pillWidth / 2, pillHeight - dotSize / 2),
      dotSize / 2,
      Paint()..color = accent,
    );
    canvas.drawCircle(
      Offset(pillWidth / 2, pillHeight - dotSize / 2),
      dotSize / 2 - 4,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      pillWidth.toInt(),
      pillHeight.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;

    final descriptor = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    _cache[cacheKey] = descriptor;
    return descriptor;
  }
}
