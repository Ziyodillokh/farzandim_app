// ─────────────────────────────────────────────────────────────────────
// ChatSettingsScreen — chat orqa foni + mavzu (Parent App'dan port)
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanuvchi (bola) bu ekrandan:
//   - Light/Dark mavzu tanlaydi (themeModeProvider'ga yoziladi)
//   - Chat orqa fonini tanlaydi (default / preset / galereya rasm)

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/theme_mode_provider.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/chat_wallpaper_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    // Web'da `path_provider` + `dart:io` File ishlamaydi — wallpaper rasmini
    // o'zgartirish faqat mobilda. Web user'iga snackbar.
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Galereyadan rasm tanlash faqat mobil ilovada'),
        ),
      );
      return;
    }
    setState(() => _picking = true);
    try {
      final x = await ImagePicker().pickImage(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rasmni yuklashda xato')),
        );
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
      backgroundColor: context.adaptive.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.adaptive.bgPrimary,
        foregroundColor: context.adaptive.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'chatSettings.title'.tr(),
          style: TextStyle(
            color: context.adaptive.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          // ─── Mavzu (light / dark) ───
          _SectionTitle(title: 'chatSettings.theme'.tr()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  label: 'chatSettings.light'.tr(),
                  icon: Icons.light_mode_rounded,
                  selected: themeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ThemeOption(
                  label: 'chatSettings.dark'.tr(),
                  icon: Icons.dark_mode_rounded,
                  selected: themeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.dark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ─── Orqa fon ───
          _SectionTitle(title: 'chatSettings.wallpaper'.tr()),
          const SizedBox(height: 4),
          Text(
            'chatSettings.wallpaperHint'.tr(),
            style: TextStyle(
              color: context.adaptive.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.66,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Standart (ilova foni).
              _WallpaperTile(
                selected: wp == kChatWallpaperDefault,
                label: 'chatSettings.default'.tr(),
                onTap: () =>
                    ref.read(chatWallpaperProvider.notifier).setDefault(),
                preview: ColoredBox(color: context.adaptive.bgPrimary),
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
              // Joriy galereya rasmi (tanlangan bo'lsa) — faqat mobil.
              if (!kIsWeb &&
                  filePath != null &&
                  File(filePath).existsSync())
                _WallpaperTile(
                  selected: true,
                  onTap: _pickImage,
                  preview: Image.file(File(filePath), fit: BoxFit.cover),
                ),
              // Galereyadan tanlash tugmasi.
              _WallpaperTile(
                selected: false,
                label: 'chatSettings.gallery'.tr(),
                onTap: _pickImage,
                preview: ColoredBox(
                  color: context.adaptive.bgCard,
                  child: Center(
                    child: _picking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
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
      style: TextStyle(
        color: context.adaptive.textPrimary,
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
              : context.adaptive.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : context.adaptive.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  selected ? AppColors.primary : context.adaptive.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.adaptive.textPrimary
                    : context.adaptive.textSecondary,
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
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : context.adaptive.border,
                    width: selected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
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
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.check, color: Colors.black, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}
