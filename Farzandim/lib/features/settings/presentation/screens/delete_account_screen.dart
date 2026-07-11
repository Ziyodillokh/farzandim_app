import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/data/repositories/backend_user_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

// ─── Yangi dizayn tokenlari (Manzillar/Joylashuv bilan bir xil) ───
const Color _bg = Color(0xFF0B0B10); // qora fon
const Color _cardBg = Color(0xFF1A1B22); // qoramtir karta
const Color _cardBorder = Color(0x14FFFFFF); // oq ~8% chegara
const Color _dim = Color(0x99FFFFFF); // oq 60% ikkilamchi matn
const Color _glassBtn = Color(0xE6121C2E); // top-bar tugma foni

// Tasdiq so'zi locale'ga bog'liq: 'deleteAccount.confirmWord'.tr() har
// til uchun mos so'zni beradi (uz: O'CHIRISH, ru: УДАЛИТЬ, en: DELETE).

/// Hisobni butunlay o'chirish ekrani (Play Market in-app deletion talabi).
///
/// Foydalanuvchi tasdiq so'zini to'liq yozgach hisob backend'da cascade
/// o'chiriladi, so'ng logout qilinib Welcome'ga qaytariladi.
///
/// REDIZAYN: eski gradient fon o'rniga yangi qora-glass dizayn (Manzillar
/// ekrani bilan bir xil top-bar, kartalar va Solar ikonlar).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _confirmed = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _onConfirmChanged(String value) {
    final ok = value.trim() == 'deleteAccount.confirmWord'.tr();
    if (ok != _confirmed) {
      setState(() => _confirmed = ok);
    }
  }

  Future<void> _deleteAccount() async {
    if (!_confirmed || _isDeleting) return;
    setState(() => _isDeleting = true);

    try {
      // Backend cascade o'chiradi: bola(lar), lokatsiya, xabarlar, obuna.
      // So'ng logout va Welcome'ga qaytamiz.
      await ref.read(backendUserRepositoryProvider).deleteAccount();
      await ref.read(backendAuthProvider.notifier).logout();
      if (!mounted) return;
      AppToast.success(context, 'deleteAccount.deletedSnack'.tr());
      context.go(AppRoutes.welcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppToast.error(
        context,
        'deleteAccount.unexpectedError'.tr(namedArgs: {'error': '$e'}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(disabled: _isDeleting),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.sm,
                  AppDimensions.md,
                  AppDimensions.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ogohlantirish hero (qizil uchburchak) ──
                    const _DangerHero(),
                    const SizedBox(height: AppDimensions.lg),

                    // ── "Nima o'chiriladi" kartasi (ikon + matn qatorlar) ──
                    const _DeleteItemsCard(),
                    const SizedBox(height: AppDimensions.lg),

                    // ── Tasdiq so'zini yozish ──
                    Text(
                      'deleteAccount.confirmInstruction'.tr(
                        namedArgs: {'word': 'deleteAccount.confirmWord'.tr()},
                      ),
                      style: AppTextStyles.bodyM.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm + 2),
                    _ConfirmField(
                      controller: _confirmController,
                      enabled: !_isDeleting,
                      confirmed: _confirmed,
                      onChanged: _onConfirmChanged,
                    ),
                  ],
                ),
              ),
            ),

            // ── Pastki amal tugmalari ──
            _BottomActions(
              enabled: _confirmed && !_isDeleting,
              isDeleting: _isDeleting,
              onDelete: _deleteAccount,
              onCancel: _isDeleting ? null : () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.disabled});

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Boshqa yangi ekranlar bilan bir xil: tepadan pastroq (md + 44).
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md + 44,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: SolarIconsOutline.arrowLeft,
            onTap: disabled ? null : () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'deleteAccount.headerTitle'.tr(),
                style: AppTextStyles.headlineL.copyWith(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // O'ng tomon bo'sh — sarlavha markazda tursin (simmetriya).
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}

/// Top-bar yumaloq-kvadrat shisha tugmasi (yangi dizayn uslubi).
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _glassBtn,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: Icon(icon, size: 22, color: Colors.white)),
        ),
      ),
    );
  }
}

// ════════════════════════ DANGER HERO ════════════════════════

/// Ekran boshidagi ogohlantirish belgisi + sarlavha + izoh.
class _DangerHero extends StatelessWidget {
  const _DangerHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            SolarIconsBold.dangerTriangle,
            size: 46,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Text(
          'deleteAccount.title'.tr(),
          style: AppTextStyles.headlineL.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'deleteAccount.subtitle'.tr(),
          style: AppTextStyles.bodyS.copyWith(color: _dim, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ════════════════════ NIMA O'CHIRILADI KARTASI ════════════════════

/// O'chiriladigan ma'lumotlar ro'yxati — har biri ikon-chip + matn.
class _DeleteItemsCard extends StatelessWidget {
  const _DeleteItemsCard();

  @override
  Widget build(BuildContext context) {
    // Har element: (Solar ikon, tarjima kaliti) — barchasi tasdiqlangan nomlar.
    const items = <(IconData, String)>[
      (SolarIconsBold.user, 'deleteAccount.items.profile'),
      (SolarIconsBold.usersGroupRounded, 'deleteAccount.items.children'),
      (SolarIconsBold.chatRoundLine, 'deleteAccount.items.messages'),
      (SolarIconsBold.mapPoint, 'deleteAccount.items.geoZones'),
      (SolarIconsBold.calendar, 'deleteAccount.items.schedules'),
      (SolarIconsBold.shield, 'deleteAccount.items.restrictions'),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _DeleteItemRow(icon: items[i].$1, textKey: items[i].$2),
            if (i != items.length - 1)
              const Divider(height: 1, thickness: 1, color: _cardBorder),
          ],
        ],
      ),
    );
  }
}

class _DeleteItemRow extends StatelessWidget {
  const _DeleteItemRow({required this.icon, required this.textKey});

  final IconData icon;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          // Qizil rangli yumshoq ikon-chip (o'chirish ma'nosini beradi).
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: AppColors.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              textKey.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ TASDIQ MAYDONI ════════════════════════

class _ConfirmField extends StatelessWidget {
  const _ConfirmField({
    required this.controller,
    required this.enabled,
    required this.confirmed,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool confirmed;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      enabled: enabled,
      textCapitalization: TextCapitalization.characters,
      cursorColor: AppColors.error,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      decoration: InputDecoration(
        hintText: 'deleteAccount.confirmWord'.tr(),
        hintStyle: const TextStyle(color: _dim, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: _cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        // Tasdiq so'zi mos kelsa — yashil belgi bilan bildiramiz.
        suffixIcon: confirmed
            ? Icon(SolarIconsBold.checkCircle, color: AppColors.success)
            : null,
        enabledBorder: border(_cardBorder),
        disabledBorder: border(_cardBorder),
        focusedBorder: border(
          confirmed ? AppColors.success : AppColors.error,
          1.4,
        ),
      ),
    );
  }
}

// ════════════════════════ PASTKI TUGMALAR ════════════════════════

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.enabled,
    required this.isDeleting,
    required this.onDelete,
    required this.onCancel,
  });

  final bool enabled;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        MediaQuery.of(context).padding.bottom + AppDimensions.md,
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: enabled ? onDelete : null,
              icon: isDeleting
                  ? const SizedBox.shrink()
                  : const Icon(SolarIconsBold.trashBinMinimalistic, size: 20),
              label: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'deleteAccount.deleteButton'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.error.withValues(
                  alpha: 0.30,
                ),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xs + 2),
          TextButton(
            onPressed: onCancel,
            child: Text(
              'deleteAccount.cancelButton'.tr(),
              style: AppTextStyles.bodyM.copyWith(color: _dim),
            ),
          ),
        ],
      ),
    );
  }
}
