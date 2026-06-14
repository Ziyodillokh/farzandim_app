// ─────────────────────────────────────────────────────────────────────
// ContentHubScreen — Videolar + Audiokitoblar (PDF kitoblar ichida)
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanuvchi talabiga ko'ra 2 ta TopTab — Videolar va Audiokitoblar.
// PDF kitoblar Audiokitoblar tab ichida alohida section sifatida turadi
// (Figma 2-rasmga muvofiq: Siz uchun vertikal cover+title list).
// Konkurslar alohida bo'lim sifatida saqlandi (boshqa tab).
//
// Eski /videos, /audiobooks, /books route'lari saqlanadi (deep-link
// uchun), lekin bottom nav endi /content ga olib boradi.

import 'package:easy_localization/easy_localization.dart';
// `adaptive` extension (context.adaptive) shu import'dan keladi — kerak.
import 'package:farzandim_child/core/theme/app_colors.dart';
// VAQTINCHA o'chirilgan — "Maqolalar" tabi (pastdagi MAQOLALAR markerlariga
// qarang). Qaytarishda quyidagi import'larni ham oching:
// import 'package:farzandim_child/features/articles/data/models/article_model.dart';
// import 'package:farzandim_child/features/articles/presentation/providers/articles_providers.dart';
// import 'package:farzandim_child/features/articles/presentation/widgets/article_card.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobook_section.dart';
import 'package:farzandim_child/features/audiobooks/presentation/widgets/audiobooks_search_bar.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/providers/books_providers.dart';
import 'package:farzandim_child/features/books/presentation/widgets/book_section.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/videos/data/models/filter_state.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/hero_video_card.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_section.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_tabs.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/videos_search_bar.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContentHubScreen extends ConsumerWidget {
  const ContentHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // VAQTINCHA: "Maqolalar" tabi o'chirilgan → length 3 emas, 2.
    // Qaytarishda 3 ga o'zgartiring.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: GradientBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DashboardTopHeader(
                    onAvatarTap: () => context.push('/account-edit'),
                  ),
                ),
                const SizedBox(height: 8),
                const _TopTabs(),
                Expanded(
                  child: TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: const [
                      _VideosTab(),
                      _AudiobooksTab(),
                      // VAQTINCHA o'chirilgan — Maqolalar tabi:
                      // _ArticlesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const ChildBottomNavigation(),
      ),
    );
  }
}

// ─── Top tabs (2 ta) — premium underline style (Figma asosida) ────────
// Skreenshot dizayniga muvofiq: filled pill o'rniga pastdan rangli
// chiziq, faol tab matni oq+bold, nofaol tab matni kulrang.
class _TopTabs extends StatelessWidget {
  const _TopTabs();

  // Brand accent — orange chiziq (skreenshotga mos). Tema accent emas,
  // chunki content hub ichida LOGO ham orange (vizual yagonalik).
  static const _accent = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        // Pastdan 3px qalin underline — premium app'lardagi standart.
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: _accent),
          insets: EdgeInsets.symmetric(horizontal: 32),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: context.adaptive.textPrimary,
        unselectedLabelColor: context.adaptive.textTertiary,
        labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        tabAlignment: TabAlignment.start,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Videolar'),
          Tab(text: 'Audiokitoblar'),
          // VAQTINCHA o'chirilgan — Maqolalar tabi:
          // Tab(text: 'Maqolalar'),
        ],
      ),
    );
  }
}

// ─── Videos tab (videos_feed_screen body) ─────────────────────────────
class _VideosTab extends ConsumerWidget {
  const _VideosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroVideo = ref.watch(heroVideoProvider);
    final topVideos = ref.watch(topVideosProvider);
    final recommended = ref.watch(recommendedVideosProvider);
    final filtered = ref.watch(filteredVideosProvider);

    return Column(
      children: [
        const VideosSearchBar(),
        const VideoTabs(),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? EmptyStateMascot(
                  faroVariant: FaroVariant.faceSad,
                  title: 'videos.feed.emptyTitle'.tr(),
                  subtitle: 'videos.feed.emptyHint'.tr(),
                  actionLabel: 'videos.feed.emptyClearButton'.tr(),
                  onAction: () {
                    ref.read(videoSearchQueryProvider.notifier).state = '';
                    ref.read(videoFilterProvider.notifier).state =
                        const VideoFilterState();
                  },
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (heroVideo != null) ...[
                        HeroVideoCard(video: heroVideo),
                        const SizedBox(height: 24),
                      ],
                      if (topVideos.isNotEmpty) ...[
                        VideoSection(
                          title: 'videos.feed.topVideos'.tr(),
                          videos: topVideos,
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (recommended.isNotEmpty)
                        VideoSection(
                          title: 'videos.feed.recommended'.tr(),
                          videos: recommended,
                          onViewAll: () {},
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Audiobooks tab (audiokitoblar + PDF kitoblar) ────────────────────
// Figma 2-rasmga muvofiq: yuqorida audiokitob sectionlari (horizontal),
// pastida PDF kitoblar sectionlari (kategoriyalarga ajratilgan).
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
      return Column(
        children: [
          const AudiobooksSearchBar(),
          const SizedBox(height: 8),
          Expanded(child: _emptyAudiobooks()),
        ],
      );
    }

    // PDF kitoblarni kategoriya bo'yicha guruhlash (school / adabiyot /
    // boshqalar) — barchasi Audiokitoblar tab ichida ko'rsatiladi.
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
                  AudiobookSection(
                      title: "Yangi qo'shilgan", books: newest),
                  const SizedBox(height: 24),
                ],
                // ─── PDF kitoblar (Audiokitoblar tab ichida) ─────────
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

  Widget _emptyAudiobooks() {
    return Builder(builder: (ctx) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones,
                size: 64, color: ctx.adaptive.textTertiary),
            const SizedBox(height: 16),
            Text(
              "Audiokitoblar topilmadi",
              style: TextStyle(
                  fontSize: 16, color: ctx.adaptive.textSecondary),
            ),
          ],
        ),
      );
    });
  }
}

// ─── Maqolalar tab (#48) — VAQTINCHA O'CHIRILGAN ──────────────────────
// Qaytarish uchun: (1) yuqoridagi 3 ta article import'ini oching,
// (2) DefaultTabController length'ni 2 dan 3 ga, (3) TabBarView'ga
// `_ArticlesTab()` va tabs'ga `Tab(text: 'Maqolalar')` qatorlarini qayting,
// (4) quyidagi block-komentni oching.
/*
class _ArticlesTab extends ConsumerWidget {
  const _ArticlesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(backendArticlesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _ArticlesMessage(
        text: 'Maqolalarni yuklab bo\'lmadi.',
        onRetry: () => ref.invalidate(backendArticlesProvider),
      ),
      data: (articles) {
        if (articles.isEmpty) {
          return const _ArticlesMessage(
            text: 'Hozircha maqola yo\'q. Tez orada qo\'shiladi!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(backendArticlesProvider);
            await ref.read(backendArticlesProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final ArticleModel a = articles[i];
              return ArticleCard(
                article: a,
                onTap: () => context.push('/articles/view', extra: a),
              );
            },
          ),
        );
      },
    );
  }
}

class _ArticlesMessage extends StatelessWidget {
  const _ArticlesMessage({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
          ],
        ],
      ),
    );
  }
}
*/
