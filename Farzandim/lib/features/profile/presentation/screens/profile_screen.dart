// "Akkount" — Tizim so'zlamalari "Akkount" qatoridan ochiladigan Parvoz
// bottom sheet (orqa fon = tizim so'zlamalari). Foydalanuvchi hisobi
// ma'lumotlari ko'rsatiladi: Email, Telefon, Login (= email/telefon), Parol.
//
// Telefon qalami → showPhoneEditSheet (to'liq ishlaydi, OTP orqali).
// Email qalami → showEmailEditSheet (dizayn tayyor, backend endpointi yo'q —
// saqlash "tez kunda"). Login/parol qalamlari hali "tez kunda" toast
// ko'rsatadi. Pastda Chiqish (logout) va Yopish, hamda farzandlarni boshqarish
// va hisobni o'chirish (Play talabi) yo'llari saqlangan — dead code bo'lmasin.
//
// Eski to'liq ProfileScreen shu faylda sheet'ga aylantirildi. Ism/avatar
// tahriri dizaynda yo'q; provider metodlari (updateProfile/uploadAvatar)
// backend infratuzilmasi sifatida saqlanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/features/profile/presentation/screens/contact_edit_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  void _editSoon() => AppToast.info(context, 'account.editSoon'.tr());

  /// Telefonni tahrirlash — to'liq ishlaydigan OTP varag'i (backend bor).
  void _editPhone() => showPhoneEditSheet(context);

  /// Emailni tahrirlash — dizayn varag'i (backend endpointi hali yo'q).
  void _editEmail() => showEmailEditSheet(context);

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
                  onEdit: _editSoon,
                ),
                _Field(
                  label: 'account.password'.tr(),
                  value: '••••••••',
                  isPassword: true,
                  onEye: _editSoon,
                  onEdit: _editSoon,
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
