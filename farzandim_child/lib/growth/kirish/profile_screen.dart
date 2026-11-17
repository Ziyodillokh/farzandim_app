// A06 · Sinf va ta'lim tili: 1–11-sinf katagi, yosh (sinf + 6, −/+ bilan
// 6–18), jins (majburiy, oldindan tanlanmagan) va ta'lim tili. Bu shaxsiy
// mashqlarni moslaydi; rasmiy maktab tasdig'i alohida (A05). Keyin A05.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _minAge = 6;
const _maxAge = 18;

/// Profil bo'lmasa — shu sinfda o'qitiladigan asosiy fanlar.
const _coreSubjects = [Subject.math, Subject.native, Subject.english];

class KirishProfileScreen extends ConsumerStatefulWidget {
  const KirishProfileScreen({super.key});

  @override
  ConsumerState<KirishProfileScreen> createState() =>
      _KirishProfileScreenState();
}

class _KirishProfileScreenState extends ConsumerState<KirishProfileScreen> {
  int? _grade;
  int? _age;
  var _ageManual = false;
  String? _gender;
  var _language = EducationLanguage.uz;
  var _busy = false;
  String? _error;

  void _pickGrade(int grade) => setState(() {
    _grade = grade;
    // Qo'lda qo'yilgan yosh boshqa sinf tanlansa yana sinfdan hisoblanadi.
    _ageManual = false;
    _age = (grade + 6).clamp(_minAge, _maxAge);
  });

  Future<void> _submit() async {
    final gender = _gender;
    if (gender == null || _busy) return;
    // Ekran yopilsa ham kerak bo'ladiganlar — birinchi `await`dan oldin.
    final childId = ref.read(pairingStateProvider).childId;
    final owner = ref.read(activeGuestProvider) == null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(kirishRepositoryProvider)
          .saveProfile(age: _age, gender: gender, language: _language);
      final grade = _grade;
      if (grade != null) {
        final current = await ref.read(savedLearningProfileProvider.future);
        final kept = [
          for (final s in current?.subjects ?? const <Subject>[])
            if (s.isTaughtIn(grade)) s,
        ];
        await ref
            .read(savedLearningProfileProvider.notifier)
            .save(
              LearningProfile(
                grade: grade,
                subjects: kept.isNotEmpty
                    ? kept.take(kMaxSubjects).toList()
                    : [
                        for (final s in _coreSubjects)
                          if (s.isTaughtIn(grade)) s,
                      ],
              ),
            );
      }
      if (childId != null) await markProfileDone(childId, owner: owner);
      if (mounted) context.go(GrowthV5Routes.kirishCode);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'g5.kirish.profile.failed'.tr();
        });
      }
    }
  }

  Future<void> _notMe() async {
    final guest = ref.read(activeGuestProvider);
    if (guest == null) return;
    final repo = ref.read(kirishRepositoryProvider);
    final registry = ref.read(accountRegistryProvider);
    try {
      await repo.logout();
    } on Object catch (e) {
      debugPrint('[kirish] chiqish so\'rovi: ${e.runtimeType}');
    }
    // Konteyner almashadi (egasiga yoki kirish ekraniga) — navigatsiya shart emas.
    await registry.signOutGuest(guest.childId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.green,
        top: GTopBar(
          title: 'g5.kirish.profile.title'.tr(),
          // Boshqa akkauntga adashib kirgan mehmon chiqib keta olsin
          // (qurilma egasi bu yerdan chiqmaydi — nazorat unga bog'liq).
          actions: [
            if (ref.watch(activeGuestProvider) != null)
              GLink(
                label: 'g5.kirish.profile.notMe'.tr(),
                onPressed: _busy ? null : _notMe,
              ),
          ],
        ),
        dock: GButton(
          label: _gender == null
              ? 'g5.kirish.profile.pickGender'.tr()
              : 'g5.kirish.profile.continue'.tr(),
          trailingIcon: _gender == null ? null : GIcons.arrowRight,
          loading: _busy,
          onPressed: _gender == null || _busy ? null : _submit,
        ),
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              for (var g = kMinGrade; g <= kMaxGrade; g++)
                _GradeTile(
                  grade: g,
                  selected: _grade == g,
                  onTap: _busy ? null : () => _pickGrade(g),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: GLink(
              label: 'g5.kirish.profile.unknown'.tr(),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _grade = null;
                      if (!_ageManual) _age = null;
                    }),
            ),
          ),
          GSection(
            title: 'g5.kirish.profile.age'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GStepper(
                  value: _age,
                  min: _minAge,
                  max: _maxAge,
                  decreaseLabel: 'g5.kirish.profile.ageLess'.tr(),
                  increaseLabel: 'g5.kirish.profile.ageMore'.tr(),
                  fallback: 12,
                  onChanged: (v) => setState(() {
                    _age = v;
                    _ageManual = true;
                  }),
                ),
                if (_grade != null && !_ageManual) ...[
                  const SizedBox(height: 6),
                  Text('g5.kirish.profile.ageAuto'.tr(), style: GText.caption),
                ],
              ],
            ),
          ),
          GSection(
            title: 'g5.kirish.profile.gender'.tr(),
            child: Row(
              children: [
                for (final (value, key) in const [
                  ('male', 'g5.kirish.profile.boy'),
                  ('female', 'g5.kirish.profile.girl'),
                ]) ...[
                  if (value == 'female') const SizedBox(width: 10),
                  Expanded(
                    child: GOption(
                      label: key.tr(),
                      selected: _gender == value,
                      onTap: _busy
                          ? null
                          : () => setState(() => _gender = value),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GSection(
            title: 'g5.kirish.profile.language'.tr(),
            child: GSegmented<EducationLanguage>(
              options: EducationLanguage.values,
              selected: _language,
              labelOf: (l) => 'g5.kirish.profile.langs.${l.name}'.tr(),
              onChanged: (l) => setState(() => _language = l),
            ),
          ),
          GNote(
            text: 'g5.kirish.profile.note'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.sparkle,
          ),
          if (_error != null)
            GNote(text: _error!, kind: GNoteKind.warn, icon: GIcons.wifiSlash),
        ],
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  final int grade;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(GRadius.option);
    return GPressable(
      onTap: onTap,
      semanticLabel: 'g5.kirish.profile.grade'.tr(namedArgs: {'n': '$grade'}),
      selected: selected,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected ? null : const Color(0x0AFFFFFF),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x574F86FF), Color(0x382F5BEA)],
                )
              : null,
          border: Border.all(
            color: selected ? const Color(0x998CB4FF) : const Color(0x17FFFFFF),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text('$grade', style: GText.display(20)),
      ),
    );
  }
}
