import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bola avatari — yumaloq, jinsi va yoshga mos default sticker yoki
/// (agar mavjud bo'lsa) custom rasm bilan.
///
/// **3 ta holat (prioritet bo'yicha):**
/// 1. `child.photoBytes != null` → `Image.memory(bytes)` — foydalanuvchi
///    tanlagan rasm (transient, ilova yopilguncha)
/// 2. `child.photoUrl != null` → `Image.network(url)` — Firebase Storage'dan
///    (Bosqich 1.6'dan keyin)
/// 3. aks holda → `assets/stickers/`'dan SVG sticker
///    (`child.defaultStickerPath`)
///
/// **Foydalanish:**
/// ```dart
/// // Default (64dp, lime green border):
/// ChildAvatar(child: child)
///
/// // Kichikroq, bordersiz:
/// ChildAvatar(child: child, size: 40, showBorder: false)
/// ```
class ChildAvatar extends ConsumerWidget {
  /// `ChildAvatar` konstruktor.
  const ChildAvatar({
    required this.child,
    super.key,
    this.size = 64,
    this.showBorder = true,
  });

  /// Avatar ko'rsatiladigan bola.
  final Child child;

  /// Diametri (kenglik = balandlik). Default 64dp.
  final double size;

  /// `true` bo'lsa, atrofida 2dp lime green chegara. Default `true`.
  final bool showBorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Backend mode: signed URL'ni FutureProvider'dan o'qiymiz.
    // `null` qaytarilsa (Firebase mode yoki photo yo'q) — default sticker.
    final backendUrl = ref.watch(childAvatarUrlProvider(child.id)).valueOrNull;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Sticker SVG'larining fon'i transparent — surface rangi orqada.
        color: AppColors.surface,
        // Premium: lime green o'rniga nozik neutral border + soft shadow
        // (Apple/Linear stil). Lime green juda agressiv ko'rinardi.
        border: showBorder ? Border.all(color: AppColors.border) : null,
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      // ClipOval — ichki rasmni ham yumaloq qirqadi (BoxDecoration
      // o'z-o'zidan rasmni qirqmaydi, faqat border va background uchun).
      child: ClipOval(child: _buildAvatarImage(backendUrl)),
    );
  }

  /// Avatar rasmi — bytes / to'g'ridan http URL / Backend proxy / sticker.
  ///
  /// Prioritet:
  /// 1. `child.photoBytes` — transient, foydalanuvchi tanlagan rasm
  /// 2. `child.photoUrl` faqat `http...` bo'lsa — eski Firestore URL
  /// 3. `backendUrl` — Backend rasm proxy (`/children/:id/avatar/image`)
  /// 4. Default sticker
  ///
  /// Eslatma: Backend mode'da `child.photoUrl` — MinIO storage *key*
  /// (masalan `child-avatars/uuid.jpg`), network URL emas. Shuning uchun
  /// faqat `http` bilan boshlansa to'g'ridan ishlatamiz, aks holda proxy.
  Widget _buildAvatarImage(String? backendUrl) {
    final bytes = child.photoBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    final directUrl = child.photoUrl;
    final url = (directUrl != null && directUrl.startsWith('http'))
        ? directUrl
        : backendUrl;
    if (url != null) {
      // MEM-4: disk-keshli rasm — avatar har cold-start'da backend'dan
      // qayta yuklanmaydi (100k user'da katta tarmoq tejovi + tez UI).
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        // Avatar kichik doira — to'liq o'lchamda dekod qilmaslik.
        memCacheWidth: 200,
        errorWidget: (_, __, ___) => _defaultSticker(),
        placeholder: (_, __) => _defaultSticker(),
      );
    }
    return _defaultSticker();
  }

  Widget _defaultSticker() =>
      SvgPicture.asset(child.defaultStickerPath, fit: BoxFit.cover);
}
