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
// Android fullscreen callback (setCustomWidgetCallbacks) uchun platform impl.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
  // NATIVE fullscreen — webview HTML5 fullscreen (YouTube tugmasi yoki bizning
  // "To'liq ekran" JS orqali). Webview QAYTA YUKLANMAYDI → qotmaydi/qaytadan
  // boshlanmaydi. `_fullscreenWidget` — webview bergan fullscreen ko'rinishi.
  Widget? _fullscreenWidget;
  VoidCallback? _hideFullscreen;
  // Pastdagi videolar kategoriya chip filtri (null = "Hammasi").
  String? _relatedChip;

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

    // NATIVE fullscreen callback (Android) — webview HTML5 fullscreen'ni
    // (YouTube tugmasi/JS) qabul qiladi va webview'ni QAYTA YUKLAMASDAN
    // fullscreen ko'rsatadi. Avval Scaffold almashtirilib qayta yuklanardi →
    // qotish/qaytadan boshlash. Endi silliq.
    final platform = _controller!.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (Widget w, void Function() onHidden) {
          if (!mounted) return;
          setState(() {
            _fullscreenWidget = w;
            _hideFullscreen = onHidden;
          });
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onHideCustomWidget: () {
          if (!mounted) return;
          setState(() {
            _fullscreenWidget = null;
            _hideFullscreen = null;
          });
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        },
      );
    }

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

  // "To'liq ekran" — webview ICHIDAGI video/iframe'ni HTML5 fullscreen qiladi
  // (JS). Buni webview onShowCustomWidget qabul qiladi → native fullscreen,
  // QAYTA YUKLASH yo'q. (YouTube'ning o'z fullscreen tugmasi ham shu yo'l bilan.)
  void _requestWebviewFullscreen() {
    _controller?.runJavaScript(
      "(function(){var e=document.querySelector('iframe')||"
      "document.querySelector('video');if(!e)return;"
      "if(e.requestFullscreen)e.requestFullscreen();"
      "else if(e.webkitRequestFullscreen)e.webkitRequestFullscreen();})();",
    );
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

    // Fullscreen (native) ochiq bo'lsa — back tugmasi avval undan chiqaradi
    // (webview'ga fullscreen'ni yopishni aytamiz), keyin ekrandan.
    return PopScope(
      canPop: _fullscreenWidget == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreenWidget != null) _hideFullscreen?.call();
      },
      child: _fullscreenWidget != null
          ? _buildFullscreen()
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
    // Davomiylik faqat MA'LUM bo'lsa (0:00 mock ko'rsatmaymiz).
    if (v.durationSeconds > 0 && v.duration.trim().isNotEmpty) {
      parts.add(v.duration.trim());
    }
    return parts.join('  ·  ');
  }

  // ── Portret (YouTube-simon): video 16:9 + ixcham info + like/share +
  //    PINNED kategoriya chiplari + shu bo'yicha videolar. ──
  Widget _buildPortrait(WebViewController controller) {
    final video = widget.video;
    final all = ref.watch(effectiveVideosProvider);
    final others = all.where((v) => v.id != video.id).toList();
    // Kategoriya chiplari — mavjud (takrorsiz, non-Boshqa) janrlar.
    final cats = <String>[];
    final seen = <String>{};
    for (final v in others) {
      final c = v.category.trim();
      if (c.isNotEmpty && c != 'Boshqa' && seen.add(c)) cats.add(c);
    }
    // Tanlangan chip bo'yicha filtr (null = Hammasi).
    var related = _relatedChip == null
        ? others
        : others.where((v) => v.category.trim() == _relatedChip).toList();
    if (related.length > 20) related = related.sublist(0, 20);
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
            child: CustomScrollView(
              slivers: [
                // Ixcham info: sarlavha + meta + amallar + tavsif.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: const TextStyle(
                            color: AppColors.parvozText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _metaLine(video),
                          style: const TextStyle(
                            color: AppColors.parvozTextDim,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _FullscreenGlassButton(
                                onTap: _requestWebviewFullscreen,
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
                          const SizedBox(height: 14),
                          Text(
                            video.description,
                            style: const TextStyle(
                              color: AppColors.parvozTextDim,
                              height: 1.5,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // PINNED kategoriya chiplari — scroll'da video ostiga yopishadi.
                if (cats.isNotEmpty)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ChipsHeader(
                      categories: cats,
                      selected: _relatedChip,
                      onSelected: (c) => setState(() => _relatedChip = c),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final v = related[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: VideoFeedCard(
                          video: v,
                          isFavorite: favIds.contains(v.id),
                          // Bosilsa o'sha video ochiladi (joriy o'rniga —
                          // webview yopiladi, xotira tejaladi).
                          onTap: () => context.pushReplacement(
                            '/video-player',
                            extra: v,
                          ),
                        ),
                      );
                    }, childCount: related.length),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── To'liq ekran (landscape): webview butun ekranni qoplaydi ──
  // Native fullscreen — webview bergan ko'rinishni (video + YouTube controllari)
  // butun ekranda ko'rsatamiz. Webview QAYTA YUKLANMAYDI (o'sha player).
  // Chiqish: YouTube'ning o'z fullscreen-exit tugmasi yoki back (→ _hideFullscreen).
  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(child: _fullscreenWidget),
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
                    onPressed: _requestWebviewFullscreen,
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

// "To'liq ekran" — shisha fon (ko'k emas, joriy dark UI'ga mos).
class _FullscreenGlassButton extends StatelessWidget {
  const _FullscreenGlassButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fullscreen_rounded,
              size: 20,
              color: AppColors.parvozText,
            ),
            SizedBox(width: 8),
            Text(
              "To'liq ekran",
              style: TextStyle(
                color: AppColors.parvozText,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pinned kategoriya chiplari header — scroll'da video ostiga yopishadi.
class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final void Function(String?) onSelected;

  static const double _h = 54;

  @override
  double get minExtent => _h;

  @override
  double get maxExtent => _h;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final items = <String?>[null, ...categories]; // null = "Hammasi"
    return Container(
      height: _h,
      color: AppColors.parvozBg,
      alignment: Alignment.center,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = items[i];
          return _CategoryChip(
            label: c ?? 'Hammasi',
            active: c == selected,
            onTap: () => onSelected(c),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ChipsHeader old) =>
      old.selected != selected || old.categories.length != categories.length;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? AppColors.parvozText : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.parvozBg : AppColors.parvozText,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
