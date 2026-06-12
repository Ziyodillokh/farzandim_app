import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/dio_client.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/features/voice_message/data/models/voice_message.dart';
import 'package:farzandim/features/voice_message/data/repositories/backend_voice_message_repository.dart';
import 'package:farzandim/features/voice_message/presentation/providers/audio_player_provider.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

part 'voice_chat_bubble_widgets.dart';
part 'voice_chat_bubble_file.dart';

/// Telegram uslubidagi xabar bubble (matn / rasm / hujjat / audio).
///
/// `isOwn = true` — ota-ona yuborgan (o'ng tomon, primary/yashil fon).
/// `isOwn = false` — bola yuborgan (chap tomon, surface/to'q fon).
///
/// Audio: tap → `AudioPlayerManager` orqali play/pause toggle.
class VoiceChatBubble extends ConsumerWidget {
  const VoiceChatBubble({
    required this.message,
    required this.isOwn,
    super.key,
  });

  /// Ko'rsatilayotgan xabar.
  final VoiceMessage message;

  /// Ota-ona yuborganmi (o'ng/chap tomon).
  final bool isOwn;

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Deterministik fake waveform — message ID hash'idan natural-looking
  /// amplitudalar (Backend hozircha waveform saqlamaydi).
  List<double> _generateWaveform(String seed, int barCount) {
    final hash = seed.hashCode.abs();
    final result = <double>[];
    var x = hash;
    for (var i = 0; i < barCount; i++) {
      x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
      // 0.25-1.0 oralig'i — barlar juda past ko'rinmasligi uchun
      final normalized = 0.25 + ((x % 1000) / 1000) * 0.75;
      result.add(normalized);
    }
    return result;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '0:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ─── Telegram-style matn / media bubble'lari ───
    if (message.isText) {
      return _TextBubble(message: message, isOwn: isOwn);
    }
    if (message.isImage) {
      return _ImageBubble(message: message, isOwn: isOwn);
    }
    if (message.isFile) {
      return _FileBubble(message: message, isOwn: isOwn);
    }

    // ─── Audio (ovozli) bubble — mavjud dizayn ───
    final currentId = ref.watch(currentlyPlayingIdProvider).value;
    final isCurrent = currentId == message.id;

    final position = isCurrent
        ? ref.watch(audioPositionProvider).value ?? Duration.zero
        : Duration.zero;
    final duration = isCurrent
        ? ref.watch(audioDurationProvider).value ??
            Duration(seconds: message.durationSeconds)
        : Duration(seconds: message.durationSeconds);

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    // playerState/speed faqat ijrodagi bubble'da watch qilinadi —
    // shartsiz watch ijro paytida har holat o'zgarishida barcha
    // bubble'larni rebuild qildirardi.
    final playerState =
        isCurrent ? ref.watch(audioPlayerStateProvider).value : null;
    final isPlaying = isCurrent && (playerState?.playing ?? false);
    final processingState = playerState?.processingState;
    final isLoading = isCurrent &&
        (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering);

    final speed =
        isCurrent ? (ref.watch(audioSpeedProvider).value ?? 1.0) : 1.0;

    final bubbleColor = isOwn ? AppColors.primary : AppColors.surface;
    final textColor = isOwn ? Colors.black : AppColors.textPrimary;
    final waveformColor =
        isOwn ? Colors.black.withValues(alpha: 0.6) : AppColors.accent;

    final displayDuration = isPlaying
        ? position
        : Duration(seconds: message.durationSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(),
          Flexible(
            flex: 4,
            child: GestureDetector(
              onTap: () async {
                // Audio proxy stream URL — signed URL telefondan yetib
                // bo'lmaydi (ichki MinIO manzili); just_audio shu @Public
                // URL'dan to'g'ridan o'ynaydi.
                final url = ref
                    .read(backendVoiceMessageRepositoryProvider)
                    .audioStreamUrl(message.id);
                try {
                  await ref
                      .read(audioPlayerManagerProvider)
                      .playOrToggle(
                        messageId: message.id,
                        audioUrl: url,
                      );
                  // Read receipt — bola yuborgan xabarni parent
                  // tinglaganda backend'ga belgi yuboramiz.
                  if (!isOwn &&
                      message.status == VoiceMessageStatus.sent) {
                    await ref
                        .read(backendVoiceMessageRepositoryProvider)
                        .markAsRead(message.id);
                    // Provider refresh — bubble `seen` indicatorga o'tadi.
                    ref.invalidate(rawVoiceMessagesProvider);
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('voiceChat.loadFailedSnack'.tr()),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
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
                  boxShadow: _bubbleShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: textColor,
                              ),
                            )
                          : Icon(
                              isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: textColor,
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
                          child: Builder(
                            builder: (_) {
                              const barCount = 36;
                              // Backend waveform yo'q → deterministic fake
                              final amps = message.waveform.isNotEmpty
                                  ? message.waveform
                                  : _generateWaveform(message.id, barCount);
                              final visibleCount =
                                  amps.length.clamp(0, barCount);
                              return Row(
                                children: List.generate(visibleCount, (i) {
                                  final amp = amps[i];
                                  final barIdx = i / visibleCount;
                                  final isPlayed = progress > barIdx;
                                  // Yumaloq pill barlar: played qism
                                  // solid, unplayed shaffof
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
                                                  .withValues(alpha: 0.32),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(displayDuration.inSeconds),
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            if (isOwn) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isSeen
                                    ? Icons.done_all
                                    : Icons.done,
                                size: 14,
                                color: message.isSeen
                                    ? Colors.blue.shade400
                                    : textColor.withValues(alpha: 0.5),
                              ),
                            ],
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  await ref
                                      .read(audioPlayerManagerProvider)
                                      .toggleSpeed();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    speed == 1.0
                                        ? '1×'
                                        : speed == 1.5
                                            ? '1.5×'
                                            : '2×',
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
          if (!isOwn) const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Matn bubble (Telegram-style)
// ─────────────────────────────────────────────────────────────────────

String _formatTimeShort(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Bubble soyasi — wallpaper ustida bo'rtib ko'rinishi uchun.
const List<BoxShadow> _bubbleShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
];
