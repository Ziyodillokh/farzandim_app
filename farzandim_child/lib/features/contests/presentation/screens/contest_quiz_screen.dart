// ─────────────────────────────────────────────────────────────────────
// ContestQuizScreen — test ichi (Parvoz dark redizayn, Figma "test ichi")
// ─────────────────────────────────────────────────────────────────────
//
// Status'ga qarab:
//   loading/intro → _LoadingScreen (intro yo'q — "Konkurs shartlari" sheet'dan
//                   keyin auto-start)
//   playing/paused → _QuestionScreen (header fan + ? / N/total + umumiy vaqt /
//                    rangli natija nuqtalari / shisha savol / shisha javoblar /
//                    Oldingi · ♡ · Keyingi)
//   finished → _ResultScreen
//
// Backend integratsiyasi saqlangan (per-savol validatsiya, XP, sertifikat).
// Navigatsiya MANUAL (Oldingi/Keyingi), timer UMUMIY (quiz byudjeti).

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/quiz_state.dart';
import 'package:farzandim_child/features/contests/data/sound_service.dart';
import 'package:farzandim_child/features/contests/presentation/providers/favorite_questions_provider.dart';
import 'package:farzandim_child/features/contests/presentation/providers/quiz_provider.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:farzandim_child/shared/widgets/math_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _green = Color(0xFF41DD7A);
const _red = Color(0xFFFF5A6E);

String _fmtTime(int sec) {
  final s = sec < 0 ? 0 : sec;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class ContestQuizScreen extends ConsumerStatefulWidget {
  const ContestQuizScreen({required this.contest, super.key});

  final ContestModel contest;

  @override
  ConsumerState<ContestQuizScreen> createState() => _ContestQuizScreenState();
}

class _ContestQuizScreenState extends ConsumerState<ContestQuizScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizProvider(widget.contest));

    ref.listen<QuizState>(quizProvider(widget.contest), (prev, next) {
      // Faqat YANGI javob berilganda tovush/haptika (Oldingi/Keyingi bilan
      // review qilinganda EMAS): bir xil savol + none → javob.
      final fresh =
          prev?.currentIndex == next.currentIndex &&
          prev?.answerState == AnswerState.none &&
          next.answerState != AnswerState.none;
      if (fresh) {
        if (next.answerState == AnswerState.correct) {
          HapticFeedback.lightImpact();
          SoundService.playCorrect();
          if (next.currentStreak >= 3 && next.currentStreak % 3 == 0) {
            _confettiController.play();
          }
        } else if (next.answerState == AnswerState.wrong) {
          HapticFeedback.heavyImpact();
          SoundService.playWrong();
        }
      }
      if (prev?.status != next.status &&
          next.status == QuizStatus.finished &&
          next.isWinner) {
        _confettiController.play();
        SoundService.playVictory();
      }
    });

    return Scaffold(
      backgroundColor: tBg,
      body: Stack(
        children: [
          SafeArea(child: _buildContent(state)),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [
                AppColors.parvozGreen,
                AppColors.catPinkRose,
                AppColors.catLavenderDark,
                AppColors.catOrangeWarm,
                AppColors.catMint,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(QuizState state) {
    switch (state.status) {
      case QuizStatus.loading:
      case QuizStatus.intro:
        // Intro yo'q — "Konkurs shartlari" sheet'dan keyin auto-start.
        return _LoadingScreen(contest: widget.contest);
      case QuizStatus.playing:
      case QuizStatus.paused:
        return _QuestionScreen(contest: widget.contest, state: state);
      case QuizStatus.finished:
        return _ResultScreen(contest: widget.contest, state: state);
    }
  }
}

// ─── Loading ────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.contest});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    final col = contest.placeholderColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: col.withValues(alpha: 0.4), width: 1.4),
            ),
            alignment: Alignment.center,
            child: Icon(contest.placeholderIcon, color: col, size: 52),
          ),
          const SizedBox(height: 34),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: tBlue),
          ),
          const SizedBox(height: 20),
          Text(
            'contests.preparingQuestions'.tr(),
            style: tPop(14, w: FontWeight.w500, c: tMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Question (Parvoz — Figma "test ichi") ──────────────────────────

class _QuestionScreen extends ConsumerWidget {
  const _QuestionScreen({required this.contest, required this.state});

  final ContestModel contest;
  final QuizState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = state.currentQuestion;
    final total = state.effectiveQuestions.length;
    final answered = state.answerState != AnswerState.none;
    final isFav = ref.watch(favoriteQuestionsProvider).any((f) => f.id == q.id);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final notifier = ref.read(quizProvider(contest).notifier);
    final low = state.timeRemaining <= 30;
    // Ochilgan to'g'ri javob indeksi (noto'g'ri belgilanganda yashil ko'rsatish).
    final revealed = state.currentIndex < state.correctIndices.length
        ? state.correctIndices[state.currentIndex]
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showMenu(context, ref);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            // Header: fan nomi + "?"
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        contest.title,
                        maxLines: 1,
                        style: tUnb(24, w: FontWeight.w700, ls: -0.6),
                      ),
                    ),
                  ),
                ),
                _RoundIconBtn(
                  icon: Icons.question_mark_rounded,
                  onTap: () => _showMenu(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // "N / total" + umumiy vaqt
            Row(
              children: [
                Text(
                  '${state.currentIndex + 1} / $total',
                  style: tPop(14, w: FontWeight.w600, c: tDim),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: low ? _red : tDim,
                ),
                const SizedBox(width: 6),
                Text(
                  _fmtTime(state.timeRemaining),
                  style: tPop(
                    14,
                    w: FontWeight.w600,
                    c: low ? _red : Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressDots(
              results: state.results,
              total: total,
              current: state.currentIndex,
            ),
            const SizedBox(height: 22),
            // Savol kartasi (shisha) + ko'k "?" doira. Uzun savolda overflow
            // bo'lmasin — balandligi cheklangan + ichida scroll.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.28,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tGlassBorder),
                ),
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: MathText(
                          q.text,
                          style: tPop(16, w: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Savol rasmi (ixtiyoriy) — admin savolga rasm yuklagan bo'lsa.
            // Matematik funksiya kabi yozib bo'lmaydigan savollar uchun.
            if (q.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: q.imageUrl,
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.17,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(
                    height: MediaQuery.sizeOf(context).height * 0.17,
                    decoration: BoxDecoration(
                      color: tGlass,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: tBlue,
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 18),
            // Javoblar (shisha secondary)
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: q.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final isSelected = state.selectedAnswer == i;
                  // To'g'ri variant yashil: backend/mock ochgan indeks, yoki
                  // reveal yo'q bo'lsa foydalanuvchi to'g'ri belgilagani.
                  final showCorrect =
                      answered &&
                      ((revealed != null && i == revealed) ||
                          (revealed == null &&
                              isSelected &&
                              state.answerState == AnswerState.correct));
                  // Foydalanuvchining NOTO'G'RI tanlovi qizil.
                  final showWrong = answered && isSelected && !showCorrect;
                  return _QuizOption(
                    text: q.options[i],
                    imageUrl: q.optionImageAt(i),
                    showCorrect: showCorrect,
                    showWrong: showWrong,
                    onTap: answered ? null : () => notifier.selectAnswer(i),
                  );
                },
              ),
            ),
            // Oldingi · ♡ · Keyingi
            Padding(
              padding: EdgeInsets.only(top: 8, bottom: 12 + bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: _NavPill(
                      label: 'contests.previous'.tr(),
                      icon: Icons.chevron_left_rounded,
                      leading: true,
                      enabled: state.currentIndex > 0,
                      onTap: notifier.goPrevious,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _QuizHeart(
                    active: isFav,
                    onTap: () async {
                      await ref
                          .read(favoriteQuestionsProvider.notifier)
                          .toggle(q.id, q.text);
                      await HapticFeedback.selectionClick();
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NavPill(
                      label: state.isLastQuestion
                          ? 'contests.finish'.tr()
                          : 'contests.next'.tr(),
                      icon: Icons.chevron_right_rounded,
                      leading: false,
                      enabled: true,
                      primary: state.isLastQuestion,
                      onTap: notifier.goNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "?" tugma / orqaga bosish — qoidalar + chiqish sheet'i. Ochilganda pause,
  // yopilganda (chiqmasa) resume.
  void _showMenu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(quizProvider(contest).notifier);
    notifier.pause();
    var exiting = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1119),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: tGlassBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tGlassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'contests.rulesTitle'.tr(),
                  style: tUnb(18, w: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                _MenuRow(
                  icon: Icons.touch_app_rounded,
                  text: 'contests.rule1'.tr(),
                ),
                _MenuRow(
                  icon: Icons.swap_horiz_rounded,
                  text: 'contests.rule2'.tr(),
                ),
                _MenuRow(
                  icon: Icons.access_time_rounded,
                  text: 'contests.rule3'.tr(),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/liked-questions');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: tGlass,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tGlassBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 20,
                          color: _red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'contests.selectedQuestions'.tr(),
                            style: tPop(15, w: FontWeight.w600),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    exiting = true;
                    notifier.quit();
                    Navigator.pop(ctx);
                    if (context.mounted) context.go('/contests');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _red.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'contests.exitTest'.tr(),
                      style: tPop(15, w: FontWeight.w600, c: _red),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'contests.continueTest'.tr(),
                      style: tPop(15, w: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      if (!exiting && context.mounted) notifier.resume();
    });
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(color: tGlass, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: tBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: tPop(13.5, c: tDim)),
          ),
        ],
      ),
    );
  }
}

/// Rangli natija nuqtalari — to'g'ri (yashil) / xato (qizil) / joriy (ko'k) /
/// kelgusi (kulrang).
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.results,
    required this.total,
    required this.current,
  });

  final List<AnswerState> results;
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    Color colorFor(int i) {
      final r = i < results.length ? results[i] : AnswerState.none;
      if (r == AnswerState.correct) return _green;
      if (r == AnswerState.wrong || r == AnswerState.timeout) return _red;
      if (i == current) return tBlue;
      return Colors.white.withValues(alpha: 0.16);
    }

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: i == current ? 9 : 7,
            height: i == current ? 9 : 7,
            decoration: BoxDecoration(
              color: colorFor(i),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// Shisha "secondary" javob tugmasi. Javob berilgach tanlangani yashil
/// (to'g'ri) yoki qizil (xato) bo'ladi.
class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.text,
    required this.showCorrect,
    required this.showWrong,
    required this.onTap,
    this.imageUrl = '',
  });

  final String text;

  /// Variant rasmi (ixtiyoriy) — matematik formula/diagramma javoblar uchun.
  final String imageUrl;

  /// To'g'ri javob — yashil + ✓ (belgilangan yoki ochilgan to'g'ri variant).
  final bool showCorrect;

  /// Foydalanuvchining noto'g'ri tanlovi — qizil + ✗.
  final bool showWrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    var bg = tGlass;
    var border = tGlassBorder;
    var txt = Colors.white;
    IconData? mark;

    if (showCorrect) {
      bg = _green.withValues(alpha: 0.16);
      border = _green;
      txt = _green;
      mark = Icons.check_rounded;
    } else if (showWrong) {
      bg = _red.withValues(alpha: 0.16);
      border = _red;
      txt = _red;
      mark = Icons.close_rounded;
    }

    final hasImage = imageUrl.isNotEmpty;
    final hasText = text.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        // Moslashuvchan balandlik — rasm yoki uzun matn sig'sin (avval 58 qat'iy).
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: mark != null ? 1.6 : 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hasImage ? 12 : 44, 12, 44, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const SizedBox(
                            height: 60,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: tBlue,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (hasText) const SizedBox(height: 8),
                  ],
                  if (hasText)
                    MathText(
                      text,
                      // Rasm bilan qisqa; faqat matn bo'lsa uzun javoblar 5 satr.
                      maxLines: hasImage ? 2 : 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tPop(15.5, w: FontWeight.w600, c: txt),
                    ),
                ],
              ),
            ),
            if (mark != null)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(child: Icon(mark, size: 22, color: txt)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Oldingi / Keyingi shisha pill (o'chirilgan bo'lsa xira).
class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.label,
    required this.icon,
    required this.leading,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool leading;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconW = Icon(
      icon,
      size: 22,
      color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
    );
    final textW = Text(
      label,
      style: tPop(
        15,
        w: FontWeight.w600,
        c: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? tBlue : tGlass,
            borderRadius: BorderRadius.circular(999),
            border: primary ? null : Border.all(color: tGlassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: leading
                ? [iconW, const SizedBox(width: 4), textW]
                : [textW, const SizedBox(width: 4), iconW],
          ),
        ),
      ),
    );
  }
}

/// Sevimli (♡) — testni yoqtirilganlarga qo'shadi/oladi.
class _QuizHeart extends StatelessWidget {
  const _QuizHeart({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active ? _red.withValues(alpha: 0.16) : tGlass,
          shape: BoxShape.circle,
          border: Border.all(color: active ? _red : tGlassBorder),
        ),
        alignment: Alignment.center,
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 24,
          color: active ? _red : Colors.white,
        ),
      ),
    );
  }
}

// ─── Result ─────────────────────────────────────────────────────────

class _ResultScreen extends ConsumerWidget {
  const _ResultScreen({required this.contest, required this.state});

  final ContestModel contest;
  final QuizState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.effectiveQuestions.length;
    final correct = state.correctCount;
    final record = (state.recordCorrect ?? correct).clamp(0, total);
    final stars = _starsFor(state.accuracy);
    // Backend bilan AYNAN bir xil formula — ekrandagi son bola balansiga
    // tushadigan son bilan mos bo'lishi shart. Avval `isWinner ? bonus : 0`
    // edi (80% dan to'liq fond), backend esa 30% dan proporsional beradi →
    // 40% topgan bola ekranda "0 DON" ko'rib, balansiga 8 DON tushardi.
    final yutuq = rewardFor(
      pool: contest.bonus,
      correct: correct,
      total: total,
    );
    final cardW = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 380.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Container(
          width: cardW,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F23),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF313639)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StarsRow(stars: stars),
              const SizedBox(height: 22),
              Text('contests.result'.tr(), style: tPop(14, c: Colors.white)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1487FA),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.black),
                ),
                child: Text(
                  '$correct / $total',
                  style: tUnb(16, w: FontWeight.w600, ls: -0.48),
                ),
              ),
              const SizedBox(height: 18),
              const _CardDivider(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatColumn(
                      label: 'contests.record'.tr(),
                      value: Text(
                        '$record / $total ta',
                        style: tUnb(16, w: FontWeight.w600, ls: -0.48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatColumn(
                      label: 'contests.reward'.tr(),
                      value: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$yutuq',
                            style: tUnb(16, w: FontWeight.w600, ls: -0.48),
                          ),
                          const SizedBox(width: 6),
                          const DonBadge(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _CardDivider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryGlassButton(
                      label: 'contests.toHome'.tr(),
                      onTap: () => context.go('/dashboard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PremiumBlueButton(
                      label: 'contests.rematch'.tr(),
                      // Qayta yechish — quiz notifier'ini yangilaymiz (backend
                      // tugagan urinishni reset qilib qaytadan boshlaydi).
                      onTap: () => ref.invalidate(quizProvider(contest)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aniqlikdan yulduz soni (0–3).
int _starsFor(double accuracy) {
  if (accuracy >= 0.9) return 3;
  if (accuracy >= 0.7) return 2;
  if (accuracy >= 0.5) return 1;
  return 0;
}

/// 3 yulduz (o'rtadagi katta) + amber yog'du. Yiqqan yulduzlar to'ldirilgan
/// (o'rta → chap → o'ng tartibida).
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    Widget star(bool filled, double size) => Icon(
      filled ? Icons.star_rounded : Icons.star_border_rounded,
      size: size,
      color: const Color(0xFFFFC400),
    );

    return SizedBox(
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 6,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                width: 180,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAE00).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              star(stars >= 2, 46),
              const SizedBox(width: 12),
              star(stars >= 1, 70),
              const SizedBox(width: 12),
              star(stars >= 3, 46),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rekord/Yutuq ustuni — markazlashgan yorliq + qiymat.
class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: tPop(14, c: Colors.white)),
        const SizedBox(height: 6),
        value,
      ],
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFF313639));
  }
}

/// "Asosiyga" — ota-ona onboarding SECONDARY shisha (oq gradient + rim + soya).
class _SecondaryGlassButton extends StatelessWidget {
  const _SecondaryGlassButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.white.withValues(alpha: 0.11),
              Colors.white.withValues(alpha: 0.025),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(label, style: tPop(16, w: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// "Revansh" — ota-ona onboarding PREMIUM ko'k shisha (ko'k gradient + rim +
/// ko'k yog'du soya).
class _PremiumBlueButton extends StatelessWidget {
  const _PremiumBlueButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3C82FF), tBlue],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: tBlue.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: tPop(16, w: FontWeight.w500)),
            const SizedBox(width: 6),
            const Icon(Icons.refresh_rounded, size: 22, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
