import 'dart:convert';
import 'dart:typed_data';

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

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
    if (p.contains('instagram')) return Icons.camera_alt;
    if (p.contains('tiktok') || p.contains('musically')) {
      return Icons.music_note;
    }
    if (p.contains('youtube')) return Icons.play_arrow;
    if (p.contains('whatsapp')) return Icons.chat;
    if (p.contains('telegram')) return Icons.send;
    if (p.contains('chrome') || p.contains('browser')) {
      return Icons.public;
    }
    if (p.contains('game') || p.contains('pubg')) {
      return Icons.sports_esports;
    }
    if (p.contains('settings')) return Icons.settings;
    if (p.contains('launcher')) return Icons.home;
    if (p.contains('camera')) return Icons.photo_camera;
    if (p.contains('phone') || p.contains('dialer')) return Icons.phone;
    if (p.contains('facebook')) return Icons.thumb_up;
    if (p.contains('snapchat')) return Icons.photo_camera;
    if (p.contains('spotify') || p.contains('music')) {
      return Icons.headphones;
    }
    if (p.contains('google')) return Icons.search;
    if (p.contains('pinterest')) return Icons.push_pin;
    return Icons.apps;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.25);

    // 1. Priority: iconUrl (Backend MinIO signed URL).
    final url = iconUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _buildFallback(radius),
          errorBuilder: (_, __, ___) => _buildBase64OrFallback(radius),
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
