// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'support_chat_screen.dart';

// ════════════════════════ MESSAGE ROW ════════════════════════

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  final SupportMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      // Guruh ichida zich (2), guruhlar orasida kengroq (8).
      padding: EdgeInsets.only(top: isFirstInGroup ? 8 : 2),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // Avatar faqat guruh oxirida; o'rtada joy saqlanadi (hizalama).
            if (isLastInGroup)
              const _OperatorAvatar(size: 28)
            else
              const SizedBox(width: 28),
            const SizedBox(width: AppDimensions.sm),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: _Bubble(
                message: message,
                isFirstInGroup: isFirstInGroup,
                isLastInGroup: isLastInGroup,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  final SupportMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = _groupBubbleRadius(
      isUser: message.isUser,
      isFirst: isFirstInGroup,
      isLast: isLastInGroup,
    );
    final Widget bubble;
    if (message.isImage) {
      bubble = _ImageBubble(message: message, radius: radius);
    } else if (message.isDocument) {
      bubble = _DocumentBubble(message: message, radius: radius);
    } else if (message.isVideo) {
      bubble = _VideoBubble(message: message, radius: radius);
    } else {
      bubble = _TextBubble(message: message, radius: radius);
    }

    // Failed biriktirma: retry qatori (bytes/filePath sessiyada bo'lsa).
    final canRetry =
        message.status == SupportSendStatus.failed &&
        message.hasAttachment &&
        (message.bytes != null || message.filePath != null);
    if (!canRetry) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 2),
        GestureDetector(
          // Opaque + keng padding — qulay teginish maydoni (review: ~16px edi).
          behavior: HitTestBehavior.opaque,
          onTap: () => ref
              .read(supportChatProvider.notifier)
              .retryAttachment(message.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  'support.retry'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Vaqt + yuborilish tick'i (faqat foydalanuvchi xabarida tick).
class _TimeStatus extends StatelessWidget {
  const _TimeStatus({required this.message, required this.color});
  final SupportMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.timeLabel,
          style: AppTextStyles.label.copyWith(color: color, fontSize: 11),
        ),
        if (message.isUser) ...[const SizedBox(width: 3), _statusIcon(color)],
      ],
    );
  }

  Widget _statusIcon(Color color) {
    switch (message.status) {
      case SupportSendStatus.sending:
        return Icon(Icons.schedule_rounded, size: 12, color: color);
      case SupportSendStatus.sent:
        return Icon(Icons.done_all_rounded, size: 14, color: color);
      case SupportSendStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 13,
          color: AppColors.error,
        );
    }
  }
}

// ─── Matn ───

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message, required this.radius});
  final SupportMessage message;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final fg = isUser ? AppColors.onPrimary : AppColors.textPrimary;
    final timeColor = isUser
        ? AppColors.onPrimary.withValues(alpha: 0.65)
        : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 7),
      decoration: BoxDecoration(
        // Foydalanuvchi: brand gradient (premium); operator: surface + border
        // (light mode'da surfaceVariant fonga singib ketardi — review).
        gradient: isUser
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryLight, AppColors.primary],
              )
            : null,
        color: isUser ? null : AppColors.surface,
        border: isUser ? null : Border.all(color: AppColors.border),
        borderRadius: radius,
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(
            message.displayText,
            style: AppTextStyles.bodyM.copyWith(color: fg, height: 1.3),
          ),
          _TimeStatus(message: message, color: timeColor),
        ],
      ),
    );
  }
}

// ─── Rasm ───

class _ImageBubble extends ConsumerWidget {
  const _ImageBubble({required this.message, required this.radius});
  final SupportMessage message;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = message.bytes;
    // Sessiya: bytes; qayta yuklashdan keyin: backend proxy (attachmentKey).
    final url = message.hasRemote
        ? ref
              .read(supportAttachmentRepositoryProvider)
              .urlForKey(message.attachmentKey!)
        : null;
    final hasImage = bytes != null || url != null;
    final sending = message.status == SupportSendStatus.sending;
    return GestureDetector(
      onTap: hasImage && !sending
          ? () => _openFullImage(context, bytes, url)
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                width: 240,
                fit: BoxFit.cover,
                // SCR-07: 240pt bubble uchun to'liq o'lchamda dekod
                // qilinmasin (xotira isrofi).
                cacheWidth: 720,
              )
            else if (url != null)
              // MEM-4: disk kesh + cheklangan dekod (memCacheWidth, SCR-07)
              CachedNetworkImage(
                imageUrl: url,
                width: 240,
                fit: BoxFit.cover,
                memCacheWidth: 720,
                errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                placeholder: (_, __) => SizedBox(
                  width: 240,
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else
              const _ImagePlaceholder(),
            // Yuklanish overlay'i.
            if (sending)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _MediaTimeChip(message: message),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullImage(BuildContext context, Uint8List? bytes, String? url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.contain)
                  // MEM-4: disk kesh + cheklangan dekod (memCacheWidth)
                  : CachedNetworkImage(
                      imageUrl: url!,
                      fit: BoxFit.contain,
                      memCacheWidth: 1080,
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 160,
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.image_rounded, color: AppColors.textTertiary, size: 40),
    );
  }
}

/// Media (rasm/video) ustidagi vaqt + tick chip'i.
class _MediaTimeChip extends StatelessWidget {
  const _MediaTimeChip({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: _TimeStatus(message: message, color: Colors.white),
    );
  }
}

// ─── Biriktirma faylni ochish (video/hujjat uchun umumiy) ───
//
// Sessiya `filePath` → to'g'ridan ochadi. Qayta yuklashdan keyin `filePath`
// yo'q, lekin `attachmentKey` bor → backend proxy'dan vaqtinchalik papkaga
// yuklab olib ochadi (mobil). Web yoki xato bo'lsa — "fayl mavjud emas".
Future<void> _openSupportFile(
  BuildContext context,
  WidgetRef ref,
  SupportMessage message,
) async {
  final path = message.filePath;
  if (path != null) {
    await OpenFilex.open(path);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  void unavailable() => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'support.fileUnavailable'.tr(),
          style: AppTextStyles.bodyS.copyWith(color: AppColors.textPrimary),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceVariant,
      ),
    );
  if (message.hasRemote && !kIsWeb) {
    try {
      final local = await ref
          .read(supportAttachmentRepositoryProvider)
          .downloadToTemp(
            key: message.attachmentKey!,
            fileName: message.fileName ?? 'fayl',
          );
      await OpenFilex.open(local);
      return;
    } catch (_) {
      unavailable();
      return;
    }
  }
  unavailable();
}

// ─── Video ───

class _VideoBubble extends ConsumerWidget {
  const _VideoBubble({required this.message, required this.radius});
  final SupportMessage message;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sending = message.status == SupportSendStatus.sending;
    return GestureDetector(
      onTap: sending ? null : () => _openSupportFile(context, ref, message),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A2E35), Color(0xFF0D1A1F)],
                  ),
                ),
              ),
              if (sending)
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              Positioned(
                left: 8,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        message.fileName ?? 'video',
                        style: AppTextStyles.label.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (message.fileSizeLabel != null)
                      Text(
                        message.fileSizeLabel!,
                        style: AppTextStyles.label.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: _MediaTimeChip(message: message),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hujjat ───

class _DocumentBubble extends ConsumerWidget {
  const _DocumentBubble({required this.message, required this.radius});
  final SupportMessage message;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final sending = message.status == SupportSendStatus.sending;
    final fg = isUser ? AppColors.onPrimary : AppColors.textPrimary;
    final subColor = isUser
        ? AppColors.onPrimary.withValues(alpha: 0.65)
        : AppColors.textSecondary;
    return GestureDetector(
      onTap: sending ? null : () => _openSupportFile(context, ref, message),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primary],
                )
              : null,
          color: isUser ? null : AppColors.surface,
          border: isUser ? null : Border.all(color: AppColors.border),
          borderRadius: radius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.onPrimary.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: isUser ? AppColors.onPrimary : AppColors.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      Icons.insert_drive_file_rounded,
                      color: isUser ? AppColors.onPrimary : AppColors.accent,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.fileName ?? 'document',
                    style: AppTextStyles.bodyS.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.fileSizeLabel != null) ...[
                        Text(
                          message.fileSizeLabel!,
                          style: AppTextStyles.label.copyWith(color: subColor),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _TimeStatus(message: message, color: subColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Telegram uslubidagi guruh radiusi: yuboruvchi tomonidagi burchaklar guruh
/// ichida kichik (6), guruh boshida tepa katta, oxirida past "dum" (4).
BorderRadius _groupBubbleRadius({
  required bool isUser,
  required bool isFirst,
  required bool isLast,
}) {
  const big = Radius.circular(18);
  const mid = Radius.circular(6);
  const tail = Radius.circular(4);
  if (isUser) {
    return BorderRadius.only(
      topLeft: big,
      bottomLeft: big,
      topRight: isFirst ? big : mid,
      bottomRight: isLast ? tail : mid,
    );
  }
  return BorderRadius.only(
    topRight: big,
    bottomRight: big,
    topLeft: isFirst ? big : mid,
    bottomLeft: isLast ? tail : mid,
  );
}
