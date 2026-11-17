// U13 · Videodars: kadr (16:9), nomi, fan/kategoriya, davomiyligi va tavsifi;
// «Ko'rish» mavjud pleyerni ochadi (YouTube / klassik — ko'rish tarixi va
// tugaganda DON o'sha yerda). Subtitr va matn ma'lumotlari serverda hali
// yo'q — ularning tugmalari ham yo'q.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VideoLessonScreen extends ConsumerWidget {
  const VideoLessonScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(effectiveVideosProvider);
    final video = videos.where((v) => v.id == videoId).firstOrNull;
    final top = GTopBar(
      leading: GTopBar.back(
        label: 'g5.common.back'.tr(),
        onPressed: () => context.pop(),
      ),
      title: video?.title ?? 'g5.library.videos'.tr(),
      subtitle: video?.category,
    );
    if (video == null) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: top,
          children: [
            if (videos.isEmpty)
              Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              )
            else
              GNote(
                text: 'g5.library.video.notFound'.tr(),
                kind: GNoteKind.warn,
              ),
          ],
        ),
      );
    }
    void watch() => context.push('/video-player', extra: video);
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: top,
        dock: GButton(
          label: 'g5.library.video.watch'.tr(),
          icon: GIcons.play,
          onPressed: watch,
        ),
        children: [
          _Frame(video: video, onTap: watch),
          Text(video.title, style: GText.h2),
          if (video.description.trim().isNotEmpty)
            Text(video.description, style: GText.body),
        ],
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.video, required this.onTap});

  final VideoModel video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = video.thumbnailUrl.trim();
    return GPressable(
      onTap: onTap,
      semanticLabel: '${'g5.library.video.watch'.tr()}: ${video.title}',
      pressedScale: .985,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GRadius.card),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF0B1022)),
                )
              else
                const ColoredBox(color: Color(0xFF0B1022)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00050915), Color(0xB3050915)],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: GEffects.primaryGradient,
                    boxShadow: GEffects.primaryShadow,
                  ),
                  alignment: Alignment.center,
                  child: const GIcon(
                    GIcons.play,
                    size: 28,
                    color: GColors.white,
                    secondaryOpacity: 0,
                  ),
                ),
              ),
              if (video.hasDuration)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: GChip(label: video.duration, kind: GChipKind.neutral),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
