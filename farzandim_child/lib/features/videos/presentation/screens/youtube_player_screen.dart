// YoutubePlayerScreen — admin "link orqali" qo'shgan YouTube videolari.
//
// To'g'ridan-to'g'ri `youtube.com/embed/ID` ni webview'da ochamiz (admin
// paneldagi embed bilan bir xil — ishonchli). iframe-API paketi lokal
// origin sababli barcha videolarni "unavailable" deb rad etardi.
//
// To'g'ridan-to'g'ri .mp4 havolalar esa ClassicVideoPlayerScreen'da.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final id = widget.video.youtubeId;
    if (id == null) return;

    // MUHIM: embed URL'ni TO'G'RIDAN-TO'G'RI ochsak (loadRequest) webview'da
    // referer bo'lmaydi va YouTube "Xato 153" beradi. Shuning uchun iframe'ni
    // HTML sifatida, baseUrl bilan yuklaymiz — shunda parent origin youtube.com
    // bo'ladi va embed qabul qilinadi (admin paneldagi iframe bilan bir xil).
    // playsinline=1 — ichida o'ynaydi; rel=0 — faqat shu kanal videolari.
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html,body{margin:0;padding:0;background:#000;height:100%;}
  .wrap{position:fixed;top:0;left:0;right:0;bottom:0;}
  iframe{width:100%;height:100%;border:0;}
</style>
</head>
<body>
<div class="wrap">
<iframe
  src="https://www.youtube.com/embed/$id?playsinline=1&rel=0&modestbranding=1"
  allow="autoplay; encrypted-media; picture-in-picture"
  allowfullscreen></iframe>
</div>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: 'https://www.youtube.com');

    // Ko'rishlar hisoblagichi (backend analitikasi) — bir marta.
    ref.read(videosBackendRepositoryProvider).markViewed(widget.video.id);
  }

  Future<void> _openInYoutube() async {
    final uri = Uri.tryParse(widget.video.videoUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('YoutubePlayer._openInYoutube: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
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
          IconButton(
            tooltip: 'YouTube',
            onPressed: _openInYoutube,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: controller == null
          ? const Center(
              child: Text(
                "Video havolasi noto'g'ri",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        WebViewWidget(controller: controller),
                        if (_loading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
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
  }
}
