// ─────────────────────────────────────────────────────────────────────
// DashboardTopHeader — Dashboard yuqorisi
// ─────────────────────────────────────────────────────────────────────
//
// Chap: Farzandim logo 44×44 (asset). Tugmalardan bir oz kichikroq
// bo'lishi vizual ierarxiyani saqlaydi — logo "qichqiriqsiz" turadi.
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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Logo + avatar diametri. Tugmalar bilan deyarli teng — vizual balans.
const double _kHeaderSize = 50;

class DashboardTopHeader extends ConsumerWidget {
  const DashboardTopHeader({
    this.onAvatarTap,
    this.onSettingsTap,
    this.photoUrl,
    this.onNotificationsTap,
    this.unreadCount = 0,
    this.onSosTap,
    this.showSos = true,
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

  // ─── SOS pill (har doim mavjud — favqulodda yordam) ─────────────
  /// SOS pill tap. `null` bo'lsa default — `/dashboard` ga o'tadi
  /// (u yerda 3-sek hold-to-send tugmasi joylashgan).
  final VoidCallback? onSosTap;

  /// SOS pillni ko'rsatish (default `true`). Bola kirmagan / pairing
  /// holatida bo'lmaganlar uchun `false` qilish mumkin.
  final bool showSos;

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
          SvgPicture.asset(
            'assets/icons/parvoz_logo_mark.svg',
            height: _kHeaderSize,
            width: _kHeaderSize,
          ),
          const Spacer(),
          if (showSos) ...[
            _SosPill(onTap: onSosTap ?? () => context.push('/dashboard')),
            const SizedBox(width: 8),
          ],
          if (onSettingsTap != null) ...[
            _SettingsButton(onTap: onSettingsTap!),
            const SizedBox(width: 8),
          ],
          if (_useBell)
            _NotificationsButton(
              onTap: onNotificationsTap!,
              badgeCount: unreadCount,
            )
          else
            _Avatar(photoUrl: resolvedPhoto, onTap: onAvatarTap ?? () {}),
        ],
      ),
    );
  }
}

// Top header tugmalarining yagona o'lchami — settings + bell vizual mos
// kelishi uchun (avval 48 vs 58 edi).
const double _kHeaderButton = 52;
const double _kHeaderButtonIcon = 26;

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
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

// ─── SOS pill — favqulodda yordam tugmasi (yuqori header'da har doim) ──
// Skreenshot dizayniga muvofiq: qizil rounded pill, oq bell ikona + "SOS".
// Tap → dashboard'dagi 3-sek hold tugmasiga olib boradi (tasodifan
// yuborilib qolmasin — safety mexanizm saqlanadi).
class _SosPill extends StatelessWidget {
  const _SosPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _kHeaderButton,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33E53935),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
