// ─────────────────────────────────────────────────────────────────────
// AudiobooksFeedScreen — "Kitoblar" (Parvoz redesign, screenshot 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Layout (yuqoridan pastga):
//   1) "Kitoblar" bosh sarlavha (katta, oq)
//   2) "Yangi kitoblar" hero-card — 3 ta kitob muqovasi gorizontal,
//      har biri ostida "250 DON" pill.
//   3) Kategoriya chip'lari (Barchasi / Hikoya / Sarguzasht / ...).
//      Faol chip ko'k fon + oq X ikonasi (bekor qilish).
//   4) 2 ustunli grid — kitob muqovasi + nom + (⏱ duration · 250 DON).
//   5) MiniAudioPlayer + ChildBottomNavigation (mavjud shell).
//
// Har bir kitob kartasiga tap → global audio o'yinatgichda ijro
// (`audioPlayerProvider.notifier.play`).
//
// Bo'sh holat (backend content bermasa) — chiroyli placeholder ko'rsatiladi.
// Muqovadagi "250 DON" — hozircha placeholder narx: backend `price`
// yubormaguncha shu qiymat chiqadi (kelajakda `AudiobookModel.price`
// qo'shilganda avtomatik olinadi).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/shared/widgets/parvoz_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _blue = Color(0xFF216BFF);
const _pageBg = Color(0xFF0B0F14);
const _cardBg = Color(0xFF141A22);
const _chipInactiveBorder = Color(0xFF2A323D);
const _textMuted = Color(0xFF9CA3AF);
const _iconMuted = Color(0xFFB6BCC5);

class AudiobooksFeedScreen extends ConsumerWidget {
  const AudiobooksFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(effectiveAudiobooksProvider);
    // Qismlar ("Kitob nomi N") BITTA kitob kartasiga yig'iladi.
    final feed = groupIntoSeries(ref.watch(audiobookFeedProvider));
    final newest = groupIntoSeries(ref.watch(newestAudiobooksProvider));
    final selectedCategory = ref.watch(audiobookCategoryFilterProvider);
    final searching = ref.watch(audiobookFeedSearchProvider).trim().isNotEmpty;

    // Chip ro'yxati — birinchi "Barchasi", keyin backend'dan kelgan
    // haqiqiy kategoriyalar (takrorsiz, kelish tartibida).
    final categories = <String>{
      for (final b in all) b.category,
    }.toList(growable: false);

    return Scaffold(
      backgroundColor: _pageBg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(backendAudiobooksProvider);
            await ref.read(backendAudiobooksProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverToBoxAdapter(child: _KitoblarTitle()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: ParvozSearchField(
                    queryProvider: audiobookFeedSearchProvider,
                    hintText: 'Kitob yoki muallif qidirish...',
                    accent: _blue,
                  ),
                ),
              ),
              // Qidiruv paytida hero + kategoriya chiplari yashiriladi
              // (qidiruv barcha kitoblardan qidiradi).
              if (!searching && newest.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverToBoxAdapter(
                    child: _YangiKitoblarHero(books: newest),
                  ),
                ),
              if (!searching)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _CategoryChips(
                      categories: categories,
                      selected: selectedCategory,
                      onSelected: (cat) =>
                          ref
                                  .read(
                                    audiobookCategoryFilterProvider.notifier,
                                  )
                                  .state =
                              cat,
                    ),
                  ),
                ),
              if (feed.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: searching
                      ? const _NoSearchResults()
                      : const _EmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 200),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 22,
                      crossAxisSpacing: 14,
                      // Karta: cover (3:4) + title (2 satr) + meta = W*1.6+68
                      // childAspectRatio = W / H → 1 / 1.62 ≈ 0.62
                      childAspectRatio: 0.62,
                    ),
                    itemCount: feed.length,
                    itemBuilder: (_, i) => _GridBookCard(series: feed[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Sarlavha — "Kitoblar" (Poppins-Bold ko'rinishi)
// ═════════════════════════════════════════════════════════════════════
class _KitoblarTitle extends StatelessWidget {
  const _KitoblarTitle();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Kitoblar',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Yangi kitoblar HERO — sarlavha + arrow + 3 muqova gorizontal
// ═════════════════════════════════════════════════════════════════════
class _YangiKitoblarHero extends StatelessWidget {
  const _YangiKitoblarHero({required this.books});

  final List<AudiobookSeries> books;

  @override
  Widget build(BuildContext context) {
    final display = books.take(3).toList(growable: false);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Yangi kitoblar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                SolarIconsOutline.altArrowRight,
                color: _iconMuted,
                size: 22,
              ),
              SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < display.length; i++) ...[
                Expanded(child: _HeroCoverCard(series: display[i])),
                if (i != display.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCoverCard extends StatelessWidget {
  const _HeroCoverCard({required this.series});

  final AudiobookSeries series;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/audiobook-detail', extra: series),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _CoverImage(book: series.cover),
            ),
          ),
          const SizedBox(height: 8),
          _DonPill(price: series.cover.xpReward),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Category chip qatori — gorizontal skroll
// ═════════════════════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _Chip(
            label: 'Barchasi',
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final cat in categories) ...[
            const SizedBox(width: 8),
            _Chip(
              label: cat,
              active: selected == cat,
              onTap: () => onSelected(selected == cat ? null : cat),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: active ? 8 : 16,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: active ? _blue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _blue : _chipInactiveBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _textMuted,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Grid karta — muqova + title + (⏱ duration · 250 DON)
// ═════════════════════════════════════════════════════════════════════
class _GridBookCard extends StatelessWidget {
  const _GridBookCard({required this.series});

  final AudiobookSeries series;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/audiobook-detail', extra: series),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cover — Expanded orqali qolgan joyni oladi (childAspectRatio
          // Karta balandligini boshqaradi, cover moslashadi).
          Expanded(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _CoverImage(book: series.cover),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            series.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                SolarIconsOutline.clockCircle,
                size: 13,
                color: _textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                // REAL jami davomiylik (qismlar yig'indisi); noma'lum -> "—".
                series.durationLabel,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '•',
                style: TextStyle(color: _textMuted, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Flexible(child: _DonPill(price: series.cover.xpReward)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Umumiy — muqova rasm (fallback rangli fon + speaker ikon)
// ═════════════════════════════════════════════════════════════════════
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context) {
    if (book.coverUrl.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: book.coverUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => Container(color: book.coverColor),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: book.coverColor,
      alignment: Alignment.center,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          SolarIconsBold.headphonesRound,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// "250 DON" pill — ko'k dumaloq badge
// ═════════════════════════════════════════════════════════════════════
class _DonPill extends StatelessWidget {
  const _DonPill({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$price',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'DON',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Bo'sh holat — filter ostida hech narsa topilmadi
// ═════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              SolarIconsOutline.bookmarkCircle,
              size: 56,
              color: _textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            const Text(
              'Kontent topilmadi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Boshqa kategoriyani tanlab ko\'ring',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// Qidiruv natijasi bo'sh — "topilmadi" holati.
class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: _textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            const Text(
              'Hech narsa topilmadi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Boshqa so'z bilan qidirib ko'ring",
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
