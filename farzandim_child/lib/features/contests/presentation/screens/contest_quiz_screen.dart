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

import 'package:confetti/confetti.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/models/quiz_state.dart';
import 'package:farzandim_child/features/contests/data/repositories/certificate_repository.dart';
import 'package:farzandim_child/features/contests/data/sound_service.dart';
import 'package:farzandim_child/features/contests/presentation/contests_theme.dart';
import 'package:farzandim_child/features/contests/presentation/providers/favorite_questions_provider.dart';
import 'package:farzandim_child/features/contests/presentation/providers/quiz_provider.dart';
import 'package:farzandim_child/features/contests/presentation/widgets/test_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
            'Savollar tayyorlanmoqda...',
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
                        child: Text(
                          q.text,
                          style: tPop(16, w: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                      label: 'Oldingi',
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
                      label: state.isLastQuestion ? 'Yakunlash' : 'Keyingi',
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
                Text('Test qoidalari', style: tUnb(18, w: FontWeight.w700)),
                const SizedBox(height: 18),
                const _MenuRow(
                  icon: Icons.touch_app_rounded,
                  text: "Javobni tanlang — to'g'ri yashil, xato qizil bo'ladi",
                ),
                const _MenuRow(
                  icon: Icons.swap_horiz_rounded,
                  text:
                      'Oldingi / Keyingi bilan savollar orasida harakatlaning',
                ),
                const _MenuRow(
                  icon: Icons.access_time_rounded,
                  text: 'Umumiy vaqt tugasa test avtomatik yakunlanadi',
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
                            'Tanlangan savollar',
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
                      'Testdan chiqish',
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
                      'Davom etish',
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
  });

  final String text;

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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 58,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: mark != null ? 1.6 : 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tPop(15.5, w: FontWeight.w600, c: txt),
                ),
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
    final p = CP(true);
    final isWinner = state.isWinner;
    final total = state.effectiveQuestions.length;
    final percent = (state.accuracy * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              gradient: isWinner
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3C82FF), tBlue],
                    )
                  : null,
              color: isWinner ? null : p.warn.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: isWinner
                  ? null
                  : Border.all(
                      color: p.warn.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
              boxShadow: [
                BoxShadow(
                  color: (isWinner ? tBlue : p.warn).withValues(alpha: 0.34),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isWinner ? AppIcons.trophy : Icons.psychology_rounded,
              color: isWinner ? Colors.white : p.warn,
              size: 62,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isWinner ? 'Tabriklaymiz!' : 'Yaxshi urinish!',
            style: tUnb(30, w: FontWeight.w700, ls: -0.6),
          ),
          const SizedBox(height: 8),
          Text(
            isWinner
                ? 'Testni muvaffaqiyatli yakunladingiz'
                : "Keyingi safar yanada yaxshi natija ko'rsatasiz",
            textAlign: TextAlign.center,
            style: tPop(14, c: tMuted),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tGlass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tGlassBorder),
            ),
            child: Column(
              children: [
                _ResultStat(
                  label: "To'g'ri javoblar",
                  value: '${state.correctCount}/$total',
                  color: _green,
                ),
                const _ResultDivider(),
                _ResultStat(
                  label: 'Yiqqan ball',
                  value: '${state.totalScore}',
                  color: tBlue,
                ),
                const _ResultDivider(),
                _ResultStat(
                  label: 'Aniqlik',
                  value: '$percent%',
                  color: AppColors.catLavenderDark,
                ),
                const _ResultDivider(),
                _ResultStat(
                  label: 'Maksimal streak',
                  value: '${state.maxStreak}',
                  color: AppColors.catOrangeLight,
                ),
                const _ResultDivider(),
                _ResultStat(
                  label: 'Vaqt',
                  value: _formatElapsed(state.totalElapsed),
                  color: AppColors.catPinkRose,
                ),
              ],
            ),
          ),
          const Spacer(),
          if (isWinner && state.attemptId != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openCertificate(context, ref),
                icon: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                label: Text('Sertifikat', style: tPop(15, w: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _onShare(context),
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text('Ulashish', style: tPop(14, w: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    side: const BorderSide(color: tGlassBorder),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.go('/contests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text('Yopish', style: tPop(15, w: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _onShare(BuildContext context) async {
    final total = state.effectiveQuestions.length;
    final text =
        "Men Parvoz ilovasida '${contest.title}' testida "
        "${state.correctCount}/$total to'g'ri javob berdim! 🏆\n"
        'Yiqqan ball: ${state.totalScore}\n\n'
        'Sen ham qatnash!';
    await Share.share(text);
  }

  Future<void> _openCertificate(BuildContext context, WidgetRef ref) async {
    final attemptId = state.attemptId;
    if (attemptId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final data = await ref.read(certificateRepositoryProvider).fetch(attemptId);
    if (!context.mounted) return;
    if (data == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sertifikat hozircha mavjud emas.')),
      );
      return;
    }
    if (context.mounted) {
      context.push('/certificate', extra: data);
    }
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ResultDivider extends StatelessWidget {
  const _ResultDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: tGlassBorder, height: 24, thickness: 1);
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(label, style: tPop(14, c: tMuted)),
        ),
        Text(value, style: tUnb(15, w: FontWeight.w700, ls: -0.3)),
      ],
    );
  }
}
