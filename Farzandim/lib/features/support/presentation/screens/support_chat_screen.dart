// ─────────────────────────────────────────────────────────────────────
// SupportChatScreen — Qo'llab-quvvatlash chati (Figma 1:1, Sprint 7)
// ─────────────────────────────────────────────────────────────────────
//
// Operator bilan chat: matn + rasm/video/hujjat biriktirmalar. Hozircha
// statik avto-javoblar (keyinroq AI). Brand: Farzandim.

import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/support/data/models/support_message.dart';
import 'package:farzandim/features/support/data/repositories/support_attachment_repository.dart';
import 'package:farzandim/features/support/presentation/providers/support_chat_provider.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
      // SCR-08: builder-list'da maxScrollExtent TAXMINIY — jump'dan keyin
      // itemlar o'lchanib extent o'sishi mumkin (uzun tarixda oxiriga yetib
      // bormasdi). Keyingi frame'da bir marta to'g'rilaymiz.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final newMax = _scrollController.position.maxScrollExtent;
        if ((_scrollController.position.pixels - newMax).abs() > 1) {
          _scrollController.jumpTo(newMax);
        }
      });
    }
  }

  void _sendText() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    ref.read(supportChatProvider.notifier).sendText(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(supportChatProvider);

    // Yangi xabar kelganda pastga scroll.
    ref.listen<List<SupportMessage>>(supportChatProvider, (prev, next) {
      if (prev != null && next.length != prev.length) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(animate: true));
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const _Header(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.md,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final showDate = index == 0 ||
                        !_sameDay(messages[index - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateSeparator(date: msg.createdAt),
                        _MessageRow(message: msg),
                      ],
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _textController,
                hasText: _hasText,
                onSend: _sendText,
                onAttach: _openAttachmentSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Biriktirma tanlash ───

  Future<void> _openAttachmentSheet() async {
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<_AttachKind>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AttachmentSheet(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AttachKind.image:
        await _pickImage();
      case _AttachKind.video:
        await _pickVideo();
      case _AttachKind.document:
        await _pickDocument();
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await ref.read(supportChatProvider.notifier).sendAttachment(
            type: SupportAttachmentType.image,
            fileName: picked.name,
            fileSize: bytes.length,
            filePath: kIsWeb ? null : picked.path,
            bytes: bytes,
          );
    } catch (_) {
      _attachError();
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      final size = await picked.length();
      // Web'da filePath yo'q → upload uchun bytes shart. Mobil'da filePath
      // yetarli (katta videoni xotiraga yuklamaymiz — fromFile stream qiladi).
      final bytes = kIsWeb ? await picked.readAsBytes() : null;
      await ref.read(supportChatProvider.notifier).sendAttachment(
            type: SupportAttachmentType.video,
            fileName: picked.name,
            fileSize: size,
            filePath: kIsWeb ? null : picked.path,
            bytes: bytes,
          );
    } catch (_) {
      _attachError();
    }
  }

  Future<void> _pickDocument() async {
    try {
      // Web'da filePath yo'q → withData: true bilan bytes o'qiymiz. Mobil'da
      // filePath yetarli (xotira tejaladi).
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await ref.read(supportChatProvider.notifier).sendAttachment(
            type: SupportAttachmentType.document,
            fileName: f.name,
            fileSize: f.size,
            filePath: kIsWeb ? null : f.path,
            bytes: kIsWeb ? f.bytes : null,
          );
    } catch (_) {
      _attachError();
    }
  }

  void _attachError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('support.attachError'.tr()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          const _OperatorAvatar(size: 40),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'support.operator'.tr(),
                  style: AppTextStyles.bodyM.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'support.online'.tr(),
                  style: AppTextStyles.label.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),
          _CallButton(),
        ],
      ),
    );
  }
}

class _OperatorAvatar extends StatelessWidget {
  const _OperatorAvatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.favorite_rounded,
        color: AppColors.onPrimary,
        size: size * 0.5,
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('settings.comingSoon'.tr()),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.surfaceVariant,
              ),
            );
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.call_outlined,
              color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

// ════════════════════════ DATE SEPARATOR ════════════════════════

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    String two(int n) => n.toString().padLeft(2, '0');
    final label = isToday
        ? 'support.today'.tr()
        : '${two(date.day)}.${two(date.month)}.${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ════════════════════════ MESSAGE ROW ════════════════════════

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _OperatorAvatar(size: 28),
            const SizedBox(width: AppDimensions.sm),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: _Bubble(message: message),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isImage) return _ImageBubble(message: message);
    if (message.isDocument) return _DocumentBubble(message: message);
    if (message.isVideo) return _VideoBubble(message: message);
    return _TextBubble(message: message);
  }
}

// ─── Matn ───

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bg = isUser ? AppColors.primary : AppColors.surfaceVariant;
    final fg = isUser ? AppColors.onPrimary : AppColors.textPrimary;
    final timeColor = isUser
        ? AppColors.onPrimary.withValues(alpha: 0.6)
        : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _bubbleRadius(isUser),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text ?? '',
            style: AppTextStyles.bodyM.copyWith(color: fg, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            message.timeLabel,
            style: AppTextStyles.label.copyWith(color: timeColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Rasm ───

class _ImageBubble extends ConsumerWidget {
  const _ImageBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = message.bytes;
    // Sessiya: bytes; qayta yuklashdan keyin: backend proxy URL (attachmentKey).
    final url = message.hasRemote
        ? ref
            .read(supportAttachmentRepositoryProvider)
            .urlForKey(message.attachmentKey!)
        : null;
    final hasImage = bytes != null || url != null;
    return GestureDetector(
      onTap: hasImage ? () => _openFullImage(context, bytes, url) : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: _bubbleRadius(message.isUser),
          border: Border.all(color: AppColors.primary, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
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
              Image.network(
                url,
                width: 240,
                fit: BoxFit.cover,
                cacheWidth: 720, // SCR-07
                errorBuilder: (_, __, ___) =>
                    _ImagePlaceholder(name: message.fileName),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: 240,
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.onPrimary,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              )
            else
              _ImagePlaceholder(name: message.fileName),
            Positioned(
              right: 8,
              bottom: 8,
              child: _TimeChip(time: message.timeLabel),
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
                  : Image.network(url!, fit: BoxFit.contain),
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
  const _ImagePlaceholder({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 160,
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.image_rounded,
          color: AppColors.textTertiary, size: 40),
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
        content: Text('support.fileUnavailable'.tr()),
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
  const _VideoBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _openSupportFile(context, ref, message),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: _bubbleRadius(message.isUser),
          border: Border.all(color: AppColors.primary, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.black,
            ),
            const Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 48),
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(
                message.fileName ?? 'video',
                style: AppTextStyles.label.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: _TimeChip(time: message.timeLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hujjat ───

class _DocumentBubble extends ConsumerWidget {
  const _DocumentBubble({required this.message});
  final SupportMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final fg = isUser ? AppColors.onPrimary : AppColors.textPrimary;
    final subColor = isUser
        ? AppColors.onPrimary.withValues(alpha: 0.6)
        : AppColors.textSecondary;
    return GestureDetector(
      onTap: () => _openSupportFile(context, ref, message),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: _bubbleRadius(isUser),
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
              child: Icon(Icons.insert_drive_file_rounded,
                  color: isUser ? AppColors.onPrimary : AppColors.accent,
                  size: 22),
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
                      if (message.fileSizeLabel != null)
                        Text(
                          message.fileSizeLabel!,
                          style: AppTextStyles.label.copyWith(color: subColor),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        message.timeLabel,
                        style:
                            AppTextStyles.label.copyWith(color: subColor),
                      ),
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

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        time,
        style: AppTextStyles.label.copyWith(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

BorderRadius _bubbleRadius(bool isUser) {
  const r = Radius.circular(18);
  const small = Radius.circular(6);
  return BorderRadius.only(
    topLeft: r,
    topRight: r,
    bottomLeft: isUser ? r : small,
    bottomRight: isUser ? small : r,
  );
}

// ════════════════════════ INPUT BAR ════════════════════════

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm + MediaQuery.of(context).viewInsets.bottom * 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Biriktirma tugmasi.
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAttach,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.attach_file_rounded,
                    color: AppColors.textPrimary, size: 22),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Matn maydoni.
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: TextField(
                controller: controller,
                style: AppTextStyles.bodyM,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'support.inputHint'.tr(),
                  hintStyle: AppTextStyles.bodyM
                      .copyWith(color: AppColors.textTertiary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Yuborish tugmasi.
          AnimatedScale(
            scale: hasText ? 1 : 0.85,
            duration: const Duration(milliseconds: 150),
            child: Material(
              color: hasText ? AppColors.primary : AppColors.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: hasText ? onSend : null,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.send_rounded,
                    color: hasText
                        ? AppColors.onPrimary
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ ATTACHMENT SHEET ════════════════════════

enum _AttachKind { image, video, document }

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.md,
          horizontal: AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            _AttachOption(
              icon: Icons.image_rounded,
              label: 'support.attach.image'.tr(),
              color: AppColors.info,
              onTap: () => Navigator.of(context).pop(_AttachKind.image),
            ),
            _AttachOption(
              icon: Icons.videocam_rounded,
              label: 'support.attach.video'.tr(),
              color: AppColors.warning,
              onTap: () => Navigator.of(context).pop(_AttachKind.video),
            ),
            _AttachOption(
              icon: Icons.insert_drive_file_rounded,
              label: 'support.attach.document'.tr(),
              color: AppColors.success,
              onTap: () => Navigator.of(context).pop(_AttachKind.document),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppDimensions.md),
            Text(label, style: AppTextStyles.bodyM),
          ],
        ),
      ),
    );
  }
}
