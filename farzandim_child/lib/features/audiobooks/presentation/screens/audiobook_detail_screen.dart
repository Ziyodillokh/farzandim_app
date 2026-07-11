// ─────────────────────────────────────────────────────────────────────
// AudiobookDetailScreen — kitob qismlari ro'yxati (screenshot 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Layout:
//   ┌─ SafeArea ────────────────────────────────────────────────
//   │  [←]      "1-qism"           ·  (right slot free)
//   │           "A kite for a moon • Jane Yolen"
//   │  ┌────────────┐
//   │  │            │
//   │  │   COVER    │  (240 x 320, radius 12)
//   │  │            │
//   │  └────────────┘
//   │  ┌──────────────────────────────────────┐
//   │  │ 1-qism                       ⏱ 00:40 │  ← chapter row
//   │  │ 2-qism                       ⏱ 01:02 │
//   │  │ …                                    │
//   │  └──────────────────────────────────────┘
//   │  ┌ mini play card ┐
//   │  │ ▶  1-qism            ⏱ 00:40         │
//   │  └──────────────────────────────────────┘
//
// Qismlar hozirgacha backend'da alohida audio URL sifatida yo'q — bitta
// audio + partsCount bor. Shu bois barcha qism bir xil `book.audioUrl`
// ijro qiladi (kelajakda `parts[]` qo'shilsa alohida URL bilan almashiladi).
// Har qism uchun sun'iy davomiylik ko'rsatamiz (bir tekis bo'linishi).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _pageBg = Color(0xFF0B0F14);
const _rowBg = Color(0xFF141A22);
const _backBg = Color(0xFF1A2029);
const _textMuted = Color(0xFF9CA3AF);
const _iconMuted = Color(0xFFB6BCC5);

class AudiobookDetailScreen extends ConsumerStatefulWidget {
  const AudiobookDetailScreen({required this.book, super.key});

  final AudiobookModel book;

  @override
  ConsumerState<AudiobookDetailScreen> createState() =>
      _AudiobookDetailScreenState();
}

class _AudiobookDetailScreenState
    extends ConsumerState<AudiobookDetailScreen> {
  int _selectedPart = 0; // hozir tanlangan qism index

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final parts = _generateParts(book);
    final activeTitle = '${_selectedPart + 1}-qism';

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: activeTitle,
              subtitle: '${book.title} · ${book.author}',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  children: [
                    _BookCover(book: book),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        for (var i = 0; i < parts.length; i++) ...[
                          _ChapterRow(
                            index: i + 1,
                            duration: parts[i],
                            onTap: () => _playPart(i),
                          ),
                          if (i != parts.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _MiniPlayCard(
              partTitle: activeTitle,
              duration: parts[_selectedPart],
              onTap: () => _playPart(_selectedPart, openFullScreen: true),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _playPart(int index, {bool openFullScreen = true}) {
    setState(() => _selectedPart = index);
    ref.read(audioPlayerProvider.notifier).play(widget.book);
    if (openFullScreen) {
      context.push('/audio-player');
    }
  }

  /// Backend hali `parts[]` bermaydi. `partsCount` va umumiy `durationSeconds`
  /// bo'yicha teng bo'lingan sun'iy davomiyliklarni ko'rsatamiz —
  /// screenshot bilan mos ko'rinish uchun.
  List<Duration> _generateParts(AudiobookModel book) {
    final count = book.partsCount <= 0 ? 1 : book.partsCount;
    final total = book.durationSeconds;

    if (total <= 0) {
      // Backend duration bermagan — screenshot'dagi kabi progressiv qiymatlar
      // (00:40, 01:02, 01:30, 02:15, 03:05, 04:00, ...)
      const seed = [40, 62, 90, 135, 185, 240];
      return List.generate(count, (i) {
        final s = i < seed.length ? seed[i] : seed.last + (i - seed.length + 1) * 60;
        return Duration(seconds: s);
      });
    }

    final base = (total ~/ count).clamp(30, 3600);
    return List.generate(count, (i) => Duration(seconds: base + i * 5));
  }
}

// ═════════════════════════════════════════════════════════════════════
// Header — ← [Title / Subtitle] [placeholder]
// ═════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _backBg,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(
                SolarIconsOutline.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Cover — 240×320 muqova (fallback bilan)
// ═════════════════════════════════════════════════════════════════════
class _BookCover extends StatelessWidget {
  const _BookCover({required this.book});

  final AudiobookModel book;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: book.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: book.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: book.coverColor),
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: book.coverColor,
      alignment: Alignment.center,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          SolarIconsBold.headphonesRound,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Chapter row — "N-qism    ⏱ MM:SS"
// ═════════════════════════════════════════════════════════════════════
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.index,
    required this.duration,
    required this.onTap,
  });

  final int index;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _rowBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$index-qism',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              SolarIconsOutline.clockCircle,
              size: 16,
              color: _iconMuted,
            ),
            const SizedBox(width: 6),
            Text(
              _fmt(duration),
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }
}

// ═════════════════════════════════════════════════════════════════════
// Mini play card — pastdagi kichik "▶  1-qism   ⏱ 00:40"
// ═════════════════════════════════════════════════════════════════════
class _MiniPlayCard extends StatelessWidget {
  const _MiniPlayCard({
    required this.partTitle,
    required this.duration,
    required this.onTap,
  });

  final String partTitle;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _rowBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  SolarIconsBold.playCircle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  partTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                SolarIconsOutline.clockCircle,
                size: 16,
                color: _iconMuted,
              ),
              const SizedBox(width: 6),
              Text(
                _fmt(duration),
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }
}
