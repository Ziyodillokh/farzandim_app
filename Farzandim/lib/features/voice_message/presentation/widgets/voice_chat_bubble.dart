import 'dart:io';

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

/// Telegram uslubidagi xabar bubble (matn / rasm / hujjat / audio).
///
/// `isOwn = true` — ota-ona yuborgan (o'ng tomon, primary/yashil fon).
/// `isOwn = false` — bola yuborgan (chap tomon, surface/to'q fon).
///
/// Audio: tap → `AudioPlayerManager` orqali play/pause toggle.
class VoiceChatBubble extends ConsumerWidget {
  /// `VoiceChatBubble` konstruktor.
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
      // 0.25-1.0 range — chiroyli amplitudalar, juda past bo'lmagan
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

    // PERF-09: playerState/speed faqat IJRODAGI bubble'da watch qilinadi —
    // avval shartsiz edi: ijro paytida har holat o'zgarishi BARCHA
    // bubble'larni (uzun chatda o'nlab) rebuild qildirardi.
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
                  // Sprint 4.4.5: read receipt — bola yuborgan xabarni
                  // parent tinglagan paytda Backend'ga belgi yuboramiz.
                  if (!isOwn &&
                      message.status == VoiceMessageStatus.sent) {
                    await ref
                        .read(backendVoiceMessageRepositoryProvider)
                        .markAsRead(message.id);
                    // Provider refresh — bubble `seen` indicatorga o'tadi.
                    ref.invalidate(voiceMessagesProvider(message.childId));
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: List.generate(visibleCount, (i) {
                                  final amp = amps[i];
                                  final barIdx = i / visibleCount;
                                  final isPlayed = progress > barIdx;
                                  // Premium: rounded pill bars, 1px gap,
                                  // played qism solid, unplayed shaffof
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

/// Premium bubble soyasi — wallpaper ustida bubble bo'rtib turadi.
const List<BoxShadow> _bubbleShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1)),
];

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message, required this.isOwn});

  final VoiceMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isOwn ? AppColors.primary : AppColors.surface;
    final textColor = isOwn ? Colors.black : AppColors.textPrimary;
    final metaColor = isOwn
        ? Colors.black.withValues(alpha: 0.55)
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(flex: 1),
          Flexible(
            flex: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOwn ? 18 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 18),
                ),
                boxShadow: _bubbleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text ?? '',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _BubbleMeta(
                    message: message,
                    isOwn: isOwn,
                    color: metaColor,
                  ),
                ],
              ),
            ),
          ),
          if (!isOwn) const Spacer(flex: 1),
        ],
      ),
    );
  }
}

/// Vaqt + (own bo'lsa) o'qildi belgisi — bubble pastki o'ng burchak.
class _BubbleMeta extends StatelessWidget {
  const _BubbleMeta({
    required this.message,
    required this.isOwn,
    required this.color,
  });

  final VoiceMessage message;
  final bool isOwn;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _formatTimeShort(message.createdAt),
          style: TextStyle(color: color, fontSize: 11),
        ),
        if (isOwn) ...[
          const SizedBox(width: 4),
          Icon(
            message.isSeen ? Icons.done_all : Icons.done,
            size: 14,
            color: message.isSeen
                ? Colors.blue.shade700
                : color,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Rasm bubble
// ─────────────────────────────────────────────────────────────────────

class _ImageBubble extends ConsumerWidget {
  const _ImageBubble({required this.message, required this.isOwn});

  final VoiceMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref
        .read(backendVoiceMessageRepositoryProvider)
        .mediaUrl(message.mediaKey!);
    final caption = message.text;
    final hasCaption = caption != null && caption.isNotEmpty;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isOwn ? 18 : 4),
      bottomRight: Radius.circular(isOwn ? 4 : 18),
    );

    final image = GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _FullScreenImage(url: url),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300, minHeight: 120),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 200,
              color: Colors.black.withValues(alpha: 0.08),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            color: Colors.black.withValues(alpha: 0.08),
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary,
              size: 40,
            ),
          ),
        ),
      ),
    );

    // Caption bo'lmasa — sof rasm + vaqt overlay (yashil "teppa" yo'q).
    // Caption bo'lsa — rasm + matn bubble fonida.
    final Widget content = hasCaption
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: isOwn ? AppColors.primary : AppColors.surface,
              borderRadius: radius,
              boxShadow: _bubbleShadow,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  image,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          caption,
                          style: TextStyle(
                            color:
                                isOwn ? Colors.black : AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _BubbleMeta(
                          message: message,
                          isOwn: isOwn,
                          color: isOwn
                              ? Colors.black.withValues(alpha: 0.55)
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: _bubbleShadow,
            ),
            child: Stack(
              children: [
                ClipRRect(borderRadius: radius, child: image),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _ImageOverlayMeta(message: message, isOwn: isOwn),
                ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(flex: 1),
          Flexible(flex: 5, child: content),
          if (!isOwn) const Spacer(flex: 1),
        ],
      ),
    );
  }
}

/// Rasm ustidagi vaqt + o'qildi belgisi (caption yo'q rasm uchun).
class _ImageOverlayMeta extends StatelessWidget {
  const _ImageOverlayMeta({required this.message, required this.isOwn});

  final VoiceMessage message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTimeShort(message.createdAt),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          if (isOwn) ...[
            const SizedBox(width: 3),
            Icon(
              message.isSeen ? Icons.done_all : Icons.done,
              size: 13,
              color: message.isSeen ? Colors.lightBlueAccent : Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

/// To'liq ekran rasm ko'rish (zoom).
class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hujjat (file) bubble — tap → yuklab olib native ilovada ochish
// ─────────────────────────────────────────────────────────────────────

class _FileBubble extends ConsumerStatefulWidget {
  const _FileBubble({required this.message, required this.isOwn});

  final VoiceMessage message;
  final bool isOwn;

  @override
  ConsumerState<_FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends ConsumerState<_FileBubble> {
  bool _busy = false;

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconFor(String? mime, String? name) {
    final m = mime ?? '';
    final n = (name ?? '').toLowerCase();
    if (m.contains('pdf') || n.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    if (m.startsWith('video/')) return Icons.movie_outlined;
    if (m.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (m.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (m.contains('sheet') ||
        m.contains('excel') ||
        n.endsWith('.xls') ||
        n.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    if (m.contains('zip') || m.contains('rar') || m.contains('compressed')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Future<void> _openFile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(backendVoiceMessageRepositoryProvider);
      final url = repo.mediaUrl(widget.message.mediaKey!);
      final dir = await getTemporaryDirectory();
      final safeName = (widget.message.fileName ?? 'fayl')
          .replaceAll(RegExp(r'[^\w\-. ]'), '_');
      final savePath = '${dir.path}/${widget.message.id}_$safeName';
      final file = File(savePath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        // ARCH-05: yalang'och Dio() emas — umumiy klient (timeout'lar bor,
        // cheksiz osilish yo'q; URL absolute bo'lgani uchun baseUrl bezarar).
        await ref.read(dioClientProvider).download(url, savePath);
      }
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('voiceChat.fileOpenFailed'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('voiceChat.fileOpenFailed'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwn;
    final message = widget.message;
    final fg = isOwn ? Colors.black : AppColors.textPrimary;
    final subColor = isOwn
        ? Colors.black.withValues(alpha: 0.55)
        : AppColors.textSecondary;
    final iconBg =
        isOwn ? Colors.black.withValues(alpha: 0.12) : AppColors.primary;
    final iconFg = isOwn ? Colors.black : Colors.black;
    final caption = message.text;
    final hasCaption = caption != null && caption.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(flex: 1),
          Flexible(
            flex: 5,
            child: GestureDetector(
              onTap: _openFile,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
                decoration: BoxDecoration(
                  color: isOwn ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isOwn ? 18 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 18),
                  ),
                  boxShadow: _bubbleShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: _busy
                              ? Padding(
                                  padding: const EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: iconFg,
                                  ),
                                )
                              : Icon(
                                  _iconFor(message.mimeType, message.fileName),
                                  color: iconFg,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.fileName ?? 'voiceChat.fileGeneric'.tr(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatSize(message.fileSize),
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasCaption) ...[
                      const SizedBox(height: 8),
                      Text(
                        caption,
                        style: TextStyle(
                          color: fg,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    _BubbleMeta(
                      message: message,
                      isOwn: isOwn,
                      color: subColor,
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
