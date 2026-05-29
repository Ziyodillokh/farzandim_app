import 'dart:typed_data';

import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// Foto yuklash uchun placeholder — 120x120 yumaloq burchakli kvadrat.
///
/// Ikki holatda ishlaydi:
/// - **Bo'sh** (`photoBytes == null`): `+` ikonkasi, butun joy bosilishi
///   mumkin — `onTap` chaqiriladi (odatda PhotoSourceBottomSheet ochish).
/// - **Foto bilan** (`photoBytes != null`): rasm ko'rinadi, o'ng yuqori
///   burchakda X tugma — `onRemove` chaqiriladi.
///
/// **Foydalanish:**
/// ```dart
/// PhotoUploadPlaceholder(
///   photoBytes: _photoBytes,                                   // Uint8List?
///   onTap: _onPickPhoto,                                       // bo'sh paytda
///   onRemove: () => setState(() => _photoBytes = null),        // foto bor paytda
/// )
/// ```
class PhotoUploadPlaceholder extends StatelessWidget {
  /// `PhotoUploadPlaceholder` konstruktor.
  const PhotoUploadPlaceholder({
    super.key,
    this.onTap,
    this.onRemove,
    this.photoBytes,
  });

  /// Bo'sh holatda bosilganda chaqiriladi (foto tanlash boshlang'ich).
  /// `null` bo'lsa placeholder bosilmaydi.
  final VoidCallback? onTap;

  /// Foto bor paytda X tugma bosilganda chaqiriladi (foto o'chirish).
  /// `null` bo'lsa X tugma ko'rinmaydi.
  final VoidCallback? onRemove;

  /// Tanlangan foto bayt massivi. `null` bo'lsa `+` ikonka ko'rinadi.
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;
    if (bytes != null) {
      return _PhotoView(bytes: bytes, onRemove: onRemove);
    }
    return _EmptyState(onTap: onTap);
  }
}

/// Bo'sh holat — `+` ikonka aylanasi, butun yuza bosilishi mumkin.
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusL);
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 120,
          height: 120,
          child: Center(child: _AddIcon()),
        ),
      ),
    );
  }
}

/// Bo'sh holatdagi `+` ikonka aylanasi — 48x48 border'li circle.
class _AddIcon extends StatelessWidget {
  const _AddIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textSecondary, width: 2),
      ),
      child: const Icon(
        Icons.add,
        color: AppColors.textSecondary,
        size: 28,
      ),
    );
  }
}

/// Foto holati — rasm + (ixtiyoriy) o'ng yuqori X tugma.
class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.bytes, this.onRemove});

  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final removeCallback = onRemove;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        // X tugma rasmning chegarasidan tashqariga chiqadi (negative position).
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            child: Image.memory(
              bytes,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              // Rasm baytlari buzuq bo'lsa fallback (kamdan-kam yuz beradi).
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.surfaceVariant,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          if (removeCallback != null)
            Positioned(
              top: -6,
              right: -6,
              child: _RemoveButton(onTap: removeCallback),
            ),
        ],
      ),
    );
  }
}

/// Kichik dumaloq X tugma — fotoni o'chirish uchun.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.close,
            size: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
