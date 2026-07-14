// "Akkount" — Tizim so'zlamalari "Akkount" qatoridan ochiladigan Parvoz
// bottom sheet (orqa fon = tizim so'zlamalari). Foydalanuvchi hisobi
// ma'lumotlari ko'rsatiladi: Email, Telefon, Login (= email/telefon), Parol.
//
// Har bir qator to'liq ishlaydi (backend endpointlari mavjud):
//   Email  → showEmailEditSheet  (OTP → yangi email; POST /users/me/email)
//   Telefon → showPhoneEditSheet  (OTP → yangi raqam; POST /users/me/phone)
//   Login  → showLoginEditSheet   (login = email/telefon; ularга yo'naltiradi)
//   Parol  → showPasswordEditSheet (eski parol yoki telefon OTP orqali)
// Pastda Chiqish (logout) va Yopish, hamda farzandlarni boshqarish va hisobni
// o'chirish (Play talabi) yo'llari saqlangan — dead code bo'lmasin.
//
// Eski to'liq ProfileScreen shu faylda sheet'ga aylantirildi. Ism/avatar
// tahriri dizaynda yo'q; provider metodlari (updateProfile/uploadAvatar)
// backend infratuzilmasi sifatida saqlanadi.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/features/profile/data/models/parent_profile.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/features/profile/presentation/screens/contact_edit_sheet.dart';
import 'package:farzandim/features/profile/presentation/screens/login_edit_sheet.dart';
import 'package:farzandim/features/profile/presentation/screens/password_edit_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF0F141A);
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _line = Color(0x14FFFFFF); // maydon ajratgichi (oq 8%)
const _dim = Color(0x99FFFFFF); // oq 60%
const _danger = Color(0xFFFF5A5A);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.4,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// "Akkount" bottom sheet'ini ochadi.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet();

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  /// Avatar yuklanayotgan payt — ustiga spinner ko'rsatiladi.
  bool _uploading = false;

  /// Telefonni tahrirlash — OTP varag'i (POST /users/me/phone).
  void _editPhone() => showPhoneEditSheet(context);

  /// Emailni tahrirlash — OTP varag'i (POST /users/me/email).
  void _editEmail() => showEmailEditSheet(context);

  /// Login (= email/telefon) varag'i.
  void _editLogin() => showLoginEditSheet(context);

  /// Parolni tahrirlash — eski parol yoki OTP orqali.
  void _editPassword() => showPasswordEditSheet(context);

  void _close() => Navigator.of(context).pop();

  /// Modal ichidan boshqa sahifaga: avval sheet'ni yopamiz, keyin push.
  void _goto(String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _cardBorder),
        ),
        title: Text('settings.logout.dialogTitle'.tr(), style: _unb(17)),
        content: Text(
          'settings.logout.dialogContent'.tr(),
          style: _pop(14, c: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'settings.logout.cancel'.tr(),
              style: _pop(15, c: _dim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'settings.logout.confirm'.tr(),
              style: _pop(15, w: FontWeight.w600, c: _danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Provider'larni await'dan OLDIN olamiz — logout sheet'ni yopib yuborsa
    // (router redirect) `ref` disposed bo'lib qolmasin.
    final fcm = ref.read(fcmServiceProvider);
    final auth = ref.read(backendAuthProvider.notifier);
    try {
      await fcm.removeTokenForCurrentUser();
    } catch (_) {
      // token o'chirish xatosi logout'ni to'xtatmasin.
    }
    // Logout → auth holati o'zgaradi → router Welcome'ga qaytaradi, sheet
    // avtomatik yopiladi.
    await auth.logout();
  }

  /// Profil rasmini tanlab (galereya/kamera) backend'ga yuklaydi.
  /// Provider `uploadAvatar` → `/users/me/avatar` (POST) → profil qayta yuklanadi.
  Future<void> _pickAndUploadAvatar() async {
    if (_uploading) return;
    // Manba tanlash (galereya / kamera).
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _bg,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SourceRow(
                icon: SolarIconsOutline.gallery,
                label: 'account.fromGallery'.tr(),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              _SourceRow(
                icon: SolarIconsOutline.camera,
                label: 'account.fromCamera'.tr(),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      // maxWidth/quality — 5 MB backend limitidan xotirjam pastda turish uchun.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _uploading = true);
      await ref.read(profileProvider.notifier).uploadAvatar(bytes);
      if (mounted) AppToast.success(context, 'account.photoUpdated'.tr());
    } catch (_) {
      if (mounted) AppToast.error(context, 'account.photoError'.tr());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Ismdan bosh harflar (rasm bo'lmaganda ko'rsatiladi).
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return '';
    final letters = parts.take(2).map((s) => s.substring(0, 1).toUpperCase());
    return letters.join();
  }

  /// Profil rasmi bloki — doira avatar + kamera belgisi, tegilsa yuklaydi.
  Widget _avatarSection(ParentProfile p) {
    final photo = (p.photoUrl ?? '').trim();
    final initials = _initials(p.name);
    Widget fallback() => Center(
      child: initials.isNotEmpty
          ? Text(initials, style: _unb(26, w: FontWeight.w700))
          : const Icon(SolarIconsBold.user, color: _dim, size: 40),
    );

    return Center(
      child: GestureDetector(
        onTap: _pickAndUploadAvatar,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _cardBorder),
                ),
                child: ClipOval(
                  child: _uploading
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : (photo.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: photo,
                                fit: BoxFit.cover,
                                width: 96,
                                height: 96,
                                memCacheWidth: 240,
                                errorWidget: (_, __, ___) => fallback(),
                                placeholder: (_, __) => fallback(),
                              )
                            : fallback()),
                ),
              ),
              // Kamera belgisi — pastki o'ngda.
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF216BFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 3),
                  ),
                  child: const Icon(
                    SolarIconsBold.camera,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider);
    final email = (p.email ?? '').trim();
    final phone = (p.phoneNumber ?? '').trim();
    final login = email.isNotEmpty ? email : phone;
    String orDash(String s) => s.isNotEmpty ? s : '—';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _avatarSection(p),
                const SizedBox(height: 10),
                // Rasmni o'zgartirish uchun yo'l-yo'riq matni.
                Text(
                  'account.changePhoto'.tr(),
                  textAlign: TextAlign.center,
                  style: _pop(12.5, c: _dim),
                ),
                const SizedBox(height: 16),
                Text(
                  'account.title'.tr(),
                  textAlign: TextAlign.center,
                  style: _unb(17, w: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'account.email'.tr(),
                  value: orDash(email),
                  onEdit: _editEmail,
                ),
                _Field(
                  label: 'account.phone'.tr(),
                  value: orDash(phone),
                  onEdit: _editPhone,
                ),
                _Field(
                  label: 'account.login'.tr(),
                  value: orDash(login),
                  onEdit: _editLogin,
                ),
                _Field(
                  label: 'account.password'.tr(),
                  value: '••••••••',
                  isPassword: true,
                  onEye: _editPassword,
                  onEdit: _editPassword,
                ),
                const SizedBox(height: 6),
                _NavRow(
                  icon: SolarIconsBold.usersGroupRounded,
                  label: 'account.manageChildren'.tr(),
                  onTap: () => _goto(AppRoutes.settingsChildren),
                ),
                const SizedBox(height: 18),
                ParvozSecondaryButton(
                  label: 'settings.logout.button'.tr(),
                  onPressed: _logout,
                ),
                const SizedBox(height: 10),
                ParvozSecondaryButton(
                  label: 'common.close'.tr(),
                  onPressed: _close,
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => _goto(AppRoutes.settingsDeleteAccount),
                    child: Text(
                      'settings.deleteAccount'.tr(),
                      style: _pop(13, c: _danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ma'lumot maydoni — yorliq + qiymat + qalam (parol bo'lsa ko'z ham),
/// ostida yupqa ajratgich chiziq.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onEdit,
    this.isPassword = false,
    this.onEye,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;
  final bool isPassword;
  final VoidCallback? onEye;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: _pop(13, c: _dim)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _unb(16, ls: -0.2),
              ),
            ),
            if (isPassword)
              _IconTap(icon: SolarIconsOutline.eye, onTap: onEye ?? onEdit),
            _IconTap(icon: SolarIconsOutline.pen, onTap: onEdit),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: _line),
      ],
    );
  }
}

/// Rasm manbasi qatori (galereya / kamera) — avatar tanlash varag'ida.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 14),
            Text(label, style: _pop(15, w: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Icon(icon, size: 20, color: _dim),
      ),
    );
  }
}

/// Navigatsiya qatori (farzandlarni boshqarish) — ikon + matn + chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: _pop(15, w: FontWeight.w500)),
            ),
            const Icon(SolarIconsOutline.altArrowRight, size: 20, color: _dim),
          ],
        ),
      ),
    );
  }
}
