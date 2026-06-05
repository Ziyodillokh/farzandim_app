import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/auth/data/repositories/backend_user_repository.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// _confirmWord endi locale'ga bog'liq — `deleteAccount.confirmWord.tr()`
// orqali har til uchun mos so'z olinadi (uz: O'CHIRISH, ru: УДАЛИТЬ,
// en: DELETE). Build paytida `widget.build` ichida o'qiymiz.

/// Hisobni butunlay o'chirish ekrani.
///
/// Play Market policy (2024+) talabi: in-app account deletion. GDPR /
/// ZRU-547 compliance.
///
/// Oqim:
///   1. Foydalanuvchi `_confirmWord` ni harf-harf yozadi.
///   2. Tugma yoqiladi.
///   3. `deleteAccount` Cloud Function chaqiriladi:
///      - Firestore (users/{uid} + subcoll, top-level filterlar)
///      - Storage (avatars, voice/video/photo prefixes)
///      - Auth.deleteUser (eng oxiri)
///   4. signOut + Welcome'ga redirect.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  /// `DeleteAccountScreen` konstruktor.
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
      // Backend `DELETE /api/users/me` — cascade o'chirish (bola(lar),
      // lokatsiya, xabarlar, obuna). So'ng logout + Welcome'ga qaytish.
      await ref.read(backendUserRepositoryProvider).deleteAccount();
      await ref.read(backendAuthProvider.notifier).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('deleteAccount.deletedSnack'.tr())),
      );
      context.go(AppRoutes.welcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'deleteAccount.unexpectedError'.tr(
              namedArgs: {'error': '$e'},
            ),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(disabled: _isDeleting),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimensions.lg),
                      Center(
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 64,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'deleteAccount.title'.tr(),
                        style: AppTextStyles.headlineL,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'deleteAccount.subtitle'.tr(),
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      _BulletList(items: [
                        'deleteAccount.items.profile'.tr(),
                        'deleteAccount.items.children'.tr(),
                        'deleteAccount.items.messages'.tr(),
                        'deleteAccount.items.geoZones'.tr(),
                        'deleteAccount.items.schedules'.tr(),
                        'deleteAccount.items.restrictions'.tr(),
                      ]),
                      const SizedBox(height: AppDimensions.lg),
                      Text(
                        'deleteAccount.confirmInstruction'.tr(
                          namedArgs: {
                            'word': 'deleteAccount.confirmWord'.tr(),
                          },
                        ),
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      TextField(
                        controller: _confirmController,
                        onChanged: _onConfirmChanged,
                        enabled: !_isDeleting,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'deleteAccount.confirmWord'.tr(),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusM,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_confirmed && !_isDeleting)
                            ? _deleteAccount
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusPill,
                            ),
                          ),
                        ),
                        child: _isDeleting
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    TextButton(
                      onPressed: _isDeleting ? null : () => context.pop(),
                      child: Text(
                        'deleteAccount.cancelButton'.tr(),
                        style: AppTextStyles.bodyM.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.disabled});

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: disabled ? null : () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'deleteAccount.headerTitle'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
