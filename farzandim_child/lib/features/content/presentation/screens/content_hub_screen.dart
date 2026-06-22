// ─────────────────────────────────────────────────────────────────────
// ContentHubScreen — "Kutubxona" (Parvoz UI Redesign — NIGHT, Premium Edition)
// ─────────────────────────────────────────────────────────────────────
//
// Google Stitch "Parvoz UI Redesign / Kutubxona (Night) - Premium Edition"
// dizayniga 1:1 moslangan. Tuzilma (yuqoridan pastga):
//   • Parvoz header (logo + bell + settings, backdrop border)
//   • Videolar / Audio kitoblar segment (rounded-xl, yashil faol)
//   • Kategoriya chiplari (rounded-xl, YASHIL faol)
//   • Hero karta — to'liq rasm + gradient overlay + ustiga matn +
//     "YANGI DARS" (to'q-sariq badge) + yashil-glow "Boshlash" tugma
//   • "Siz uchun tavsiyalar" (2-ustun grid, rounded-2xl)
//   • "Eng ko'p ko'rilganlar" (gorizontal, rounded-2xl, ko'rishlar soni)
//
// Faqat NIGHT — `AppTheme.darkTheme` bilan majburiy. Ranglar
// `AppColors.parvoz*` (Premium: surface #162B45, green #2ECC71, badge #F39C12).
// Real data: effectiveVideosProvider + audiobooks/books (mock yo'q).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/providers/books_providers.dart';
import 'package:farzandim_child/features/books/presentation/widgets/book_section.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tanlangan kategoriya chip (null = "Barchasi").
final _parvozCategoryProvider = StateProvider<String?>((ref) => null);

class ContentHubScreen extends ConsumerStatefulWidget {
  const ContentHubScreen({super.key});

  @override
  ConsumerState<ContentHubScreen> createState() => _ContentHubScreenState();
}

class _ContentHubScreenState extends ConsumerState<ContentHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kun/tunga moslashadi (ilovaning themeMode'ini meros oladi).
    return Scaffold(
      backgroundColor: context.adaptive.pvBg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _ParvozHeader(),
            const SizedBox(height: 16),
            _ParvozSegment(controller: _tab),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: const [
                  _VideosTab(),
                  _AudiobooksTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

// ─── Header: "Parvoz" + bell + settings ───────────────────────────────
class _ParvozHeader extends StatelessWidget {
  const _ParvozHeader();

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pv.pvBorder)),
      ),
      child: Row(
        children: [
          Text(
            'Parvoz',
            style: TextStyle(
              color: pv.pvGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _ParvozIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
          _ParvozIconButton(
            icon: Icons.settings_outlined,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _ParvozIconButton extends StatelessWidget {
  const _ParvozIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: pv.pvSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: pv.pvText, size: 22),
      ),
    );
  }
}

// ─── Segment: Videolar / Audio kitoblar (rounded-xl, yashil faol) ──────
class _ParvozSegment extends StatelessWidget {
  const _ParvozSegment({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: pv.pvSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final idx = controller.index;
            return Row(
              children: [
                _seg('Videolar', 0, idx, pv),
                _seg('Audio kitoblar', 1, idx, pv),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _seg(String label, int i, int active, AdaptivePalette pv) {
    final selected = i == active;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.animateTo(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? pv.pvGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? pv.pvOnGreen : pv.pvTextDim,
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Videolar tab ─────────────────────────────────────────────────────
class _VideosTab extends ConsumerWidget {
  const _VideosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(effectiveVideosProvider);
    final selectedCat = ref.watch(_parvozCategoryProvider);

    if (all.isEmpty) {
      return const _ParvozEmpty(
        icon: Icons.video_library_outlined,
        text: "Hozircha video yo'q",
      );
    }

    final categories = <String>[];
    for (final v in all) {
      if (v.category.isNotEmpty && !categories.contains(v.category)) {
        categories.add(v.category);
      }
    }

    final filtered = selectedCat == null
        ? all
        : all.where((v) => v.category == selectedCat).toList();

    final hero = filtered.isNotEmpty ? filtered.first : null;
    final recommended =
        filtered.length > 1 ? filtered.skip(1).take(4).toList() : <VideoModel>[];
    final mostViewed = [...filtered]
      ..sort((a, b) => b.views.compareTo(a.views));
    final topViewed = mostViewed.take(6).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ParvozChips(categories: categories),
          const SizedBox(height: 28),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Center(
                child: Text(
                  "Bu kategoriyada video yo'q",
                  style: TextStyle(
                      color: context.adaptive.pvTextDim, fontSize: 14),
                ),
              ),
            ),
          if (hero != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ParvozHeroCard(video: hero),
            ),
            const SizedBox(height: 32),
          ],
          if (recommended.isNotEmpty) ...[
            _ParvozSectionHeader(
              title: 'Siz uchun tavsiyalar',
              onSeeAll: () => context.push('/videos'),
            ),
            const SizedBox(height: 16),
            _ParvozVideoHList(videos: recommended),
            const SizedBox(height: 32),
          ],
          if (topViewed.isNotEmpty) ...[
            const _ParvozSectionTitle("Eng ko'p ko'rilganlar"),
            const SizedBox(height: 16),
            _ParvozWideList(videos: topViewed),
          ],
        ],
      ),
    );
  }
}

// ─── Kategoriya chiplari (rounded-xl, YASHIL faol) ────────────────────
class _ParvozChips extends ConsumerWidget {
  const _ParvozChips({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pv = context.adaptive;
    final selected = ref.watch(_parvozCategoryProvider);
    final items = <String?>[null, ...categories]; // null = Barchasi

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final cat = items[i];
          final isSel = cat == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(_parvozCategoryProvider.notifier).state = cat,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? pv.pvGreen : pv.pvSurface,
                borderRadius: BorderRadius.circular(12),
                border: isSel
                    ? null
                    : Border.all(color: pv.pvBorder, width: 1),
              ),
              child: Text(
                cat ?? 'Barchasi',
                style: TextStyle(
                  color: isSel ? pv.pvOnGreen : pv.pvTextDim,
                  fontSize: 14,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section sarlavhasi ───────────────────────────────────────────────
class _ParvozSectionTitle extends StatelessWidget {
  const _ParvozSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: TextStyle(
          color: context.adaptive.pvText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ─── Hero karta — to'liq rasm + overlay + glow tugma ──────────────────
class _ParvozHeroCard extends StatelessWidget {
  const _ParvozHeroCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        decoration: parvozGlass(radius: 16, dark: pv.isDark),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetImage(url: video.thumbnailUrl, fallback: video.thumbnailColor),
              // Rasm ustidagi skrim — matn o'qilishi uchun har doim to'q
              // (rasm — media, tegilmaydi).
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF0B1C30),
                      Color(0xB30B1C30),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              // YANGI DARS badge (to'q-sariq, yuqori-chap)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pv.pvBadge,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'YANGI DARS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              // Matn + tugma (pastda overlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        video.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: pv.pvGreen,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: pv.pvGreen.withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: pv.pvOnGreen,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Boshlash',
                                style: TextStyle(
                                  color: pv.pvOnGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section sarlavhasi + "Barchasi" tugmasi ──────────────────────────
class _ParvozSectionHeader extends StatelessWidget {
  const _ParvozSectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: pv.pvText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                decoration: BoxDecoration(
                  color: pv.pvGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: pv.pvGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Barchasi',
                      style: TextStyle(
                        color: pv.pvGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: pv.pvGreen,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── "Siz uchun tavsiyalar" — bir qatorli gorizontal ro'yxat ──────────
class _ParvozVideoHList extends StatelessWidget {
  const _ParvozVideoHList({required this.videos});

  final List<VideoModel> videos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => SizedBox(
          width: 160,
          child: _ParvozGridCard(video: videos[i]),
        ),
      ),
    );
  }
}

class _ParvozGridCard extends StatelessWidget {
  const _ParvozGridCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        decoration: parvozGlass(radius: 16, dark: pv.isDark),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 128,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetImage(
                    url: video.thumbnailUrl,
                    fallback: video.thumbnailColor,
                  ),
                  if (video.hasDuration)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _DurationBadge(video.duration),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pv.pvText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      video.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pv.pvTextDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "Eng ko'p ko'rilganlar" — gorizontal keng kartalar ───────────────
class _ParvozWideList extends StatelessWidget {
  const _ParvozWideList({required this.videos});

  final List<VideoModel> videos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => _ParvozWideCard(video: videos[i]),
      ),
    );
  }
}

class _ParvozWideCard extends StatelessWidget {
  const _ParvozWideCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: parvozGlass(radius: 16, dark: pv.isDark),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: _NetImage(
                  url: video.thumbnailUrl,
                  fallback: video.thumbnailColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pv.pvText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pv.pvTextDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: pv.pvGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatViews(video.views)} ko\'rilgan',
                        style: TextStyle(
                          color: pv.pvGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
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

// ─── Yordamchi widgetlar ──────────────────────────────────────────────
class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, required this.fallback});

  final String url;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return ColoredBox(color: fallback);
    // Disk-cache (cached_network_image): kontent rasmlari bir marta
    // yuklangach keyingi safar (offline ham) darhol chiqadi.
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => ColoredBox(color: fallback),
      errorWidget: (_, __, ___) => ColoredBox(color: fallback),
    );
  }
}

class _ParvozEmpty extends StatelessWidget {
  const _ParvozEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final pv = context.adaptive;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: pv.pvTextDim),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: pv.pvTextDim,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatViews(int v) {
  if (v >= 1000) {
    final k = v / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return '$v';
}

// ─── Audio kitoblar tab (Premium Edition — Stitch) ────────────────────
// Tartib: kategoriya chiplari → Hero audiokitob (cover + Eshitish + bookmark)
// → "Siz uchun tavsiyalar" (gorizontal) → "Eng ko'p eshitilganlar" (raqamli
// vertikal ro'yxat + play) → Kitoblar (PDF, funksiya saqlanishi uchun).
class _AudiobooksTab extends ConsumerWidget {
  const _AudiobooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(effectiveAudiobooksProvider);
    final forYou = ref.watch(forYouAudiobooksProvider);
    final mostListened = ref.watch(mostListenedProvider);
    final asyncBooks = ref.watch(backendBooksProvider);
    final books = asyncBooks.valueOrNull ?? const <BookModel>[];

    if (all.isEmpty && books.isEmpty) {
      return const _ParvozEmpty(
        icon: Icons.headphones_rounded,
        text: 'Audiokitoblar topilmadi',
      );
    }

    final categories = <String>[];
    for (final b in all) {
      if (b.category.isNotEmpty && !categories.contains(b.category)) {
        categories.add(b.category);
      }
    }

    final featured = forYou.isNotEmpty ? forYou.first : null;
    final recommended =
        forYou.length > 1 ? forYou.skip(1).toList() : <AudiobookModel>[];

    final schoolBooks = books.where((b) => b.category == 'school').toList();
    final adabiyotBooks = books.where((b) => b.category == 'adabiyot').toList();
    final otherBooks = books
        .where((b) => b.category != 'school' && b.category != 'adabiyot')
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categories.isNotEmpty) ...[
            _ParvozAudioChips(categories: categories),
            const SizedBox(height: 28),
          ],
          if (featured != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ParvozAudioHero(book: featured),
            ),
            const SizedBox(height: 32),
          ],
          if (recommended.isNotEmpty) ...[
            _ParvozSectionHeader(
              title: 'Siz uchun tavsiyalar',
              onSeeAll: () => context.push('/audiobooks'),
            ),
            const SizedBox(height: 16),
            _ParvozAudioHList(books: recommended),
            const SizedBox(height: 32),
          ],
          if (mostListened.isNotEmpty) ...[
            const _ParvozSectionTitle("Eng ko'p eshitilganlar"),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < mostListened.length; i++) ...[
                    _ParvozAudioRow(book: mostListened[i], rank: i + 1),
                    if (i != mostListened.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
          if (books.isNotEmpty) ...[
            const SizedBox(height: 32),
            BookSection(
              title: 'Kitoblar',
              books: books,
              onTap: (b) => context.push('/books/pdf', extra: b),
            ),
            if (schoolBooks.isNotEmpty) ...[
              const SizedBox(height: 20),
              BookSection(
                title: 'Maktab darsliklari',
                books: schoolBooks,
                onTap: (b) => context.push('/books/pdf', extra: b),
              ),
            ],
            if (adabiyotBooks.isNotEmpty) ...[
              const SizedBox(height: 20),
              BookSection(
                title: 'Adabiyot',
                books: adabiyotBooks,
                onTap: (b) => context.push('/books/pdf', extra: b),
              ),
            ],
            if (otherBooks.isNotEmpty) ...[
              const SizedBox(height: 20),
              BookSection(
                title: 'Boshqalar',
                books: otherBooks,
                onTap: (b) => context.push('/books/pdf', extra: b),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Audio: kategoriya chiplari (audiobookCategoryFilter) ─────────────
class _ParvozAudioChips extends ConsumerWidget {
  const _ParvozAudioChips({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pv = context.adaptive;
    final selected = ref.watch(audiobookCategoryFilterProvider);
    final items = <String?>[null, ...categories];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final cat = items[i];
          final isSel = cat == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(audiobookCategoryFilterProvider.notifier).state = cat,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? pv.pvGreen : pv.pvSurface,
                borderRadius: BorderRadius.circular(12),
                border: isSel
                    ? null
                    : Border.all(color: pv.pvBorder, width: 1),
              ),
              child: Text(
                cat ?? 'Barchasi',
                style: TextStyle(
                  color: isSel ? pv.pvOnGreen : pv.pvTextDim,
                  fontSize: 14,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Audio: Hero (featured audiokitob) ────────────────────────────────
class _ParvozAudioHero extends ConsumerWidget {
  const _ParvozAudioHero({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pv = context.adaptive;
    return Container(
      decoration: parvozGlass(radius: 20, dark: pv.isDark),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _NetImage(url: book.coverUrl, fallback: book.coverColor),
                    // Cover ustidagi skrim — pill o'qilishi uchun to'q (media).
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xD90B1C30),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.6],
                        ),
                      ),
                    ),
                    if (book.duration.isNotEmpty)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: _AudioDurationPill(book.duration),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: pv.pvText,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.category.isEmpty
                  ? book.author
                  : '${book.author} • ${book.category}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: pv.pvTextDim,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(audioPlayerProvider.notifier).play(book),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pv.pvGreen,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: pv.pvGreen.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: pv.pvOnGreen,
                              size: 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Eshitish',
                              style: TextStyle(
                                color: pv.pvOnGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: pv.pvBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pv.pvBorder),
                  ),
                  child: Icon(
                    Icons.bookmark_border_rounded,
                    color: pv.pvText,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioDurationPill extends StatelessWidget {
  const _AudioDurationPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.parvozBorderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.headphones_rounded,
              color: AppColors.parvozGreen, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Audio: gorizontal tavsiya kartalari ──────────────────────────────
class _ParvozAudioHList extends StatelessWidget {
  const _ParvozAudioHList({required this.books});

  final List<AudiobookModel> books;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => _ParvozAudioHCard(book: books[i]),
      ),
    );
  }
}

class _ParvozAudioHCard extends ConsumerWidget {
  const _ParvozAudioHCard({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: () => ref.read(audioPlayerProvider.notifier).play(book),
      child: Container(
        width: 150,
        decoration: parvozGlass(radius: 16, dark: pv.isDark),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetImage(url: book.coverUrl, fallback: book.coverColor),
                  if (book.duration.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _DurationBadge(book.duration),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pv.pvText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pv.pvTextDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Audio: "Eng ko'p eshitilganlar" qatori ───────────────────────────
class _ParvozAudioRow extends ConsumerWidget {
  const _ParvozAudioRow({required this.book, required this.rank});

  final AudiobookModel book;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pv = context.adaptive;
    return GestureDetector(
      onTap: () => ref.read(audioPlayerProvider.notifier).play(book),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: parvozGlass(radius: 16, dark: pv.isDark),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pv.pvText.withValues(alpha: 0.25),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _NetImage(url: book.coverUrl, fallback: book.coverColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pv.pvText,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.headphones_rounded,
                          size: 14, color: pv.pvTextDim),
                      const SizedBox(width: 5),
                      Text(
                        '${_formatViews(book.listenCount)} marta eshitildi',
                        style: TextStyle(
                          color: pv.pvTextDim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: pv.pvBorderStrong),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: pv.pvGreen,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
