// ─────────────────────────────────────────────────────────────────────
// ChatBubble — Telegram-style ovozli xabar bubble (real audio)
// ─────────────────────────────────────────────────────────────────────
//
// `isOwn=true` (bola yuborgan) → o'ngda lime green bubble.
// `isOwn=false` (Parent yuborgan) → chapda surface bubble.
// Bubble bossa AudioPlayerManager.playOrToggle ishga tushadi —
// boshqa bubble'lar avtomatik to'xtaydi (singleton).
// Real-time waveform progress + position display.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim_child/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/voice_message/presentation/providers/voice_message_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

// Parvoz tokenlar — ota-ona ilovasidagi chat bilan BIR XIL.
const _pBlue = Color(0xFF216BFF);
const _recvBubble = Color(0xFF1C232B);
const _pDim = Color(0x8CFFFFFF);

class ChatBubble extends ConsumerWidget {
  const ChatBubble({required this.message, required this.isOwn, super.key});

  final VoiceMessage message;
  final bool isOwn;

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '0:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Deterministik fake waveform — message ID hash'idan natural-looking
  /// amplitudalar (Backend hozircha waveform saqlamaydi).
  List<double> _generateWaveform(String seed, int barCount) {
    final hash = seed.hashCode.abs();
    final result = <double>[];
    var x = hash;
    for (var i = 0; i < barCount; i++) {
      x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
      // 0.25-1.0 range — chiroyli amplitudalar, juda past bo'lmagan
      final normalized = 0.25 + ((x % 1000) / 1000) * 0.75;
      result.add(normalized);
    }
    return result;
  }

  // ── Telegram uslubidagi xabar menyusi (uzoq bosilganda) ──
  void _showMessageMenu(BuildContext context, WidgetRef ref) {
    if (message.id == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15181E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 6),
            if (isOwn && message.isText)
              _MenuRow(
                icon: Icons.edit_rounded,
                label: 'Tahrirlash',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _editMessage(context, ref);
                },
              ),
            _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: "O'chirish",
              destructive: true,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _deleteMessage(context, ref);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(BuildContext context, WidgetRef ref) async {
    final id = message.id;
    if (id == null) return;
    final ok = await ref
        .read(backendVoiceMessageRepositoryProvider)
        .deleteMessage(id);
    ref.invalidate(voiceMessagesProvider);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Xabar o'chirilmadi"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editMessage(BuildContext context, WidgetRef ref) async {
    final id = message.id;
    if (id == null) return;
    final ctrl = TextEditingController(text: message.text ?? '');
    final newText = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF15181E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Xabarni tahrirlash',
              style: GoogleFonts.unbounded(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2128),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 1,
                maxLines: 5,
                cursorColor: _pBlue,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.of(sheetCtx).pop(ctrl.text),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _pBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Saqlash',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final trimmed = newText?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == message.text) {
      return;
    }
    final ok = await ref
        .read(backendVoiceMessageRepositoryProvider)
        .updateText(id, trimmed);
    ref.invalidate(voiceMessagesProvider);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xabar tahrirlanmadi'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Matn bubble — Parvoz (ota-ona ilovasi bilan bir xil):
  // own — ko'k (#216BFF), receiver — to'q kulrang (#1C232B), matn oq.
  Widget _buildTextBubble(BuildContext context, WidgetRef ref) {
    final metaColor = isOwn ? Colors.white70 : _pDim;
    final isSeen = message.status == VoiceMessageStatus.seen;
    final time = message.createdAt != null
        ? _formatTime(message.createdAt!)
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(flex: 1),
          Flexible(
            flex: 5,
            child: GestureDetector(
              // Telegram uslubi: uzoq bosilsa tahrirlash/o'chirish menyusi.
              onLongPress: () => _showMessageMenu(context, ref),
              child: Container(
                constraints: const BoxConstraints(minWidth: 80),
                padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
                decoration: BoxDecoration(
                  color: isOwn ? _pBlue : _recvBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isOwn ? 18 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message.text ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: GoogleFonts.poppins(
                            color: metaColor,
                            fontSize: 11,
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isSeen
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isOwn) const Spacer(flex: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Telegram-style text xabar — alohida bubble.
    if (message.isText) {
      return _buildTextBubble(context, ref);
    }

    final currentId = ref.watch(currentlyPlayingIdProvider).value;
    final isCurrent = currentId == message.id;

    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);
    final playerState = ref.watch(audioPlayerStateProvider).value;

    final position = isCurrent
        ? (positionAsync.value ?? Duration.zero)
        : Duration.zero;
    final duration = isCurrent
        ? (durationAsync.value ?? Duration(seconds: message.durationSeconds))
        : Duration(seconds: message.durationSeconds);

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble()
        : 0.0;
    final isPlaying = isCurrent && (playerState?.playing ?? false);
    final processing = playerState?.processingState;
    final isLoading =
        isCurrent &&
        (processing == ProcessingState.loading ||
            processing == ProcessingState.buffering);
    final displayDuration = isPlaying
        ? position.inSeconds
        : message.durationSeconds;
    final speed = ref.watch(audioSpeedProvider).value ?? 1.0;
    final speedLabel = speed == 1.0
        ? '1×'
        : speed == 1.5
        ? '1.5×'
        : '2×';

    // Parvoz: own — ko'k, receiver — to'q kulrang; matn har doim oq.
    final bubbleColor = isOwn ? _pBlue : _recvBubble;
    const textColor = Colors.white;
    final waveformColor = isOwn ? Colors.white : _pBlue;
    final playTint = isOwn ? Colors.white : _pBlue;
    final isSeen = message.status == VoiceMessageStatus.seen;
    // Premium: 36 ta rounded pill — Parent bubble bilan parallel.
    const barCount = 36;
    final waveformAmps = message.waveform.isNotEmpty
        ? message.waveform
        : _generateWaveform(message.id ?? 'fallback', barCount);
    final visibleBars = waveformAmps.length.clamp(0, barCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(flex: 1),
          Flexible(
            flex: 4,
            child: GestureDetector(
              // Telegram uslubi: uzoq bosilsa o'chirish menyusi.
              onLongPress: () => _showMessageMenu(context, ref),
              onTap: () async {
                final id = message.id;
                if (id == null) return;
                // Sprint 4.4.5: Backend signed URL fetch (1 soat amal).
                // audioUrl bo'sh bo'lsa — Backend'dan olamiz.
                var url = message.audioUrl;
                if (url.isEmpty) {
                  url =
                      await ref
                          .read(backendVoiceMessageRepositoryProvider)
                          .getFileUrl(id) ??
                      '';
                }
                if (url.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Audio URL olinmadi'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                try {
                  await ref
                      .read(audioPlayerManagerProvider)
                      .playOrToggle(messageId: id, audioUrl: url);
                  // Sprint 4.4.5: read receipt — boshqa tomondan kelgan
                  // va hali tinglanmagan xabar bo'lsa Backend'ga belgi.
                  if (!isOwn && message.status == VoiceMessageStatus.sent) {
                    await ref
                        .read(backendVoiceMessageRepositoryProvider)
                        .markAsRead(id);
                    // Provider refresh — bubble `seen` indicatorga o'tadi.
                    ref.invalidate(voiceMessagesProvider);
                  }
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ovozli xabar yuklanmadi'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isOwn ? 20 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: playTint.withValues(alpha: isOwn ? 0.22 : 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: playTint,
                              ),
                            )
                          : Icon(
                              isPlaying ? AppIcons.pause : AppIcons.play,
                              color: playTint,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 160,
                          height: 32,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(visibleBars, (i) {
                              final amp = waveformAmps[i];
                              final isPlayed = progress > (i / visibleBars);
                              // Premium: rounded pill bars, 1.5px gap,
                              // played qism solid, unplayed 32% alpha.
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  child: Container(
                                    height: (amp * 32).clamp(4.0, 32.0),
                                    decoration: BoxDecoration(
                                      color: isPlayed
                                          ? waveformColor
                                          : waveformColor
                                            // ignore: deprecated_member_use
                                            .withOpacity(0.32),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(displayDuration),
                              style: TextStyle(
                                // ignore: deprecated_member_use
                                color: textColor.withOpacity(0.7),
                                fontSize: 11,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (message.createdAt != null)
                              Text(
                                _formatTime(message.createdAt!),
                                style: TextStyle(
                                  // ignore: deprecated_member_use
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            if (isOwn) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isSeen
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => ref
                                    .read(audioPlayerManagerProvider)
                                    .toggleSpeed(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    // ignore: deprecated_member_use
                                    color: textColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    speedLabel,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isOwn) const Spacer(flex: 1),
        ],
      ),
    );
  }
}

/// Menyu qatori (Telegram uslubi): ikon + yozuv.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFFF5A5A) : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
