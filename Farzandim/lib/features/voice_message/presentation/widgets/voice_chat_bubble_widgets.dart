// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'voice_chat_bubble.dart';

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
          if (isOwn) const Spacer(),
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
          if (!isOwn) const Spacer(),
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
          if (isOwn) const Spacer(),
          Flexible(flex: 5, child: content),
          if (!isOwn) const Spacer(),
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
