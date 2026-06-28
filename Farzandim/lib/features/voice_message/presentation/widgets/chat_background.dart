// ─────────────────────────────────────────────────────────────────────
// ChatBackground — chat orqa foni (default gradient / preset / rasm)
// ─────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:farzandim/features/voice_message/presentation/providers/chat_wallpaper_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tanlangan wallpaper'ni chat orqasida ko'rsatadi. Rasm fon bo'lsa,
/// bubble/header o'qilishi uchun yengil scrim qo'shadi.
class ChatBackground extends ConsumerWidget {
  const ChatBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wp = ref.watch(chatWallpaperProvider);

    final presetIndex = chatWallpaperPresetIndex(wp);
    if (presetIndex != null &&
        presetIndex >= 0 &&
        presetIndex < chatWallpaperPresets.length) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: chatWallpaperPresets[presetIndex],
          ),
        ),
        child: child,
      );
    }

    final filePath = chatWallpaperFilePath(wp);
    if (filePath != null &&
        filePath.isNotEmpty &&
        File(filePath).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(filePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const GradientBackground(child: SizedBox.expand()),
          ),
          // O'qilishi uchun yengil to'q scrim (yuqori + past quyuqroq).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.40),
                ],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),
          child,
        ],
      );
    }

    // Default — ilovaning gradient foni.
    return GradientBackground(child: child);
  }
}
