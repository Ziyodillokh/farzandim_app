// Hujjat (file) bubble — tap qilinganda yuklab olib native ilovada ochadi.
part of 'voice_chat_bubble.dart';

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
      return SolarIconsBold.fileText;
    }
    if (m.startsWith('video/')) return SolarIconsBold.clapperboard;
    if (m.startsWith('audio/')) return SolarIconsBold.musicNote;
    if (m.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) {
      return SolarIconsBold.documentText;
    }
    if (m.contains('sheet') ||
        m.contains('excel') ||
        n.endsWith('.xls') ||
        n.endsWith('.xlsx')) {
      return SolarIconsBold.chartSquare;
    }
    if (m.contains('zip') || m.contains('rar') || m.contains('compressed')) {
      return SolarIconsBold.zipFile;
    }
    return SolarIconsBold.file;
  }

  Future<void> _openFile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(backendVoiceMessageRepositoryProvider);
      final url = repo.mediaUrl(widget.message.mediaKey!);
      final dir = await getTemporaryDirectory();
      final safeName = (widget.message.fileName ?? 'fayl').replaceAll(
        RegExp(r'[^\w\-. ]'),
        '_',
      );
      final savePath = '${dir.path}/${widget.message.id}_$safeName';
      final file = File(savePath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        // Yalang'och Dio() o'rniga umumiy klient — timeout'lar bor,
        // cheksiz osilmaydi; URL absolute bo'lgani uchun baseUrl bezarar.
        await ref.read(dioClientProvider).download(url, savePath);
      }
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        AppToast.error(context, 'voiceChat.fileOpenFailed'.tr());
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'voiceChat.fileOpenFailed'.tr());
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
    final iconBg = isOwn
        ? Colors.black.withValues(alpha: 0.12)
        : AppColors.primary;
    final iconFg = isOwn ? Colors.black : Colors.black;
    final caption = message.text;
    final hasCaption = caption != null && caption.isNotEmpty;

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
                                message.fileName ??
                                    'voiceChat.fileGeneric'.tr(),
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
                                style: TextStyle(color: subColor, fontSize: 12),
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
                        style: TextStyle(color: fg, fontSize: 15, height: 1.35),
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
          if (!isOwn) const Spacer(),
        ],
      ),
    );
  }
}
