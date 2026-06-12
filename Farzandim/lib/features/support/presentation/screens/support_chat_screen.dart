// ─────────────────────────────────────────────────────────────────────
// SupportChatScreen — Qo'llab-quvvatlash chati (messenger-style)
// ─────────────────────────────────────────────────────────────────────
//
// Operator bilan chat: matn + rasm/video/hujjat biriktirmalar. Hozircha
// statik avto-javoblar (keyinroq AI). Brand: Farzandim.
//
// Messenger UI: ketma-ket xabarlar guruhlanadi (avatar/dum faqat guruh
// oxirida), yuborilish tick'lari (soat/✓/xato+retry), operator "yozmoqda…"
// indikatori, pastga tushish FAB, pill input (📎 ichkarida).
// CHEGARA: fon rasmi YO'Q; videoxabar/ovozli xabar YO'Q (faqat matn,
// rasm, video, hujjat).

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

/// Ketma-ket xabarlar shu oraliqda bo'lsa bitta guruh hisoblanadi.
const Duration _kGroupWindow = Duration(minutes: 3);

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  bool _showScrollFab = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final away =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final show = away > 300;
    if (show != _showScrollFab) setState(() => _showScrollFab = show);
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        300;
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

  /// Oxirgi ko'rilgan klaviatura inset'i — ochilganda pastga yopishish uchun.
  double _lastBottomInset = 0;

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(supportChatProvider);
    final messages = chat.messages;
    // Typing indikator ro'yxat oxirida qo'shimcha element sifatida.
    final itemCount = messages.length + (chat.operatorTyping ? 1 : 0);

    // Klaviatura ochilganda ro'yxat "pastga yopishadi" (messenger xulqi):
    // viewport qisqarganda foydalanuvchi pastda bo'lgan bo'lsa, oxirgi
    // xabarlar ko'rinishda qoladi. Inset o'zgarishi MediaQuery orqali
    // rebuild'ni o'zi keltiradi.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (bottomInset != _lastBottomInset) {
      final delta = bottomInset - _lastBottomInset;
      _lastBottomInset = bottomInset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        if (delta > 0) {
          final away =
              _scrollController.position.maxScrollExtent -
              _scrollController.position.pixels;
          // Klaviaturadan oldin pastda bo'lgan (away ≤ delta + threshold).
          if (away <= delta + 300) _scrollToBottom(animate: true);
        }
        _onScroll(); // FAB holatini yangilash (pixels o'zgarmagan bo'lsa ham).
      });
    }

    // Yangi xabar/typing — pastga scroll (messenger xulqi: foydalanuvchi
    // tepada o'qiyotgan bo'lsa majburlamaymiz; o'z xabari doim tushiradi).
    ref.listen<SupportChatState>(supportChatProvider, (prev, next) {
      if (prev == null) return;
      final grew = next.messages.length != prev.messages.length;
      final typingChanged = next.operatorTyping != prev.operatorTyping;
      if (!grew && !typingChanged) return;
      final lastIsMine = next.messages.isNotEmpty && next.messages.last.isUser;
      if (_isNearBottom || (grew && lastIsMine)) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animate: true),
        );
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
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.md,
                          AppDimensions.md,
                          AppDimensions.md,
                          AppDimensions.md,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index >= messages.length) {
                            return const _TypingRow();
                          }
                          final msg = messages[index];
                          final prev = index > 0 ? messages[index - 1] : null;
                          final next = index < messages.length - 1
                              ? messages[index + 1]
                              : null;
                          final showDate =
                              prev == null ||
                              !_sameDay(prev.createdAt, msg.createdAt);
                          // Guruhlash: bir xil yuboruvchi + 3 daqiqa ichida +
                          // bitta kun. Avatar/dum faqat guruh OXIRIDA.
                          // `showDate` allaqachon prev==null holatini qamraydi
                          // (yangi kun = yangi guruh).
                          final isFirst =
                              showDate ||
                              prev.sender != msg.sender ||
                              msg.createdAt.difference(prev.createdAt) >
                                  _kGroupWindow;
                          final isLast =
                              next == null ||
                              next.sender != msg.sender ||
                              !_sameDay(next.createdAt, msg.createdAt) ||
                              next.createdAt.difference(msg.createdAt) >
                                  _kGroupWindow;
                          return Column(
                            children: [
                              if (showDate) _DateSeparator(date: msg.createdAt),
                              _MessageRow(
                                message: msg,
                                isFirstInGroup: isFirst,
                                isLastInGroup: isLast,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Pastga tushish FAB — tepaga scroll qilinganda chiqadi.
                    Positioned(
                      right: AppDimensions.md,
                      bottom: AppDimensions.md,
                      child: AnimatedScale(
                        scale: _showScrollFab ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Material(
                          color: AppColors.surface,
                          shape: CircleBorder(
                            side: BorderSide(color: AppColors.border),
                          ),
                          elevation: 4,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _scrollToBottom(animate: true),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
      await ref
          .read(supportChatProvider.notifier)
          .sendAttachment(
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
      await ref
          .read(supportChatProvider.notifier)
          .sendAttachment(
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
      final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await ref
          .read(supportChatProvider.notifier)
          .sendAttachment(
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
          content: Text(
            'support.attachError'.tr(),
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textPrimary),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ════════════════════════ HEADER ════════════════════════

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
          const _OperatorAvatar(size: 42, showOnlineDot: true),
          const SizedBox(width: AppDimensions.sm + 2),
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
                const SizedBox(height: 1),
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

/// Operator avatari — brand gradient doira + support ikona. Header'da
/// online nuqta bilan, bubble yonida nuqtasiz.
class _OperatorAvatar extends StatelessWidget {
  const _OperatorAvatar({required this.size, this.showOnlineDot = false});
  final double size;
  final bool showOnlineDot;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.support_agent_rounded,
        color: AppColors.onPrimary,
        size: size * 0.55,
      ),
    );
    if (!showOnlineDot) return avatar;
    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
          ),
        ),
      ],
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
                content: Text(
                  'settings.comingSoon'.tr(),
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.surfaceVariant,
              ),
            );
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.call_outlined,
            color: AppColors.textPrimary,
            size: 20,
          ),
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
          color: AppColors.surface.withValues(alpha: 0.9),
          border: Border.all(color: AppColors.border),
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

// ════════════════════════ TYPING INDIKATOR ════════════════════════

/// Operator "yozmoqda…" qatori — avatar + 3 nuqtali animatsiyali bubble.
class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _OperatorAvatar(size: 28),
          const SizedBox(width: AppDimensions.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              _dot(i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index) {
    // Har nuqta 0.2 siljish bilan ko'tarilib-tushadi (silliq to'lqin).
    final t = (_controller.value + index * 0.2) % 1.0;
    final wave = (t < 0.5 ? t : 1 - t) * 2; // 0→1→0
    return Transform.translate(
      offset: Offset(0, -3 * wave),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.5 + 0.5 * wave),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

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
              Image.network(
                url,
                width: 240,
                fit: BoxFit.cover,
                cacheWidth: 720, // SCR-07
                errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: 240,
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
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
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Pill maydon: 📎 ichkarida + matn (messenger-style).
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Biriktirma — maydon ichida (Telegram'dagidek).
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: IconButton(
                      onPressed: onAttach,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: AppDimensions.md,
                        top: 13,
                        bottom: 13,
                      ),
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
                          hintStyle: AppTextStyles.bodyM.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          // Yuborish tugmasi — matn borligida brand gradient bilan jonlanadi.
          AnimatedScale(
            scale: hasText ? 1 : 0.9,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: hasText
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, AppColors.primary],
                      )
                    : null,
                color: hasText ? null : AppColors.surface,
                shape: BoxShape.circle,
                border: hasText ? null : Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasText ? onSend : null,
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
