// Matn va rasm bubble'lari + meta (vaqt, o'qildi belgisi) widget'lari.
part of 'voice_chat_bubble.dart';

/// Xabar menyusidagi bitta qator (tahrirlash / o'chirish).
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
            Text(label, style: TextStyle(color: color, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Xabar matnini tahrirlash varag'i — "Saqlash" bosilsa yangi matnni
/// `Navigator.pop` orqali qaytaradi.
///
/// Alohida StatefulWidget: `TextEditingController` shu yerda yaratilib
/// `dispose()` da tozalanadi (varaq yopilganda oqib qolmasin).
class _EditMessageSheet extends StatefulWidget {
  const _EditMessageSheet({required this.initialText});

  final String initialText;

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
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
            'voiceChat.editTitle'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
              controller: _ctrl,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              cursorColor: const Color(0xFF216BFF),
              style: const TextStyle(color: Colors.white, fontSize: 15),
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
            onTap: () => Navigator.of(context).pop(_ctrl.text),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF216BFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'voiceChat.editSave'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    required this.isOwn,
    this.onLongPress,
  });

  final VoiceMessage message;
  final bool isOwn;

  /// Uzoq bosilganda — tahrirlash/o'chirish menyusi.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Bola chati bilan bir xil Parvoz tokenlari: own = ko'k, received =
    // `#1C232B`, matn OQ, Poppins shrift, soyasiz. Vaqt+belgi Telegram uslubida
    // matn bilan BIR QATORDA (Wrap — sig'sa yonida, sig'masa pastda o'ngda).
    final metaColor = isOwn ? Colors.white70 : const Color(0x8CFFFFFF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (isOwn) const Spacer(),
          Flexible(
            flex: 5,
            child: GestureDetector(
              // Telegram uslubi: uzoq bosilsa tahrirlash/o'chirish menyusi.
              onLongPress: onLongPress,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
                decoration: BoxDecoration(
                  color: isOwn
                      ? const Color(0xFF216BFF)
                      : const Color(0xFF1C232B),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isOwn ? 18 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 18),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(
                      message.text ?? '',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: _BubbleMeta(
                        message: message,
                        isOwn: isOwn,
                        color: metaColor,
                      ),
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
          style: GoogleFonts.poppins(color: color, fontSize: 11),
        ),
        if (isOwn) ...[
          const SizedBox(width: 3),
          // Bola chatidek: ikki galochka (o'qildi) / bitta (yuborildi), doim
          // oq. Bu belgi faqat O'Z (ko'k) bubble'ida chiqadi.
          Icon(
            message.isSeen ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14,
            color: Colors.white,
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
  const _ImageBubble({
    required this.message,
    required this.isOwn,
    this.onLongPress,
  });

  final VoiceMessage message;
  final bool isOwn;

  /// Uzoq bosilganda — o'chirish menyusi.
  final VoidCallback? onLongPress;

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
        MaterialPageRoute<void>(builder: (_) => _FullScreenImage(url: url)),
      ),
      // Uzoq bosilsa — o'chirish menyusi (matn bubble bilan bir xil).
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300, minHeight: 120),
        // Disk kesh + memCacheWidth bilan cheklangan dekod.
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 720,
          placeholder: (_, __) => Container(
            height: 200,
            color: Colors.black.withValues(alpha: 0.08),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF216BFF),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 160,
            color: Colors.black.withValues(alpha: 0.08),
            child: const Icon(
              SolarIconsBold.galleryRemove,
              color: Color(0x8CFFFFFF),
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
              color: isOwn ? const Color(0xFF216BFF) : const Color(0xFF1C232B),
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
                          // Ko'k bubble ustida OQ matn (matn bubble bilan bir
                          // xil) — qora yashil davridan qolgan edi.
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _BubbleMeta(
                          message: message,
                          isOwn: isOwn,
                          color: isOwn
                              ? Colors.white70
                              : const Color(0x8CFFFFFF),
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
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
              message.isSeen
                  ? SolarIconsBold.checkSquare
                  : SolarIconsBold.checkCircle,
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
          // Disk kesh + memCacheWidth bilan cheklangan dekod.
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            memCacheWidth: 1080,
            errorWidget: (_, __, ___) => const Icon(
              SolarIconsBold.galleryRemove,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
