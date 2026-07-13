// ─────────────────────────────────────────────────────────────────────
// AudiobookDetailScreen — kitob qismlari ro'yxati (REAL qismlar)
// ─────────────────────────────────────────────────────────────────────
//
// Bitta kitob (seriya) — qismlari ichida:
//   ┌─ SafeArea ────────────────────────────────────────────────
//   │  [←]      "11-qism"
//   │           "Mehrobdan chayon • Abdulla Qodiriy"
//   │  [ COVER 240x320 ]
//   │  │ 11-qism                      ⏱ 30:21 │  ← REAL davomiylik
//   │  │ 12-qism                      ⏱ 45:15 │
//   │  │ …                                    │
//   │  [▶  11-qism            ⏱ 30:21]        ← mini play card
//
// Har qism — alohida audiokitob yozuvi (o'z audio URL'i bilan): bosilsa
// AYNAN O'SHA qism ijro etiladi. Davomiylik backend'dagi REAL qiymat
// (birinchi ijroda aniqlanib saqlanadi); hali noma'lum bo'lsa "—".

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
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
  const AudiobookDetailScreen({required this.series, super.key});

  final AudiobookSeries series;

  @override
  ConsumerState<AudiobookDetailScreen> createState() =>
      _AudiobookDetailScreenState();
}

class _AudiobookDetailScreenState extends ConsumerState<AudiobookDetailScreen> {
  int _selectedPart = 0; // hozir tanlangan qism indeksi

  String _partLabel(int i) => '${widget.series.partNumbers[i]}-qism';

  @override
  Widget build(BuildContext context) {
    final series = widget.series;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: _partLabel(_selectedPart),
              subtitle: '${series.title} · ${series.author}',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  children: [
                    _BookCover(book: series.cover),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        for (var i = 0; i < series.parts.length; i++) ...[
                          _ChapterRow(
                            label: _partLabel(i),
                            durationLabel: formatDuration(
                              series.parts[i].durationSeconds,
                            ),
                            onTap: () => _playPart(i),
                          ),
                          if (i != series.parts.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _MiniPlayCard(
              partTitle: _partLabel(_selectedPart),
              durationLabel: formatDuration(
                series.parts[_selectedPart].durationSeconds,
              ),
              onTap: () => _playPart(_selectedPart),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _playPart(int index, {bool openFullScreen = true}) {
    setState(() => _selectedPart = index);
    // Har qism ALOHIDA audiokitob — o'z URL'i ijro etiladi.
    ref.read(audioPlayerProvider.notifier).play(widget.series.parts[index]);
    if (openFullScreen) {
      context.push('/audio-player');
    }
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
// Chapter row — "N-qism    ⏱ MM:SS" (REAL davomiylik, noma'lum → "—")
// ═════════════════════════════════════════════════════════════════════
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.label,
    required this.durationLabel,
    required this.onTap,
  });

  final String label;
  final String durationLabel;
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
                label,
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
              durationLabel,
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
}

// ═════════════════════════════════════════════════════════════════════
// Mini play card — pastdagi kichik "▶  N-qism   ⏱ MM:SS"
// ═════════════════════════════════════════════════════════════════════
class _MiniPlayCard extends StatelessWidget {
  const _MiniPlayCard({
    required this.partTitle,
    required this.durationLabel,
    required this.onTap,
  });

  final String partTitle;
  final String durationLabel;
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
                durationLabel,
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
}
