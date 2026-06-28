import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/services/image_picker_service.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/profile/presentation/providers/profile_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/custom_text_field.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ota-ona profilini tahrirlash ekrani — ism va avatar.
///
/// Ism `PUT /users/me` bilan saqlanadi, avatar galereyadan tanlanib
/// backend'ga yuklanadi.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;
  bool _hydrated = false;
  bool _isUploadingAvatar = false;

  /// Ism majburiy (kamida 2 belgi).
  bool get _isFormValid => _nameController.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _hydrateFromProfile();
  }

  void _hydrateFromProfile() {
    final profile = ref.read(profileProvider);
    if (profile.name.isEmpty) {
      // Backend hali yuklanmagan — listener kelganda qayta urinamiz.
      return;
    }
    _nameController.text = profile.name;
    _hydrated = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_isFormValid) return;
    setState(() => _isSaving = true);

    try {
      await ref
          .read(profileProvider.notifier)
          .updateProfile(name: _nameController.text.trim());

      if (!mounted) return;
      AppToast.success(context, 'profile.savedSnack'.tr());
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.error(
        context,
        'profile.errorPrefix'.tr(namedArgs: {'error': '$e'}),
      );
    }
  }

  /// Galereyadan rasm tanlab, Backend'ga avatar sifatida yuklaydi.
  Future<void> _pickAndUploadAvatar() async {
    final bytes = await ImagePickerService().pickFromGallery();
    if (bytes == null) return;
    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(profileProvider.notifier).uploadAvatar(bytes);
      if (!mounted) return;
      AppToast.success(context, 'profile.savedSnack'.tr());
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        'profile.errorPrefix'.tr(namedArgs: {'error': '$e'}),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Backend'dan keyinroq kelgan profile bo'lsa controllers'ni bir
    // martalik to'ldiramiz (foydalanuvchi yozayotgan bo'lsa tegmaymiz).
    ref.listen(profileProvider, (prev, next) {
      if (_hydrated || next.name.isEmpty) return;
      _nameController.text = next.name;
      _hydrated = true;
      setState(() {});
    });

    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
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
                        child: _EditableAvatar(
                          photoUrl: profile.photoUrl,
                          isUploading: _isUploadingAvatar,
                          onTap: _pickAndUploadAvatar,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      _Label('profile.nameLabel'.tr()),
                      const SizedBox(height: AppDimensions.sm),
                      CustomTextField(
                        controller: _nameController,
                        hint: 'profile.nameHint'.tr(),
                        maxLength: 30,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: PrimaryButton(
                  label: 'profile.saveButton'.tr(),
                  icon: SolarIconsBold.checkCircle,
                  isLoading: _isSaving,
                  onPressed: _isFormValid && !_isSaving ? _onSave : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tahrirlanadigan avatar — bosilganda galereya ochiladi, Backend'ga yuklaydi.
///
/// `photoUrl` null bo'lsa placeholder; `isUploading` paytida spinner.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.photoUrl,
    required this.isUploading,
    required this.onTap,
  });

  final String? photoUrl;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: isUploading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.accent,
                    ),
                  )
                : (photoUrl == null || photoUrl!.isEmpty
                      ? Icon(
                          SolarIconsBold.userRounded,
                          color: AppColors.textSecondary,
                          size: 48,
                        )
                      // memCacheWidth — to'liq o'lchamda dekod qilmay xotira
                      // tejaymiz.
                      : CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          errorWidget: (_, __, ___) => Icon(
                            SolarIconsBold.userRounded,
                            color: AppColors.textSecondary,
                            size: 48,
                          ),
                        )),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              child: const Icon(
                SolarIconsBold.camera,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
                SolarIconsBold.altArrowLeft,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'profile.headerTitle'.tr(),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
