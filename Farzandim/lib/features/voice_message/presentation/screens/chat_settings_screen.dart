// Chat sozlamalari ekrani: orqa fon va mavzu (light/dark) tanlash.

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/services/image_picker_service.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/theme/theme_mode_provider.dart';
import 'package:farzandim/features/voice_message/presentation/providers/chat_wallpaper_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  bool _picking = false;

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final x = await ref.read(imagePickerServiceProvider).pickImageFile(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1440,
      );
      if (x == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          '${dir.path}/chat_wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(x.path).copy(dest);
      await ref.read(chatWallpaperProvider.notifier).setImage(dest);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'voiceChat.mediaSendError'.tr());
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final wp = ref.watch(chatWallpaperProvider);
    final filePath = chatWallpaperFilePath(wp);
    final presetIndex = chatWallpaperPresetIndex(wp);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'chatSettings.title'.tr(),
          style: AppTextStyles.bodyM.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.md,
          AppDimensions.lg,
          AppDimensions.xl,
        ),
        children: [
          // ─── Mavzu (light / night) ───
          _SectionTitle(title: 'chatSettings.theme'.tr()),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  label: 'chatSettings.light'.tr(),
                  icon: Icons.light_mode_rounded,
                  selected: themeMode == AppThemeMode.light,
                  onTap: () {
                    if (themeMode != AppThemeMode.light) {
                      ref.read(themeModeProvider.notifier).toggle();
                    }
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: _ThemeOption(
                  label: 'chatSettings.dark'.tr(),
                  icon: Icons.dark_mode_rounded,
                  selected: themeMode == AppThemeMode.dark,
                  onTap: () {
                    if (themeMode != AppThemeMode.dark) {
                      ref.read(themeModeProvider.notifier).toggle();
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.xl),

          // ─── Orqa fon ───
          _SectionTitle(title: 'chatSettings.wallpaper'.tr()),
          const SizedBox(height: 4),
          Text(
            'chatSettings.wallpaperHint'.tr(),
            style: AppTextStyles.bodyS.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: AppDimensions.md,
            crossAxisSpacing: AppDimensions.md,
            childAspectRatio: 0.66,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Standart (ilova gradienti).
              _WallpaperTile(
                selected: wp == kChatWallpaperDefault,
                label: 'chatSettings.default'.tr(),
                onTap: () =>
                    ref.read(chatWallpaperProvider.notifier).setDefault(),
                preview: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.backgroundTop,
                        AppColors.backgroundBottom,
                      ],
                    ),
                  ),
                ),
              ),
              // Preset gradientlar.
              for (var i = 0; i < chatWallpaperPresets.length; i++)
                _WallpaperTile(
                  selected: presetIndex == i,
                  onTap: () =>
                      ref.read(chatWallpaperProvider.notifier).setPreset(i),
                  preview: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: chatWallpaperPresets[i],
                      ),
                    ),
                  ),
                ),
              // Joriy galereya rasmi (tanlangan bo'lsa).
              if (filePath != null && File(filePath).existsSync())
                _WallpaperTile(
                  selected: true,
                  onTap: _pickImage,
                  preview: Image.file(File(filePath), fit: BoxFit.cover),
                ),
              // Galereyadan tanlash.
              _WallpaperTile(
                selected: false,
                label: 'chatSettings.gallery'.tr(),
                onTap: _pickImage,
                preview: ColoredBox(
                  color: AppColors.surfaceVariant,
                  child: Center(
                    child: _picking
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primary,
                            size: 30,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.bodyM.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodyM.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.selected,
    required this.onTap,
    required this.preview,
    this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget preview;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: preview,
              ),
            ),
          ),
          if (label != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black.withValues(alpha: 0.45),
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}
