// ─────────────────────────────────────────────────────────────────────
// DashboardTopHeader — Dashboard yuqorisi (Sprint UI.4 redesign)
// ─────────────────────────────────────────────────────────────────────
//
// Chap: Farzandim logo 58×58 (asset).
// O'ng: Settings tugma (48×48) + Avatar circle 58×58.
//   - Settings → /settings (til, tema, hisob, ...)
//   - Avatar → /account-edit (Parent App'dan yuklangan bola rasmi).

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:flutter/material.dart';

const double _kHeaderSize = 58;

class DashboardTopHeader extends StatelessWidget {
  const DashboardTopHeader({
    required this.onAvatarTap,
    this.onSettingsTap,
    this.photoUrl,
    super.key,
  });

  /// Parent App'dan yuklangan bola rasmining signed URL.
  /// `null` bo'lsa default `Icon.person` ko'rinadi.
  final String? photoUrl;
  final VoidCallback onAvatarTap;

  /// Sozlamalar tugmasi tap. `null` bo'lsa tugma ko'rinmaydi.
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
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
          _Avatar(photoUrl: photoUrl, onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: const Icon(
          AppIcons.settings,
          color: AppColors.textSecondary,
          size: 22,
        ),
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
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1.5),
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
    return const Icon(
      AppIcons.profile,
      color: AppColors.textSecondary,
      size: 30,
    );
  }
}
