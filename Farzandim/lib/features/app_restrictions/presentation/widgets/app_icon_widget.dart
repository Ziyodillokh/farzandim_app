import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ilova ikonkasi — priority: `iconUrl` (Backend MinIO signed URL) >
/// `iconBase64` (eski Bola App PNG) > paket nomidan Material `IconData`.
///
/// Hech qaysisi mavjud bo'lmasa, paket nomidan taxminiy `IconData`
/// ko'rsatiladi (Instagram=camera, TikTok=music, va h.k.).
class AppIconWidget extends StatefulWidget {
  /// `AppIconWidget` konstruktor.
  const AppIconWidget({
    required this.packageName,
    super.key,
    this.iconUrl,
    this.iconBase64,
    this.size = 48,
  });

  /// Backend MinIO signed URL (1 soat). Sprint 4.4.29. Eng yuqori priority.
  final String? iconUrl;

  /// Bola App tomonidan yuborilgan PNG ikon (base64-encoded). Legacy
  /// fallback. Backend hozir iconUrl qaytaradi, base64 ishlatilmaydi.
  final String? iconBase64;

  /// Android paket nomi — fallback ikon tanlash uchun.
  final String packageName;

  /// Widget o'lchami (kvadrat, default 48dp).
  final double size;

  @override
  State<AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends State<AppIconWidget> {
  // Decode natijasi MEMOIZE qilinadi (PERF-04): avval StatelessWidget har
  // rebuild'da base64Decode + YANGI Uint8List yaratardi — Image.memory
  // keshini doim sog'inib (yangi obyekt = yangi kesh kaliti), ro'yxat
  // scroll'ida qayta-qayta dekod bo'lardi.
  Uint8List? _decodedBytes;
  String? _decodedFrom;

  Uint8List? get _bytes {
    final code = widget.iconBase64;
    if (code == null || code.isEmpty) return null;
    if (identical(code, _decodedFrom) || code == _decodedFrom) {
      return _decodedBytes;
    }
    try {
      _decodedBytes = base64Decode(code);
    } catch (_) {
      _decodedBytes = null;
    }
    _decodedFrom = code;
    return _decodedBytes;
  }

  double get size => widget.size;
  String? get iconUrl => widget.iconUrl;
  String get packageName => widget.packageName;

  /// Paket nomidan tipik IconData taxmin qilamiz.
  IconData _fallbackIcon(String pkg) {
    final p = pkg.toLowerCase();
    if (p.contains('instagram')) return SolarIconsBold.camera;
    if (p.contains('tiktok') || p.contains('musically')) {
      return SolarIconsBold.musicNote;
    }
    if (p.contains('youtube')) return SolarIconsBold.play;
    if (p.contains('whatsapp')) return SolarIconsBold.chatRound;
    if (p.contains('telegram')) return SolarIconsBold.plain;
    if (p.contains('chrome') || p.contains('browser')) {
      return SolarIconsBold.global;
    }
    if (p.contains('game') || p.contains('pubg')) {
      return SolarIconsBold.gamepad;
    }
    if (p.contains('settings')) return SolarIconsBold.settings;
    if (p.contains('launcher')) return SolarIconsBold.home;
    if (p.contains('camera')) return SolarIconsBold.camera;
    if (p.contains('phone') || p.contains('dialer')) {
      return SolarIconsBold.phone;
    }
    if (p.contains('facebook')) return SolarIconsBold.like;
    if (p.contains('snapchat')) return SolarIconsBold.camera;
    if (p.contains('spotify') || p.contains('music')) {
      return SolarIconsBold.headphonesRound;
    }
    if (p.contains('google')) return SolarIconsBold.magnifier;
    if (p.contains('pinterest')) return SolarIconsBold.pin;
    return SolarIconsBold.widget;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.25);

    // 1. Priority: iconUrl (Backend proxy URL).
    // MEM-4: disk-keshli — ikonkalar har cold-start'da qayta yuklanmaydi
    // (bola qurilmasida 100+ ilova bo'lishi mumkin — har ochilishda 100+
    // so'rov ketardi). memCacheWidth — kichik ikonka to'liq o'lchamda
    // dekod qilinmasin (xotira).
    final url = iconUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: 128,
          placeholder: (_, __) => _buildFallback(radius),
          errorWidget: (_, __, ___) => _buildBase64OrFallback(radius),
        ),
      );
    }

    // 2. Fallback: iconBase64 (legacy).
    return _buildBase64OrFallback(radius);
  }

  Widget _buildBase64OrFallback(BorderRadius radius) {
    final bytes = _bytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildFallback(radius),
        ),
      );
    }
    return _buildFallback(radius);
  }

  Widget _buildFallback(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        _fallbackIcon(packageName),
        color: AppColors.accent,
        size: size * 0.5,
      ),
    );
  }
}
