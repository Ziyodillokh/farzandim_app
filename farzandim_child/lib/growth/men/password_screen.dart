// I04b · Parolni almashtirish (Men › Sozlamalar › Akkaunt): joriy parol,
// yangi parol (kuch ko'rsatkichi bilan) va takrorlash. Serverda boshqa
// qurilmalardagi login sessiyalar yopiladi, shu qurilma ochiq qoladi.
// Oila kodi bilan ulangan akkauntda login yo'q — login va parolni ota-ona
// yoki maktab beradi (`NO_CREDENTIAL`).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/kirish/setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MePasswordScreen extends ConsumerStatefulWidget {
  const MePasswordScreen({super.key});

  @override
  ConsumerState<MePasswordScreen> createState() => _MePasswordScreenState();
}

class _MePasswordScreenState extends ConsumerState<MePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _currentError;
  String? _nextError;
  String? _repeatError;
  String? _error;

  /// `true` — akkauntga login berilmagan, o'zgartiradigan parol yo'q.
  bool _noLogin = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final current = _current.text;
    final next = _next.text;
    final login = ref.read(accountRegistryProvider).active?.login;
    final issue = next == current && next.isNotEmpty
        ? PasswordIssue.sameAsCurrent
        : passwordIssue(next, login: login);
    final mismatch = next != _repeat.text;
    setState(() {
      _currentError = current.isEmpty
          ? 'g5.men.password.enterCurrent'.tr()
          : null;
      _nextError = issue == null ? null : passwordIssueText(issue);
      _repeatError = issue == null && mismatch
          ? 'g5.kirish.setup.mismatch'.tr()
          : null;
      _error = null;
    });
    if (current.isEmpty || issue != null || mismatch) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(kirishRepositoryProvider)
          .changePassword(current: current, next: next);
      _current.clear();
      _next.clear();
      _repeat.clear();
      if (mounted) {
        setState(() {
          _busy = false;
          _done = true;
        });
      }
    } on KirishException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.error) {
          case KirishError.invalidCredentials:
            _currentError = 'g5.men.password.wrongCurrent'.tr();
          case KirishError.weakPassword:
            _nextError = passwordIssueText(e.passwordIssue);
          case KirishError.noCredential:
            _noLogin = true;
          case KirishError.locked || KirishError.rateLimited:
            _error = 'g5.men.password.tooMany'.tr();
          case KirishError.network:
            _error = 'g5.kirish.login.network'.tr();
          default:
            _error = 'g5.men.password.failed'.tr();
        }
      });
    } on Object catch (e) {
      debugPrint('[men] parol almashmadi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'g5.men.password.failed'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(_next.text);
    final canEdit = !_busy && !_done && !_noLogin;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: GTopBar(
            leading: GTopBar.back(
              label: 'g5.common.back'.tr(),
              onPressed: () => context.pop(),
            ),
            title: 'g5.men.password.title'.tr(),
          ),
          dock: _done || _noLogin
              ? GButton(
                  label: 'g5.men.password.back'.tr(),
                  onPressed: () => context.pop(),
                )
              : GButton(
                  label: 'g5.men.password.save'.tr(),
                  icon: GIcons.lockKey,
                  loading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
          children: [
            if (_done)
              GNote(
                kind: GNoteKind.info,
                icon: GIcons.checkCircle,
                text: 'g5.men.password.done'.tr(),
              )
            else if (_noLogin)
              GNote(
                kind: GNoteKind.info,
                icon: GIcons.userCircle,
                text: 'g5.men.password.noLogin'.tr(),
              )
            else ...[
              GNote(
                kind: GNoteKind.plain,
                icon: GIcons.shieldCheck,
                text: 'g5.men.password.intro'.tr(),
              ),
              GTextField(
                label: 'g5.men.password.current'.tr(),
                controller: _current,
                enabled: canEdit,
                obscure: true,
                showLabel: 'g5.kirish.login.show'.tr(),
                hideLabel: 'g5.kirish.login.hide'.tr(),
                autofillHints: const [AutofillHints.password],
                error: _currentError,
                onChanged: (_) => setState(() => _currentError = null),
              ),
              GTextField(
                label: 'g5.kirish.setup.newPassword'.tr(),
                helper: 'g5.kirish.setup.hint'.tr(),
                controller: _next,
                enabled: canEdit,
                obscure: true,
                showLabel: 'g5.kirish.login.show'.tr(),
                hideLabel: 'g5.kirish.login.hide'.tr(),
                autofillHints: const [AutofillHints.newPassword],
                error: _nextError,
                onChanged: (_) => setState(() => _nextError = null),
              ),
              if (_next.text.isNotEmpty) _Strength(strength),
              GTextField(
                label: 'g5.kirish.setup.repeat'.tr(),
                controller: _repeat,
                enabled: canEdit,
                obscure: true,
                showLabel: 'g5.kirish.login.show'.tr(),
                hideLabel: 'g5.kirish.login.hide'.tr(),
                autofillHints: const [AutofillHints.newPassword],
                error: _repeatError,
                onChanged: (_) => setState(() => _repeatError = null),
              ),
              if (_error != null)
                GNote(
                  text: _error!,
                  kind: GNoteKind.warn,
                  icon: GIcons.warningCircle,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Parol kuchi: 3 bo'lak (3 — kuchli, yashil; kamroq — ogohlantirish).
class _Strength extends StatelessWidget {
  const _Strength(this.strength);

  final int strength;

  @override
  Widget build(BuildContext context) {
    final label = 'g5.kirish.setup.strength.$strength'.tr();
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: GSegments(
                states: [
                  for (var i = 0; i < 3; i++)
                    i < strength
                        ? (strength >= 3
                              ? GSegmentState.ok
                              : GSegmentState.warn)
                        : GSegmentState.empty,
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: GText.caption),
          ],
        ),
      ),
    );
  }
}
