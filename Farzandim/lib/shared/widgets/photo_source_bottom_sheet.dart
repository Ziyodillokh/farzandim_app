import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

/// Foto manba tanlash bottom sheet'i — Galereya yoki Kamera.
///
/// **Foydalanish:**
/// ```dart
/// final source = await PhotoSourceBottomSheet.show(context);
/// if (source == null) return;  // foydalanuvchi bekor qildi
///
/// final bytes = source == ImageSource.gallery
///     ? await service.pickFromGallery()
///     : await service.pickFromCamera();
/// ```
///
/// `Future<ImageSource?>` qaytaradi:
/// - `ImageSource.gallery` — Galereya tanlandi
/// - `ImageSource.camera` — Kamera tanlandi
/// - `null` — bekor qilindi (tashqaridan bosish, swipe, yoki "Bekor qilish")
class PhotoSourceBottomSheet extends StatelessWidget {
  /// `PhotoSourceBottomSheet` konstruktor.
  const PhotoSourceBottomSheet({super.key});

  /// Bottom sheet'ni ko'rsatadi va foydalanuvchi tanloviga qarab
  /// `ImageSource?` qaytaradi.
  static Future<ImageSource?> show(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (context) => const PhotoSourceBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle — vizual signal "swipe down to close".
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            // Sarlavha — 18sp Semibold (custom o'lcham, headlineL'dan kichik).
            Text(
              'childManagement.addEdit.photoSourceTitle'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.lg),

            // Galereya tugmasi — pop qilib `ImageSource.gallery` qaytaradi.
            _buildOption(
              icon: SolarIconsBold.gallery,
              label: 'voiceChat.attachGallery'.tr(),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),

            // Kamera tugmasi — faqat mobil/native platformalarda ko'rinadi.
            //
            // Web'da `image_picker_for_web` `ImageSource.camera`'ni galereyaga
            // fallback qiladi (browser API cheklovi) — foydalanuvchi
            // chalkashmasligi uchun yashiramiz. Desktop emas, mobile web
            // (Android Chrome) ham ostida — chunki asosiy maqsad native
            // ilova, web faqat dev test uchun.
            if (!kIsWeb) ...[
              _buildOption(
                icon: SolarIconsBold.camera,
                label: 'voiceChat.attachCamera'.tr(),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 12),
            ],

            // "Bekor qilish" — pop qiladi (qiymatsiz → null qaytadi).
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common.cancel'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bitta tanlov tugmasi — pill shaped, lime green ikonkali.
  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return Material(
      color: AppColors.surfaceVariant,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          height: AppDimensions.buttonHeight,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.accent, size: AppDimensions.iconM),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodyM.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
