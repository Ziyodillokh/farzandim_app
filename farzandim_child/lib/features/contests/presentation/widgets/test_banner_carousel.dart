// ─────────────────────────────────────────────────────────────────────
// TestBannerCarousel — dashboard + Testlar tepasidagi test banner karuseli
// ─────────────────────────────────────────────────────────────────────
//
// Markazda bitta test, ikki chetida qo'shni testlar UCHLARI ko'rinadi
// (viewportFraction < 1). Har 5 sekundda avtomatik o'tadi (banner kabi).
// ≥2 test bo'lsa CHEKSIZ aylanadi (ikkala chet doim peek); 1 ta bo'lsa
// markazda turadi (aylanmaydi). Foydalanuvchi qo'lda surganda 5s taymer
// qayta boshlanadi. Banner rasmi `imageUrl` (admin coverKey) — bo'sh bo'lsa
// subject-rangli gradient + ikonka.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:flutter/material.dart';

class TestBannerCarousel extends StatefulWidget {
  const TestBannerCarousel({
    required this.tests,
    required this.onTap,
    this.height = 168,
    super.key,
  });

  final List<ContestModel> tests;
  final void Function(ContestModel test) onTap;
  final double height;

  @override
  State<TestBannerCarousel> createState() => _TestBannerCarouselState();
}

class _TestBannerCarouselState extends State<TestBannerCarousel> {
  late PageController _controller;
  Timer? _timer;
  int _page = 0;

  bool get _loop => widget.tests.length > 1;
  int get _count => widget.tests.length;
  int get _index => _count == 0 ? 0 : _page % _count;

  @override
  void initState() {
    super.initState();
    // Loop: katta (count'ga karrali) boshlang'ich — ikkala tomon aylanadi,
    // _index 0'dan boshlanadi.
    _page = _loop ? _count * 5000 : 0;
    _controller = PageController(
      viewportFraction: _loop ? 0.86 : 0.94,
      initialPage: _page,
    );
    _restartAutoPlay();
  }

  void _restartAutoPlay() {
    _timer?.cancel();
    if (!_loop) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant TestBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasLoop = oldWidget.tests.length > 1;
    if (oldWidget.tests.length != widget.tests.length) {
      // Loop holati o'zgarsagina kontrollerni qayta quramiz (viewportFraction
      // o'zgaradi). Aks holda _index = _page % _count o'zi moslashadi.
      if (wasLoop != _loop) {
        _controller.dispose();
        _page = _loop ? _count * 5000 : 0;
        _controller = PageController(
          viewportFraction: _loop ? 0.86 : 0.94,
          initialPage: _page,
        );
      }
      _restartAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tests = widget.tests;
    if (tests.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // Qo'l bilan surganda avto-taymerni qayta boshlaymiz.
              if (n is UserScrollNotification) _restartAutoPlay();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: _loop ? null : 1,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (_, i) {
                final t = tests[i % tests.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _TestBannerCard(test: t, onTap: () => widget.onTap(t)),
                );
              },
            ),
          ),
        ),
        if (_loop) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_count, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? tBlue : tGlassBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _TestBannerCard extends StatelessWidget {
  const _TestBannerCard({required this.test, required this.onTap});

  final ContestModel test;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = test.imageUrl.isNotEmpty;
    final accent = test.placeholderColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tGlassBorder),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fon: banner rasm (bo'lsa) yoki subject-rangli gradient.
            if (hasImage)
              CachedNetworkImage(
                imageUrl: test.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _GradientBg(accent: accent),
                errorWidget: (_, __, ___) => _GradientBg(accent: accent),
              )
            else
              _GradientBg(accent: accent),
            // Matn o'qilishi uchun chapdan qorong'i gradient.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: hasImage ? 0.80 : 0.34),
                    Colors.black.withValues(alpha: hasImage ? 0.12 : 0.0),
                  ],
                ),
              ),
            ),
            // Rasmsiz — o'ng-pastda subject ikonka (dekorativ, xira).
            if (!hasImage)
              Positioned(
                right: -8,
                bottom: -8,
                child: Icon(
                  test.placeholderIcon,
                  size: 108,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    test.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tUnb(20, w: FontWeight.w700, ls: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'contests.bannerMeta'.tr(
                      namedArgs: {
                        'soha': test.soha,
                        'count': '${test.savollarSoni}',
                      },
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tPop(12.5, c: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const Spacer(),
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      'common.details'.tr(),
                      style: tPop(12.5, w: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBg extends StatelessWidget {
  const _GradientBg({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.55),
              const Color(0xFF0C1826),
            ),
            const Color(0xFF0C1826),
          ],
        ),
      ),
    );
  }
}
