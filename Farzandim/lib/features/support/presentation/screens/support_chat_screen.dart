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

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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

part 'support_chat_widgets.dart';
part 'support_chat_bubbles.dart';
part 'support_chat_input.dart';

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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    // Operator (Telegram'dan) javobini olish — ekran ochiqligida 10s polling.
    // Ochilishda darhol ham sinxronlaymiz (oxirgi javoblar ko'rinsin).
    Future.microtask(
      () => ref.read(supportChatProvider.notifier).syncFromServer(),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        ref.read(supportChatProvider.notifier).syncFromServer();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
      // `withData: true` — hujjatni doim BYTES bilan o'qiymiz (web + mobil).
      // Android'da FilePicker `path` (content/cache URI) `fromFile` bilan
      // o'qilmasligi mumkin edi → upload jim fail bo'lib FAYL guruhga yetmasdi.
      // Bytes (fromBytes) rasm kabi ishonchli. filePath mobil'da foydalanuvchi
      // o'z faylini ochishi uchun saqlanadi.
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      await ref
          .read(supportChatProvider.notifier)
          .sendAttachment(
            type: SupportAttachmentType.document,
            fileName: f.name,
            fileSize: f.size,
            filePath: kIsWeb ? null : f.path,
            bytes: f.bytes,
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
