// YoutubePlayerScreen — admin "link orqali" qo'shgan YouTube videolari.
//
// Backend domenida xizmat qilinadigan embed sahifasini (/content/yt/:id)
// webview'da ochamiz — sahifa haqiqiy https domende bo'lgani uchun iframe
// referer'i to'g'ri va YouTube embed ishlaydi (admin paneldagidek).
//
// UX: portretda video 16:9 yuqorida, ostida sarlavha + "To'liq ekran"
// tugmasi + tavsif (qora bo'sh joy o'rniga foydali kontent). Gorizontal
// (to'liq ekran) — tugma bilan: qurilma landscape'ga buriladi, immersive
// rejim, webview butun ekranni qoplaydi (ClassicVideoPlayer bilan izchil).
//
// To'g'ridan-to'g'ri .mp4 havolalar esa ClassicVideoPlayerScreen'da.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';

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
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    final id = widget.video.youtubeId;
    if (id == null) return;

    // YouTube embed sahifasini BACKEND domenidan yuklaymiz (loadRequest).
    // Sahifa haqiqiy https domende xizmat qilingani uchun iframe referer'i
    // to'g'ri bo'ladi (admin paneldagidek) va xato 153 chiqmaydi.
    final embedPage = Uri.parse('${EnvConfig.apiUrl}/content/yt/$id');

    _controller = WebViewController()
      // Chrome UA — default Android WebView UA ('; wv') ni YouTube embed
      // player ko'pincha bloklab "Xato 153" berardi; haqiqiy Chrome UA bilan
      // ishlaydi.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(embedPage);

    // Ko'rishlar hisoblagichi (backend analitikasi) — bir marta.
    ref.read(videosBackendRepositoryProvider).markViewed(widget.video.id);
  }

  @override
  void dispose() {
    // Ekrandan chiqishda orientatsiya/UI'ni portretga qaytaramiz (boshqa
    // ekranlar landscape'da qotib qolmasin).
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _enterFullscreen() {
    setState(() => _fullscreen = true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() => _fullscreen = false);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    if (controller == null) {
      return const Scaffold(
        backgroundColor: AppColors.parvozBg,
        body: Center(
          child: Text(
            "Video havolasi noto'g'ri",
            style: TextStyle(color: AppColors.parvozTextDim),
          ),
        ),
      );
    }

    // To'liq ekran (landscape) — back tugmasi avval fullscreen'dan chiqaradi,
    // keyin ekrandan.
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _exitFullscreen();
      },
      child: _fullscreen
          ? _buildFullscreen(controller)
          : _buildPortrait(controller),
    );
  }

  // ── Portret: video 16:9 + sarlavha + "To'liq ekran" + tavsif ──
  Widget _buildPortrait(WebViewController controller) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ParvozHeader(
            title: widget.video.title,
            onBack: () => Navigator.of(context).maybePop(),
            trailing: GestureDetector(
              onTap: _openInYoutube,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.open_in_new_rounded,
                  color: AppColors.parvozText,
                  size: 22,
                ),
              ),
            ),
          ),
          _videoBox(controller, showFullscreenButton: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: AppColors.parvozText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _enterFullscreen,
                      icon: const Icon(Icons.fullscreen_rounded),
                      label: const Text("To'liq ekranda ko'rish"),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.parvozGreen,
                        foregroundColor: AppColors.parvozOnGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (widget.video.description.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      widget.video.description,
                      style: const TextStyle(
                        color: AppColors.parvozTextDim,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── To'liq ekran (landscape): webview butun ekranni qoplaydi ──
  Widget _buildFullscreen(WebViewController controller) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: controller)),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.parvozGreen),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _GlassIconButton(
                  icon: Icons.fullscreen_exit_rounded,
                  onPressed: _exitFullscreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 16:9 video qutisi — webview + yuklanish + (ixtiyoriy) to'liq ekran tugmasi.
  Widget _videoBox(
    WebViewController controller, {
    required bool showFullscreenButton,
  }) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.parvozGreen),
              ),
            if (showFullscreenButton)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _GlassIconButton(
                    icon: Icons.fullscreen_rounded,
                    onPressed: _enterFullscreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Yarim-shaffof doira ustidagi oq ikon — video ustida ko'rinadigan tugma.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
