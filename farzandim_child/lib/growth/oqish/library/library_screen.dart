// U11 · Kutubxona: qidiruv, kategoriya filtri, «Davom ettirish» (oxirgi
// tinglangan audiokitob) va guruhlar — audiokitob, videodars, maqola.
// Materiallar server tomonida yoshga mos va tasdiqlangan holda keladi.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/articles/presentation/providers/articles_providers.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/oqish/library/library_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Har guruhda dastlab ko'rsatiladigan materiallar soni.
const _collapsedCount = 4;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _query = TextEditingController();
  String? _category;
  final _expanded = <String>{};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String title, String category, [String extra = '']) {
    final q = _query.text.trim().toLowerCase();
    if (_category != null && category != _category) return false;
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) || extra.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(effectiveAudiobooksProvider);
    final videos = [
      for (final v in ref.watch(effectiveVideosProvider))
        if (!v.isReels) v,
    ];
    final articles = ref.watch(effectiveArticlesProvider);
    final loading =
        ref.watch(backendAudiobooksProvider).isLoading && books.isEmpty;
    final categories = {
      for (final b in books) b.category,
      for (final v in videos) v.category,
      for (final a in articles) a.category,
    }.where((c) => c.trim().isNotEmpty).toList()..sort();

    final series = groupIntoSeries([
      for (final b in books)
        if (_matches(b.title, b.category, b.author)) b,
    ]);
    final shownVideos = [
      for (final v in videos)
        if (_matches(v.title, v.category, v.description)) v,
    ];
    final shownArticles = [
      for (final a in articles)
        if (_matches(a.title, a.category)) a,
    ];
    final nothing =
        series.isEmpty && shownVideos.isEmpty && shownArticles.isEmpty;
    final filtering = _category != null || _query.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.library.title'.tr(),
          subtitle: 'g5.library.subtitle'.tr(),
        ),
        onRefresh: () async {
          ref
            ..invalidate(backendAudiobooksProvider)
            ..invalidate(backendVideosProvider)
            ..invalidate(backendArticlesProvider);
        },
        children: [
          _SearchField(controller: _query, onChanged: (_) => setState(() {})),
          if (categories.isNotEmpty)
            _CategoryChips(
              categories: categories,
              selected: _category,
              onSelect: (c) => setState(() => _category = c),
            ),
          if (!filtering) _ContinueCard(books: books),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              ),
            )
          else if (nothing)
            GNote(
              text: filtering
                  ? 'g5.library.nothing'.tr()
                  : 'g5.library.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.magnifyingGlass,
              action: filtering
                  ? GLink(
                      label: 'g5.library.clearFilters'.tr(),
                      onPressed: () => setState(() {
                        _category = null;
                        _query.clear();
                      }),
                    )
                  : null,
            )
          else ...[
            if (series.isNotEmpty)
              _group('audio', 'g5.library.audiobooks'.tr(), [
                for (final s in series)
                  GListItem(
                    title: s.title,
                    subtitle: s.isSeries
                        ? '${'g5.library.parts'.tr(namedArgs: {'count': '${s.parts.length}'})} · ${s.durationLabel}'
                        : s.durationLabel,
                    leading: _Cover(
                      url: s.cover.coverUrl,
                      icon: GIcons.bookOpen,
                      hue: GHue.green,
                    ),
                    onTap: () =>
                        GrowthLinks.audiobook(context, s.parts.first.id),
                  ),
              ]),
            if (shownVideos.isNotEmpty)
              _group('video', 'g5.library.videos'.tr(), [
                for (final v in shownVideos)
                  GListItem(
                    title: v.title,
                    subtitle: [
                      v.category,
                      if (v.hasDuration) v.duration,
                    ].where((s) => s.trim().isNotEmpty).join(' · '),
                    leading: _Cover(
                      url: v.thumbnailUrl,
                      icon: GIcons.filmStrip,
                      hue: GHue.blue,
                    ),
                    onTap: () => GrowthLinks.video(context, v.id),
                  ),
              ]),
            if (shownArticles.isNotEmpty)
              _group('article', 'g5.library.articles'.tr(), [
                for (final a in shownArticles)
                  GListItem(
                    title: a.title,
                    subtitle: [
                      a.category,
                      'g5.library.readMinutes'.tr(
                        namedArgs: {'count': '${articleReadingMinutes(a)}'},
                      ),
                    ].where((s) => s.trim().isNotEmpty).join(' · '),
                    leading: _Cover(
                      url: a.hasCover ? a.coverUrl : null,
                      icon: GIcons.article,
                      hue: GHue.teal,
                    ),
                    onTap: () => GrowthLinks.article(context, a.id),
                  ),
              ]),
          ],
        ],
      ),
    );
  }

  Widget _group(String key, String title, List<Widget> rows) {
    final expanded = _expanded.contains(key);
    final canExpand = rows.length > _collapsedCount;
    return GSection(
      title: title,
      actionLabel: canExpand
          ? (expanded ? 'g5.library.showLess' : 'g5.library.showAll').tr()
          : null,
      onAction: canExpand
          ? () => setState(
              () => expanded ? _expanded.remove(key) : _expanded.add(key),
            )
          : null,
      child: GList(
        children: expanded || !canExpand
            ? rows
            : rows.take(_collapsedCount).toList(),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: GColors.fieldFill,
        borderRadius: BorderRadius.circular(GRadius.field),
        border: Border.all(color: GColors.fieldBorder),
      ),
      child: Row(
        children: [
          const GIcon(
            GIcons.magnifyingGlass,
            size: 18,
            color: GColors.textMuted,
            secondaryOpacity: 0,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: 'g5.library.search'.tr(),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                keyboardAppearance: Brightness.dark,
                cursorColor: GColors.primary,
                style: GText.onest(16),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'g5.library.search'.tr(),
                  hintStyle: GText.onest(16, color: GColors.textFaint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? value) {
      final on = value == selected;
      return GPressable(
        onTap: () => onSelect(value),
        selected: on,
        exclusive: true,
        semanticLabel: label,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: on ? const Color(0x384F86FF) : const Color(0x0EFFFFFF),
            border: Border.all(
              color: on ? const Color(0x738CB4FF) : const Color(0x1AFFFFFF),
            ),
          ),
          child: Text(
            label,
            style: GText.onest(
              13.5,
              weight: FontWeight.w600,
              color: on ? GColors.white : GColors.textBody,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        children: [
          chip('g5.library.all'.tr(), null),
          for (final c in categories) ...[const SizedBox(width: 8), chip(c, c)],
        ],
      ),
    );
  }
}

/// Oxirgi tinglangan audiokitob — to'xtagan joyidan davom ettirish.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.books});

  final List<AudiobookModel> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastAudiobookProvider).valueOrNull;
    if (last == null) return const SizedBox.shrink();
    final book = books.where((b) => b.id == last.id).firstOrNull;
    if (book == null) return const SizedBox.shrink();
    final total = book.durationSeconds;
    final progress = total <= 0
        ? 0.0
        : (last.position.inSeconds / total).clamp(0.0, 1.0);
    return GPressable(
      onTap: () => GrowthLinks.audiobook(context, book.id),
      pressedScale: .98,
      child: GGlass(
        kind: GGlassKind.feat,
        glowHue: GHue.green,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _Cover(
              url: book.coverUrl,
              icon: GIcons.bookOpen,
              hue: GHue.green,
              size: 60,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'g5.library.continueLabel'.tr().toUpperCase(),
                    style: GText.label.copyWith(color: GColors.link),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GText.h3,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'g5.library.stoppedAt'.tr(
                      namedArgs: {'time': _clock(last.position)},
                    ),
                    style: GText.caption,
                  ),
                  const SizedBox(height: 8),
                  GProgressBar(value: progress),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: GEffects.primaryGradient,
              ),
              alignment: Alignment.center,
              child: const GIcon(
                GIcons.play,
                size: 20,
                color: GColors.white,
                secondaryOpacity: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _clock(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Muqova shu baravar kattaroq qutida dekod qilinadi: kvadratni `cover` bilan
/// to'ldirganda 2:1 gacha nisbatdagi rasmning (yotiq video kadri, tik kitob
/// muqovasi) qisqa tomoni ham ekrandagi o'lchamdan kichik qolmaydi.
const _kCoverDecodeScale = 2.0;

/// Muqova paydo bo'lishi (avvalgi CachedNetworkImage fade'iga mos).
const _kCoverFade = Duration(milliseconds: 500);

/// Muqova: rasm bo'lsa rasm, bo'lmasa rangli plita.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.url,
    required this.icon,
    required this.hue,
    this.size = 48,
  });

  final String? url;
  final GIconData icon;
  final GHue hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tile = GTile(icon: icon, hue: hue, size: size);
    final src = url?.trim() ?? '';
    if (src.isEmpty) return tile;
    // Ro'yxat muqovasi ekrandagi o'lchamda dekod qilinadi: to'liq o'lchamli
    // 1200×1600 muqova xotirada ~7.7 MB edi. `fit` nisbatni saqlaydi (eni va
    // bo'yi `exact` bilan berilsa rasm cho'zilib qolardi).
    final box =
        (size * _kCoverDecodeScale * MediaQuery.devicePixelRatioOf(context))
            .round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .31),
      child: Image(
        image: ResizeImage(
          CachedNetworkImageProvider(src),
          width: box,
          height: box,
          policy: ResizeImagePolicy.fit,
        ),
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: (_, image, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded
            ? image
            : AnimatedSwitcher(
                duration: _kCoverFade,
                child: frame == null ? tile : image,
              ),
        errorBuilder: (_, _, _) => tile,
      ),
    );
  }
}
