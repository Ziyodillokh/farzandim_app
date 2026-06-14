// ─────────────────────────────────────────────────────────────────────
// AiChatScreen — Faro bilan suhbat (#64/#65)
// ─────────────────────────────────────────────────────────────────────
//
// Faro mimikalari: yozmoqda → faceIdle, javob → faceExcited, flagged → faceSad.
// Yuqorida ota-ona suhbatni ko'ra olishi haqida shaffof eslatma (#70).

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/ai_companion/data/ai_message.dart';
import 'package:farzandim_child/features/ai_companion/presentation/ai_chat_provider.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  FaroVariant _faroFor(AiChatState s) {
    if (s.sending) return FaroVariant.faceIdle;
    final last = s.messages.isNotEmpty ? s.messages.last : null;
    if (last != null && !last.isUser) {
      return last.flagged ? FaroVariant.faceSad : FaroVariant.faceExcited;
    }
    return FaroVariant.faceIdle;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    ref.listen(aiChatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: FaroMascot(variant: _faroFor(state), size: 36),
            ),
            const SizedBox(width: 10),
            const Text(
              'Faro',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // #70 — shaffof eslatma: ota-ona suhbatni ko'ra oladi.
          Container(
            width: double.infinity,
            color: AppColors.primary.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ota-onang bu suhbatni ko\'ra oladi. Bu xavfsiz makon 💚',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.messages.isEmpty && state.loaded
                ? const _Greeting()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: state.messages.length + (state.sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= state.messages.length) {
                        return const _TypingBubble();
                      }
                      return _Bubble(message: state.messages[i]);
                    },
                  ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                state.error!,
                style: TextStyle(color: AppColors.error, fontSize: 12.5),
              ),
            ),
          _Composer(
            controller: _controller,
            sending: state.sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 140,
              height: 140,
              child: FaroMascot(variant: FaroVariant.faceExcited, size: 140),
            ),
            const SizedBox(height: 16),
            const Text(
              'Salom! Men Faro 🦊',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Men sening do\'st AI hamrohingman. Dars, kosmos, hayvonlar '
              '— xohlagan narsang haqida so\'ra!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bg = isUser
        ? AppColors.primary
        : (message.flagged
            ? AppColors.warning.withValues(alpha: 0.15)
            : AppColors.surface);
    final fg = isUser ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: message.flagged
              ? Border.all(color: AppColors.warning.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.flagged && !isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 13, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Xavfsizlik',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(color: fg, fontSize: 15, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Faro yozmoqda…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Faro\'ga yoz…',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    sending ? Icons.hourglass_empty_rounded : Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
