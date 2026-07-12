// ─────────────────────────────────────────────────────────────────────
// LikedQuestionsScreen — "Tanlangan savollar" (quiz ♡ bilan saqlangan)
// ─────────────────────────────────────────────────────────────────────
//
// Raqamli, scroll qilinadigan ro'yxat — eng oxirgi tanlangan birinchi
// (newest-first). Oldingi/Keyingi tugmasi YO'Q. Har savolni ♥ bosib olib
// tashlash mumkin.

import 'package:farzandim_child/features/contests/presentation/providers/favorite_questions_provider.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:farzandim_child/shared/widgets/math_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _red = Color(0xFFFF5A6E);

class LikedQuestionsScreen extends ConsumerWidget {
  const LikedQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(favoriteQuestionsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: tBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tGlass,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tanlangan savollar',
                        maxLines: 1,
                        style: tUnb(22, w: FontWeight.w700, ls: -0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: questions.isEmpty
                  ? _empty()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 6, 16, 24 + bottomInset),
                      itemCount: questions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _QuestionRow(
                        number: i + 1,
                        text: questions[i].text,
                        onUnfav: () async {
                          await ref
                              .read(favoriteQuestionsProvider.notifier)
                              .toggle(questions[i].id, questions[i].text);
                          await HapticFeedback.selectionClick();
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tGlass,
              border: Border.all(color: tGlassBorder),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 38,
              color: tBlue.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Hali tanlangan savol yo'q",
            textAlign: TextAlign.center,
            style: tUnb(17, w: FontWeight.w600, ls: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Test yechayotib ♥ bosib savolni saqlang',
            textAlign: TextAlign.center,
            style: tPop(13, c: tMuted),
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.number,
    required this.text,
    required this.onUnfav,
  });

  final int number;
  final String text;
  final VoidCallback onUnfav;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tGlassBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: tPop(12.5, w: FontWeight.w600, c: tMuted),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: tBlue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.question_mark_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MathText(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tPop(14.5, w: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUnfav,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.favorite_rounded, size: 24, color: _red),
            ),
          ),
        ],
      ),
    );
  }
}
