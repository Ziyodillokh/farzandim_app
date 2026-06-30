import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim/core/utils/app_brand.dart';
import 'package:flutter/material.dart';

/// Ilova ikonkasi — priority: `iconUrl` (Backend proxy URL) >
/// `iconBase64` (eski Bola App PNG) > brend rangli harf-avatar.
///
/// Ikon mavjud bo'lmasa, paket nomidan friendly nom olinib, uning bosh
/// harfi brend (yoki deterministik) rang ustida ko'rsatiladi — har ilova
/// aniq va farqlanadigan ko'rinadi ("Telegram" → ko'k "T").
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

  /// Ikon yo'q — brend rangli harf-avatar (friendly nom bosh harfi).
  Widget _buildFallback(BorderRadius radius) {
    final color = appAvatarColor(packageName);
    // WCAG: ~0.179 — qora va oq matn teng kontrast beradigan chegara; undan
    // yorug' fonda qora, qorong'ida oq matn (har doim o'qiladi).
    final onColor = color.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: radius),
      alignment: Alignment.center,
      child: Text(
        appInitial(packageName),
        style: TextStyle(
          color: onColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
