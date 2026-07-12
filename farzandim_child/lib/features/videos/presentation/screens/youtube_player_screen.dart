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
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:farzandim_child/core/config/env_config.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/data/repositories/videos_backend_repository.dart';
import 'package:farzandim_child/features/videos/presentation/providers/video_engagement_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_ui.dart';
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

  Future<void> _share() async {
    try {
      await Share.share('${widget.video.title}\n${widget.video.videoUrl}');
    } catch (e) {
      debugPrint('YoutubePlayer._share: $e');
    }
  }

  String _fmtViews(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String _metaLine(VideoModel v) {
    final parts = <String>[];
    final cat = v.category.trim();
    if (cat.isNotEmpty && cat != 'Boshqa') parts.add(cat);
    parts.add("${_fmtViews(v.views)} ko'rish");
    if (v.duration.trim().isNotEmpty) parts.add(v.duration.trim());
    return parts.join('  ·  ');
  }

  // ── Portret (YouTube-simon): video 16:9 + info + like/share + SHU
  //    turkumdagi videolar (pastda, bosilsa o'sha video ochiladi). ──
  Widget _buildPortrait(WebViewController controller) {
    final video = widget.video;
    final all = ref.watch(effectiveVideosProvider);
    // Shu KATEGORIYADAGI boshqa videolar; bo'lmasa umumiy boshqa videolar.
    var related = all
        .where((v) => v.id != video.id && v.category == video.category)
        .toList();
    if (related.isEmpty) {
      related = all.where((v) => v.id != video.id).toList();
    }
    if (related.length > 12) related = related.sublist(0, 12);
    final favIds = ref.watch(favoriteVideoIdsProvider);
    final isFav = favIds.contains(video.id);

    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ParvozHeader(
            title: video.title,
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Text(
                  video.title,
                  style: const TextStyle(
                    color: AppColors.parvozText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _metaLine(video),
                  style: const TextStyle(
                    color: AppColors.parvozTextDim,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                // Amallar: To'liq ekran (asosiy) + Yoqtirish + Ulashish.
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _enterFullscreen,
                        icon: const Icon(Icons.fullscreen_rounded, size: 20),
                        label: const Text("To'liq ekran"),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.parvozGreen,
                          foregroundColor: AppColors.parvozOnGreen,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CircleAction(
                      icon: isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav
                          ? const Color(0xFFFF4D6D)
                          : AppColors.parvozText,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(favoriteVideoIdsProvider.notifier)
                            .toggle(video.id);
                      },
                    ),
                    const SizedBox(width: 10),
                    _CircleAction(
                      icon: Icons.share_rounded,
                      color: AppColors.parvozText,
                      onTap: _share,
                    ),
                  ],
                ),
                if (video.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    video.description,
                    style: const TextStyle(
                      color: AppColors.parvozTextDim,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Divider(color: Color(0x1FFFFFFF), height: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Shu turkumdagi videolar',
                    style: TextStyle(
                      color: AppColors.parvozText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final v in related)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: VideoFeedCard(
                        video: v,
                        isFavorite: favIds.contains(v.id),
                        // Bosilsa o'sha video ochiladi (joriy o'rniga —
                        // webview yopiladi, xotira tejaladi).
                        onTap: () =>
                            context.pushReplacement('/video-player', extra: v),
                      ),
                    ),
                ],
              ],
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

// Dumaloq amal tugmasi (yoqtirish / ulashish) — shisha fon + rim.
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
