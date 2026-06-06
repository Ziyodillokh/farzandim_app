// ─────────────────────────────────────────────────────────────────────
// DashboardTopHeader — Dashboard yuqorisi
// ─────────────────────────────────────────────────────────────────────
//
// Chap: Farzandim logo 58×58 (asset).
// O'ng: Settings tugma (48×48) +
//   - `onNotificationsTap` berilsa: 🔔 bell (badge bilan) — Dashboard.
//   - aks holda: 👤 avatar circle — boshqa ekranlar (Videos/Rankings/...).
//
// Avatar URL — provider'dan avtomatik o'qiladi (pairing state'dagi childId
// orqali `childAvatarUrlProvider`). Foydalanuvchi rasm yuklagan bo'lsa
// shu rasm ko'rinadi; aks holda fallback person icon.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const double _kHeaderSize = 58;

class DashboardTopHeader extends ConsumerWidget {
  const DashboardTopHeader({
    this.onAvatarTap,
    this.onSettingsTap,
    this.photoUrl,
    this.onNotificationsTap,
    this.unreadCount = 0,
    super.key,
  });

  // ─── Avatar (eski rejim — boshqa ekranlar uchun) ────────────────
  /// Parent App'dan yuklangan bola rasmining signed URL. `null` bo'lsa
  /// provider'dan avtomatik o'qiladi (pairing state'dagi childId orqali).
  final String? photoUrl;
  final VoidCallback? onAvatarTap;

  // ─── Bildirishnoma (yangi rejim — Dashboard uchun) ──────────────
  final VoidCallback? onNotificationsTap;
  final int unreadCount;

  /// Sozlamalar tugmasi tap. `null` bo'lsa tugma ko'rinmaydi.
  final VoidCallback? onSettingsTap;

  bool get _useBell => onNotificationsTap != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // photoUrl explicit berilmagan bo'lsa — provider'dan auto-fetch.
    // Foydalanuvchi rasm yuklagan bo'lsa bu signed URL'ni qaytaradi.
    String? resolvedPhoto = photoUrl;
    if (!_useBell && resolvedPhoto == null) {
      final childId = ref.watch(pairingStateProvider).childId;
      if (childId != null && childId.isNotEmpty) {
        resolvedPhoto = ref.watch(childAvatarUrlProvider(childId)).valueOrNull;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/child_logo_icon.png',
            height: _kHeaderSize,
            width: _kHeaderSize,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          if (onSettingsTap != null) ...[
            _SettingsButton(onTap: onSettingsTap!),
            const SizedBox(width: 12),
          ],
          if (_useBell)
            _NotificationsButton(
              onTap: onNotificationsTap!,
              badgeCount: unreadCount,
            )
          else
            _Avatar(
              photoUrl: resolvedPhoto,
              onTap: onAvatarTap ?? () {},
            ),
        ],
      ),
    );
  }
}

// Top header tugmalarining yagona o'lchami — settings + bell vizual mos
// kelishi uchun (avval 48 vs 58 edi).
const double _kHeaderButton = 48;
const double _kHeaderButtonIcon = 24;

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _kHeaderButton,
        height: _kHeaderButton,
        decoration: BoxDecoration(
          color: context.adaptive.bgSurface,
          shape: BoxShape.circle,
          border: Border.all(color: context.adaptive.border, width: 1.5),
        ),
        child: Icon(
          AppIcons.settings,
          color: context.adaptive.textSecondary,
          size: _kHeaderButtonIcon,
        ),
      ),
    );
  }
}

// ─── Bildirishnoma tugmasi (avval pastki nav'da edi) ──────────────────
class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.onTap, required this.badgeCount});

  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _kHeaderButton,
            height: _kHeaderButton,
            decoration: BoxDecoration(
              color: context.adaptive.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(color: context.adaptive.border, width: 1.5),
            ),
            child: Icon(
              AppIcons.bell,
              color: context.adaptive.textSecondary,
              size: _kHeaderButtonIcon,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: context.adaptive.bgPrimary,
                    width: 2,
                  ),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.onTap});

  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _kHeaderSize,
        height: _kHeaderSize,
        decoration: BoxDecoration(
          color: context.adaptive.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: context.adaptive.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _AvatarFallback(),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const _AvatarFallback();
                },
              )
            : const _AvatarFallback(),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      AppIcons.profile,
      color: context.adaptive.textSecondary,
      size: 30,
    );
  }
}
