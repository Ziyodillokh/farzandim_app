// ─────────────────────────────────────────────────────────────────────
// ContentHubScreen — "Kutubxona" (Parvoz UI Redesign — NIGHT)
// ─────────────────────────────────────────────────────────────────────
//
// Google Stitch "Parvoz UI Redesign / Kutubxona (Night)" dizayniga
// moslangan. Tuzilma (yuqoridan pastga):
//   • Parvoz header (logo + bell + settings)
//   • Videolar / Audiokitoblar segment (pill)
//   • Kategoriya chiplari (Barchasi + ...)
//   • Hero karta (YANGI DARS badge + Boshlash)
//   • "Siz uchun tavsiyalar" (2-ustun grid)
//   • "Eng ko'p ko'rilganlar" (gorizontal, ko'rishlar soni)
//
// Faqat NIGHT — `AppTheme.darkTheme` bilan majburiy dark, ranglar
// `AppColors.parvoz*` (Stitch night palitra). Light mode keyin alohida.
//
// Real data: effectiveVideosProvider + audiobooks/books providerlari
// (mock yo'q). Eski /videos, /audiobooks, /books route'lari deep-link
// uchun saqlanadi; bottom nav /content ga olib boradi.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_theme.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobook_section.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobooks_search_bar.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/providers/books_providers.dart';
import 'package:farzandim_child/features/books/presentation/widgets/book_section.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
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
    // NIGHT majburiy: butun subtree dark theme (qayta ishlatilgan
    // audiokitob/kitob widgetlari ham to'g'ri dark render bo'lsin).
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AppColors.parvozBg,
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _ParvozHeader(),
              const SizedBox(height: 12),
              _ParvozSegment(controller: _tab),
              const SizedBox(height: 16),
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
      ),
    );
  }
}

// ─── Header: "Parvoz" + bell + settings ───────────────────────────────
class _ParvozHeader extends StatelessWidget {
  const _ParvozHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          const Text(
            'Parvoz',
            style: TextStyle(
              color: AppColors.parvozGreen,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _ParvozIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 10),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.parvozSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.parvozTextDim, size: 22),
      ),
    );
  }
}

// ─── Segment: Videolar / Audiokitoblar (pill) ─────────────────────────
class _ParvozSegment extends StatelessWidget {
  const _ParvozSegment({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.parvozSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final idx = controller.index;
            return Row(
              children: [
                _seg('Videolar', 0, idx),
                _seg('Audiokitoblar', 1, idx),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _seg(String label, int i, int active) {
    final selected = i == active;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.animateTo(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.parvozGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.parvozOnGreen : AppColors.parvozTextDim,
              fontSize: 14,
              fontWeight: FontWeight.w700,
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

    // Kategoriyalar — videolardagi distinct `category`.
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
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Center(
                child: Text(
                  "Bu kategoriyada video yo'q",
                  style: TextStyle(color: AppColors.parvozTextDim, fontSize: 14),
                ),
              ),
            ),
          if (hero != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ParvozHeroCard(video: hero),
            ),
            const SizedBox(height: 28),
          ],
          if (recommended.isNotEmpty) ...[
            const _ParvozSectionTitle('Siz uchun tavsiyalar'),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ParvozVideoGrid(videos: recommended),
            ),
            const SizedBox(height: 28),
          ],
          if (topViewed.isNotEmpty) ...[
            const _ParvozSectionTitle("Eng ko'p ko'rilganlar"),
            const SizedBox(height: 14),
            _ParvozWideList(videos: topViewed),
          ],
        ],
      ),
    );
  }
}

// ─── Kategoriya chiplari ──────────────────────────────────────────────
class _ParvozChips extends ConsumerWidget {
  const _ParvozChips({required this.categories});

  final List<String> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_parvozCategoryProvider);
    final items = <String?>[null, ...categories]; // null = Barchasi

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = items[i];
          final isSel = cat == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(_parvozCategoryProvider.notifier).state = cat,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? AppColors.parvozBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: isSel
                    ? null
                    : Border.all(color: AppColors.parvozBorder, width: 1),
              ),
              child: Text(
                cat ?? 'Barchasi',
                style: TextStyle(
                  color: isSel ? Colors.white : AppColors.parvozTextDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
        style: const TextStyle(
          color: AppColors.parvozText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Hero karta ───────────────────────────────────────────────────────
class _ParvozHeroCard extends StatelessWidget {
  const _ParvozHeroCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.parvozSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.parvozBorder.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetImage(
                    url: video.thumbnailUrl,
                    fallback: video.thumbnailColor,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.parvozSurface.withValues(alpha: 0.95),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.parvozGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.parvozGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'YANGI DARS',
                      style: TextStyle(
                        color: AppColors.parvozGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.parvozText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.parvozTextDim,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.parvozGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.parvozOnGreen,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Boshlash',
                            style: TextStyle(
                              color: AppColors.parvozOnGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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

// ─── "Siz uchun tavsiyalar" — 2-ustun grid ────────────────────────────
class _ParvozVideoGrid extends StatelessWidget {
  const _ParvozVideoGrid({required this.videos});

  final List<VideoModel> videos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 182,
      ),
      itemCount: videos.length,
      itemBuilder: (_, i) => _ParvozGridCard(video: videos[i]),
    );
  }
}

class _ParvozGridCard extends StatelessWidget {
  const _ParvozGridCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.parvozSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.parvozBorder.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 104,
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
                      bottom: 6,
                      right: 6,
                      child: _DurationBadge(video.duration),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.parvozText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      video.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.parvozTextDim,
                        fontSize: 11,
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
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
    return GestureDetector(
      onTap: () => context.push('/video-player', extra: video),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: AppColors.parvozSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.parvozBorder.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: _NetImage(
                url: video.thumbnailUrl,
                fallback: video.thumbnailColor,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.parvozText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.parvozTextDim,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: AppColors.parvozGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatViews(video.views)} ko\'rilgan',
                          style: const TextStyle(
                            color: AppColors.parvozGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

// ─── Yordamchi widgetlar ──────────────────────────────────────────────
class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
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
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : ColoredBox(color: fallback),
      errorBuilder: (_, __, ___) => ColoredBox(color: fallback),
    );
  }
}

class _ParvozEmpty extends StatelessWidget {
  const _ParvozEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.parvozTextDim),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.parvozTextDim,
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

// ─── Audiokitoblar tab (mavjud tuzilma — dark theme ostida) ───────────
class _AudiobooksTab extends ConsumerWidget {
  const _AudiobooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forYou = ref.watch(forYouAudiobooksProvider);
    final mostListened = ref.watch(mostListenedProvider);
    final newest = ref.watch(newestAudiobooksProvider);
    final allFiltered = ref.watch(filteredAudiobooksProvider);
    final asyncBooks = ref.watch(backendBooksProvider);

    final hasAudiobooks = allFiltered.isNotEmpty;
    final books = asyncBooks.valueOrNull ?? const <BookModel>[];

    if (!hasAudiobooks && books.isEmpty) {
      return const Column(
        children: [
          AudiobooksSearchBar(),
          SizedBox(height: 8),
          Expanded(
            child: _ParvozEmpty(
              icon: Icons.headphones_rounded,
              text: 'Audiokitoblar topilmadi',
            ),
          ),
        ],
      );
    }

    final schoolBooks = books.where((b) => b.category == 'school').toList();
    final adabiyotBooks = books.where((b) => b.category == 'adabiyot').toList();
    final otherBooks = books
        .where((b) => b.category != 'school' && b.category != 'adabiyot')
        .toList();

    return Column(
      children: [
        const AudiobooksSearchBar(),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (forYou.isNotEmpty) ...[
                  AudiobookSection(title: 'Siz uchun', books: forYou),
                  const SizedBox(height: 24),
                ],
                if (mostListened.isNotEmpty) ...[
                  AudiobookSection(
                      title: "Eng ko'p o'qilgan", books: mostListened),
                  const SizedBox(height: 24),
                ],
                if (newest.isNotEmpty) ...[
                  AudiobookSection(title: "Yangi qo'shilgan", books: newest),
                  const SizedBox(height: 24),
                ],
                if (books.isNotEmpty) ...[
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
          ),
        ),
      ],
    );
  }
}
