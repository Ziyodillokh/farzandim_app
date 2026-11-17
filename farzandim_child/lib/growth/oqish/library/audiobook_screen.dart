// U12 · Audiokitob: muqova, bob nomi, vaqt chizig'i, ±15 soniya, ijro/to'xtatish,
// tezlik va boblar ro'yxati. Pleyer — mavjud global `audioPlayerProvider`
// (fon ijrosi, joyni saqlash, tugaganda DON) — bu yerda faqat ko'rinish.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/growth/oqish/library/library_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _speeds = [1.0, 1.25, 1.5, .75];

class AudiobookScreen extends ConsumerWidget {
  const AudiobookScreen({super.key, required this.bookId});

  /// Seriyadagi istalgan qism id'si.
  final String bookId;

  Future<void> _play(WidgetRef ref, AudiobookModel part) async {
    await ref.read(lastAudiobookProvider.notifier).remember(part.id);
    await ref.read(audioPlayerProvider.notifier).play(part);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(effectiveAudiobooksProvider);
    final series = seriesContaining(books, bookId);
    final player = ref.watch(audioPlayerProvider);
    final top = GTopBar(
      leading: GTopBar.back(
        label: 'g5.common.back'.tr(),
        onPressed: () => context.pop(),
      ),
      title: 'g5.library.player.title'.tr(),
      subtitle: 'g5.library.title'.tr(),
    );
    if (series == null) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: top,
          children: [
            if (books.isEmpty)
              Text(
                'g5.common.loading'.tr(),
                textAlign: TextAlign.center,
                style: GText.caption,
              )
            else
              GNote(
                text: 'g5.library.player.notFound'.tr(),
                kind: GNoteKind.warn,
              ),
          ],
        ),
      );
    }
    final current = player.currentBook;
    final isThisSeries =
        current != null && series.parts.any((p) => p.id == current.id);
    final active = isThisSeries
        ? current
        : series.parts.firstWhere(
            (p) => p.id == bookId,
            orElse: () => series.parts.first,
          );
    final index = series.parts.indexWhere((p) => p.id == active.id);
    final number = series.partNumbers.length > index
        ? series.partNumbers[index]
        : index + 1;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.green,
        top: top,
        children: [
          _PlayerCard(
            series: series,
            part: active,
            partNumber: series.isSeries ? number : null,
            state: isThisSeries ? player : null,
            onPlay: () => isThisSeries
                ? ref.read(audioPlayerProvider.notifier).resume()
                : _play(ref, active),
          ),
          if (isThisSeries && player.error != null)
            GNote(
              text: 'g5.library.player.unavailable'.tr(),
              kind: GNoteKind.warn,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => _play(ref, active),
              ),
            ),
          if (series.isSeries)
            GSection(
              title: 'g5.library.player.chapters'.tr(),
              trailing: Text(
                '${'g5.library.parts'.tr(namedArgs: {'count': '${series.parts.length}'})} · ${series.durationLabel}',
                style: GText.onest(
                  12.5,
                  weight: FontWeight.w600,
                  color: GColors.textMuted,
                ),
              ),
              child: GList(
                children: [
                  for (var i = 0; i < series.parts.length; i++)
                    GListItem(
                      leading: GTile(
                        icon: series.parts[i].id == active.id
                            ? GIcons.speakerHigh
                            : GIcons.bookOpen,
                        hue: GHue.green,
                        size: 40,
                      ),
                      title: 'g5.library.player.part'.tr(
                        namedArgs: {
                          'number':
                              '${series.partNumbers.length > i ? series.partNumbers[i] : i + 1}',
                        },
                      ),
                      subtitle: formatDuration(series.parts[i].durationSeconds),
                      trailing: series.parts[i].id == active.id && isThisSeries
                          ? GChip(
                              label: 'g5.library.player.now'.tr(),
                              kind: GChipKind.info,
                            )
                          : null,
                      showChevron: false,
                      onTap: () => _play(ref, series.parts[i]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({
    required this.series,
    required this.part,
    required this.partNumber,
    required this.state,
    required this.onPlay,
  });

  final AudiobookSeries series;
  final AudiobookModel part;
  final int? partNumber;

  /// `null` — bu kitob hozir pleyerda emas.
  final AudioPlayerState? state;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(audioPlayerProvider.notifier);
    final playing = state?.isPlaying ?? false;
    final position = state?.position ?? Duration.zero;
    final duration = state?.duration ?? Duration(seconds: part.durationSeconds);
    final speed = ref.watch(audioSpeedProvider);
    final max = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    return GGlass(
      kind: GGlassKind.feat,
      glowHue: GHue.green,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GTile(icon: GIcons.bookOpen, hue: GHue.green, size: 96),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        series.title,
                        style: GText.display(20).copyWith(height: 1.25),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partNumber != null
                          ? 'g5.library.player.part'.tr(
                              namedArgs: {'number': '$partNumber'},
                            )
                          : series.author,
                      style: GText.onest(
                        14,
                        weight: FontWeight.w600,
                        color: GColors.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'g5.library.player.position'.tr(),
            value: '${_clock(position)} / ${_clock(duration)}',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: GColors.primary,
                inactiveTrackColor: const Color(0x14FFFFFF),
                thumbColor: GColors.white,
                overlayColor: const Color(0x244F86FF),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                max: max,
                onChanged: state == null
                    ? null
                    : (v) => notifier.seek(Duration(milliseconds: v.round())),
              ),
            ),
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                Text(_clock(position), style: GText.display(13)),
                const Spacer(),
                Text(
                  _clock(duration),
                  style: GText.onest(
                    13,
                    weight: FontWeight.w600,
                    color: GColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Skip(
                icon: GIcons.arrowCounterClockwise,
                label: 'g5.library.player.back15'.tr(),
                onTap: state == null ? null : () => notifier.seekBackward(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GButton(
                  label:
                      (playing
                              ? 'g5.library.player.pause'
                              : 'g5.library.player.play')
                          .tr(),
                  icon: playing ? GIcons.pause : GIcons.play,
                  onPressed: playing ? notifier.pause : onPlay,
                ),
              ),
              const SizedBox(width: 10),
              _Skip(
                icon: GIcons.arrowClockwise,
                label: 'g5.library.player.fwd15'.tr(),
                onTap: state == null ? null : () => notifier.seekForward(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GButton(
                label:
                    '${'g5.library.player.speed'.tr()} ${_speedLabel(speed)}',
                icon: GIcons.gauge,
                kind: GButtonKind.ghost,
                size: GButtonSize.md,
                expand: false,
                onPressed: () {
                  final next =
                      _speeds[(_speeds.indexOf(speed) + 1) % _speeds.length];
                  ref.read(audioSpeedProvider.notifier).state = next;
                  notifier.setSpeed(next);
                },
              ),
              const Spacer(),
              const GIcon(
                GIcons.checkCircle,
                size: 16,
                color: Color(0xFF8BE8C0),
              ),
              const SizedBox(width: 6),
              Text(
                'g5.library.player.kept'.tr(),
                style: GText.onest(
                  12.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFF8BE8C0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Skip extends StatelessWidget {
  const _Skip({required this.icon, required this.label, required this.onTap});

  final GIconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) =>
      GIconButton(icon: icon, label: label, onPressed: onTap, size: 22);
}

String _speedLabel(double speed) =>
    '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';

String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '${d.inMinutes}:$s';
}
