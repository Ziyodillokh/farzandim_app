// YoutubePlayerScreen — admin "link orqali" qo'shgan YouTube videolari.
// youtube_player_iframe (webview ustida YouTube IFrame API) bilan o'ynaydi.
// To'g'ridan-to'g'ri .mp4 havolalar esa ClassicVideoPlayerScreen'da.
//
// Ba'zi YouTube videolari egasi tomonidan "embed" qilish taqiqlangan
// (xato 101/150/152). Bunday holatda IFrame o'zining xom xato sahifasini
// ko'rsatadi — biz uni ushlab, chiroyli "YouTube'da ochish" ekraniga
// almashtiramiz (professional fallback).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';

class YoutubePlayerScreen extends ConsumerStatefulWidget {
  const YoutubePlayerScreen({required this.video, super.key});

  final VideoModel video;

  @override
  ConsumerState<YoutubePlayerScreen> createState() =>
      _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends ConsumerState<YoutubePlayerScreen> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;

  // Embed taqiqlangan yoki video o'chirilgan — fallback ekran ko'rsatamiz.
  bool _failed = false;

  // Haqiqiy duration backend'ga bir marta yuborilgan bo'lsin.
  bool _durationReported = false;

  @override
  void initState() {
    super.initState();
    final id = widget.video.youtubeId;
    if (id == null) {
      _failed = true;
      return;
    }
    final controller = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        // Bola ilovasi — boshqa kanal videolarini tavsiya qilmaymiz.
        strictRelatedVideos: true,
      ),
    );
    _controller = controller;
    // Xato bo'lsa (embed taqiq, o'chirilgan video) fallback'ga o'tamiz.
    // Video yuklangach haqiqiy davomiylikni backend'ga yuboramiz (agar
    // hozir noma'lum bo'lsa) — ro'yxatda to'g'ri vaqt ko'rinsin.
    _sub = controller.stream.listen((value) {
      if (value.error != YoutubeError.none && !_failed && mounted) {
        setState(() => _failed = true);
      }
      final dur = value.metaData.duration.inSeconds;
      if (!_durationReported &&
          dur > 0 &&
          widget.video.durationSeconds <= 0) {
        _durationReported = true;
        ref
            .read(videosBackendRepositoryProvider)
            .reportDuration(widget.video.id, dur);
      }
    });
    // Ko'rishlar hisoblagichi (backend analitikasi) — bir marta.
    ref.read(videosBackendRepositoryProvider).markViewed(widget.video.id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller?.close();
    super.dispose();
  }

  Future<void> _openInYoutube() async {
    final uri = Uri.tryParse(widget.video.videoUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Qurilmada ochadigan ilova/brauzer yo'q — jim o'tkazamiz.
      debugPrint('YoutubePlayer._openInYoutube: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null) {
      return _ErrorScaffold(
        title: widget.video.title,
        thumbnailUrl: widget.video.thumbnailUrl,
        onOpenYoutube: _openInYoutube,
      );
    }

    return YoutubePlayerScaffold(
      controller: _controller!,
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              widget.video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              // Har doim: tashqi YouTube'da ochish imkoni.
              IconButton(
                tooltip: 'YouTube',
                onPressed: _openInYoutube,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              player,
              if (widget.video.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.video.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Embed taqiqlangan/o'chirilgan video uchun chiroyli fallback ekran.
class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.title,
    required this.thumbnailUrl,
    required this.onOpenYoutube,
  });

  final String title;
  final String thumbnailUrl;
  final Future<void> Function() onOpenYoutube;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumbnailUrl.isNotEmpty
                      ? Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF1C1C24),
                          ),
                        )
                      : const ColoredBox(color: Color(0xFF1C1C24)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bu videoni ilova ichida ochib bo\'lmadi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Video egasi uni boshqa ilovalarda ko\'rsatishni '
                'cheklagan. YouTube ilovasida ochib ko\'ring.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenYoutube,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("YouTube'da ochish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
