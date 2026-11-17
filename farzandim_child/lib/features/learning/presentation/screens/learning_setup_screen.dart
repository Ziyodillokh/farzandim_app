// ─────────────────────────────────────────────────────────────────────
// LearningSetupScreen — sinf va fanlar tanlash
// ─────────────────────────────────────────────────────────────────────
//
// Ikki rejim:
//   • onboarding (`/onboarding`, pair'dan keyin bir marta): Sinf → Fanlar →
//     Qiziqishlar (ixtiyoriy) → ruxsatlar sahifasi. Qiziqishlar avvalgidek
//     backend'ga yuboriladi (InterestsSyncService).
//   • tahrirlash (`/learn/setup`, Profil "Fanlarim" / bosh sahifa): Sinf →
//     Fanlar → saqlash va orqaga.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/learning_stats.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_pickers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:farzandim_child/features/onboarding/data/interests_sync_service.dart';
import 'package:farzandim_child/features/onboarding/data/onboarding_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Step { grade, subjects, interests }

class LearningSetupScreen extends ConsumerStatefulWidget {
  const LearningSetupScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<LearningSetupScreen> createState() =>
      _LearningSetupScreenState();
}

class _LearningSetupScreenState extends ConsumerState<LearningSetupScreen> {
  late final List<_Step> _steps = widget.isOnboarding
      ? _Step.values
      : const [_Step.grade, _Step.subjects];
  int _index = 0;
  int? _grade;
  List<Subject> _subjects = const [];
  Set<String> _interests = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Tahrirlash — joriy profildan boshlanadi.
    final current = ref.read(learningProfileProvider);
    if (!widget.isOnboarding && current != null) {
      _grade = current.grade;
      _subjects = current.subjects;
    }
  }

  _Step get _step => _steps[_index];
  bool get _isLast => _index == _steps.length - 1;

  bool get _canContinue => switch (_step) {
    _Step.grade => _grade != null,
    _Step.subjects => _subjects.length >= kMinSubjects,
    _Step.interests => true,
  };

  void _setGrade(int grade) {
    HapticFeedback.selectionClick();
    setState(() {
      _grade = grade;
      // Bu sinfda o'qitilmaydigan fanlar olib tashlanadi.
      _subjects = List.unmodifiable(
        _subjects.where((s) => s.isTaughtIn(grade)),
      );
    });
  }

  void _toggleSubject(Subject subject) {
    if (_subjects.contains(subject)) {
      HapticFeedback.selectionClick();
      setState(
        () =>
            _subjects = List.unmodifiable(_subjects.where((s) => s != subject)),
      );
      return;
    }
    if (_subjects.length >= kMaxSubjects) {
      HapticFeedback.heavyImpact();
      _snack('learn.maxReached'.tr(namedArgs: {'max': '$kMaxSubjects'}));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _subjects = List.unmodifiable([..._subjects, subject]));
  }

  void _toggleInterest(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _interests = _interests.contains(id)
          ? (_interests.difference({id}))
          : {..._interests, id};
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      return;
    }
    if (context.canPop()) context.pop();
  }

  Future<void> _continue() async {
    if (!_canContinue || _busy) return;
    if (!_isLast) {
      HapticFeedback.selectionClick();
      setState(() => _index++);
      return;
    }
    await _finish();
  }

  Future<void> _finish({bool skipInterests = false}) async {
    final grade = _grade;
    if (grade == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(savedLearningProfileProvider.notifier)
          .save(LearningProfile(grade: grade, subjects: _subjects));
      if (widget.isOnboarding) await _completeOnboarding(skipInterests);
    } catch (e) {
      debugPrint('[learning] profil saqlanmadi: $e');
      if (mounted) {
        setState(() => _busy = false);
        _snack('learn.saveFailed'.tr());
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (widget.isOnboarding) {
      // Onboarding'dan keyin ruxsatlar sahifasi (avvalgi oqim).
      context.go('/permission-setup');
    } else {
      _snack('learn.saved'.tr());
      context.canPop() ? context.pop() : context.go('/profile');
    }
  }

  Future<void> _completeOnboarding(bool skipInterests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenKey, true);
    if (skipInterests || _interests.isEmpty) return;
    await prefs.setStringList(kPendingInterestsKey, _interests.toList());
    // Xato bo'lsa pending qoladi — keyingi ishga tushishda qayta urinadi.
    await ref.read(interestsSyncServiceProvider).syncPendingInterests();
  }

  @override
  Widget build(BuildContext context) {
    final showBack = _index > 0 || (!widget.isOnboarding && context.canPop());
    return PopScope(
      canPop: _index == 0 && !widget.isOnboarding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0) _back();
      },
      child: Scaffold(
        backgroundColor: HomeColors.bg,
        body: DesignScale(
          child: Builder(
            builder: (context) {
              final insets = MediaQuery.paddingOf(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: growthTopInset(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        if (showBack) ...[
                          HeaderIconButton(
                            semanticLabel: 'common.back'.tr(),
                            onTap: _back,
                            child: const HomeSvgIcon(homeBackSvg, size: 20),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: SetupSteps(step: _index, total: _steps.length),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'learn.stepOf'.tr(
                            namedArgs: {
                              'step': '${_index + 1}',
                              'total': '${_steps.length}',
                            },
                          ),
                          style: homeText(13, color: HomeColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: ListView(
                        key: ValueKey(_step),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                        children: _stepContent(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, insets.bottom + 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SetupButton(
                          label: _buttonLabel(),
                          busy: _busy,
                          onTap: _canContinue ? _continue : null,
                        ),
                        if (_step == _Step.interests)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _finish(skipInterests: true),
                            child: Text(
                              'learn.skip'.tr(),
                              style: homeText(
                                14,
                                weight: FontWeight.w600,
                                color: HomeColors.textDim,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _buttonLabel() {
    if (!_isLast) return 'learn.next'.tr();
    return (widget.isOnboarding ? 'learn.start' : 'learn.save').tr();
  }

  List<Widget> _stepContent() {
    final (title, subtitle) = switch (_step) {
      _Step.grade => ('learn.gradeTitle'.tr(), 'learn.gradeSubtitle'.tr()),
      _Step.subjects => (
        'learn.subjectsTitle'.tr(),
        'learn.subjectsSubtitle'.tr(
          namedArgs: {'max': '$kMaxSubjects', 'count': '$kDailyQuestionCount'},
        ),
      ),
      _Step.interests => (
        'learn.interestsTitle'.tr(),
        'learn.interestsSubtitle'.tr(),
      ),
    };
    return [
      Text(title, style: homeDisplay(25, letterSpacing: -0.4, height: 1.2)),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: homeText(14.5, color: HomeColors.textDim, height: 1.4),
      ),
      const SizedBox(height: 22),
      switch (_step) {
        _Step.grade => GradePicker(grade: _grade, onChanged: _setGrade),
        _Step.subjects => SubjectPicker(
          available: Subject.forGrade(_grade ?? kMaxGrade),
          selected: _subjects,
          onToggle: _toggleSubject,
        ),
        _Step.interests => InterestPicker(
          selected: _interests,
          onToggle: _toggleInterest,
        ),
      },
      if (_step == _Step.subjects) ...[
        const SizedBox(height: 14),
        Text(
          'learn.selectedCount'.tr(
            namedArgs: {'count': '${_subjects.length}', 'max': '$kMaxSubjects'},
          ),
          textAlign: TextAlign.center,
          style: homeText(13, color: HomeColors.textDim),
        ),
      ],
    ];
  }
}
