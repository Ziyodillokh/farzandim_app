// A09 · Kabinetni sozlash (birinchi kirish): yoshga mos uchta qoida, yangi
// parol (kuchi belgisi bilan) va ixtiyoriy qurilma kaliti (barmoq izi /
// yuz). Vaqtinchalik parol shu yerda almashtiriladi; keyin A06.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:farzandim_child/growth/kirish/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class KirishSetupScreen extends ConsumerStatefulWidget {
  const KirishSetupScreen({super.key, required this.args});

  final SetupArgs args;

  @override
  ConsumerState<KirishSetupScreen> createState() => _KirishSetupScreenState();
}

class _KirishSetupScreenState extends ConsumerState<KirishSetupScreen> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  var _key = false;
  var _busy = false;
  String? _passwordError;
  String? _repeatError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _toggleKey(bool on) async {
    if (!on) {
      setState(() => _key = false);
      return;
    }
    final ok = await ref
        .read(deviceKeyProvider)
        .confirm('g5.kirish.login.keyReason'.tr());
    if (mounted) setState(() => _key = ok);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final password = _password.text;
    final issue = passwordIssue(password, login: widget.args.login);
    final mismatch = password != _repeat.text;
    setState(() {
      _passwordError = issue == null ? null : passwordIssueText(issue);
      _repeatError = issue == null && mismatch
          ? 'g5.kirish.setup.mismatch'.tr()
          : null;
      _error = null;
    });
    if (issue != null || mismatch) return;
    setState(() => _busy = true);
    // Ekran yopilsa ham kerak bo'ladiganlar — birinchi `await`dan oldin:
    // sozlash tokeni bir martalik, sessiya yo'qolmasin.
    final registry = ref.read(accountRegistryProvider);
    final ownerPairing = ref.read(ownerPairingProvider);
    final repo = ref.read(kirishRepositoryProvider);
    final deviceFuture = ref.read(deviceDescriptorProvider.future);
    final deviceKey = _key;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hostsControl =
          registry.owner == null && prefs.getString('childId') == null;
      final device = (await deviceFuture).withHostsControl(hostsControl);
      final session = await repo.completeSetup(
        setupToken: widget.args.setupToken,
        newPassword: password,
        device: device,
      );
      _password.clear();
      _repeat.clear();
      final placement = await placeSessionWith(
        registry: registry,
        ownerPairing: ownerPairing,
        session: session,
        login: widget.args.login,
        deviceKey: deviceKey,
      );
      if (!mounted || placement == SessionPlacement.rebuilding) return;
      context.go(GrowthV5Routes.kirishProfile);
    } on KirishException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.error) {
          case KirishError.weakPassword:
            _passwordError = passwordIssueText(e.passwordIssue);
          case KirishError.setupExpired:
            _error = 'g5.kirish.setup.expired'.tr();
          case KirishError.network:
            _error = 'g5.kirish.login.network'.tr();
          default:
            _error = 'g5.kirish.setup.failed'.tr();
        }
      });
    } on Object catch (e) {
      debugPrint('[kirish] sozlash joylanmadi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'g5.kirish.setup.failed'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyAvailable =
        ref.watch(deviceKeyAvailableProvider).valueOrNull ?? false;
    final strength = passwordStrength(_password.text);
    // Sozlash ketayotganda orqaga chiqilmaydi.
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.blue,
          top: GTopBar(
            leading: GTopBar.back(
              label: 'g5.common.back'.tr(),
              onPressed: () => context.pop(),
            ),
            title: 'g5.kirish.setup.title'.tr(),
            subtitle: widget.args.childName.isEmpty
                ? null
                : widget.args.childName,
          ),
          dock: GButton(
            label: 'g5.kirish.setup.continue'.tr(),
            trailingIcon: GIcons.arrowRight,
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          children: [
            GList(
              children: [
                _Rule(GIcons.userCircle, GHue.blue, 'g5.kirish.setup.rule1'),
                _Rule(GIcons.lockKey, GHue.teal, 'g5.kirish.setup.rule2'),
                _Rule(GIcons.eye, GHue.sky, 'g5.kirish.setup.rule3'),
              ],
            ),
            GTextField(
              label: 'g5.kirish.setup.newPassword'.tr(),
              helper: 'g5.kirish.setup.hint'.tr(),
              controller: _password,
              enabled: !_busy,
              obscure: true,
              showLabel: 'g5.kirish.login.show'.tr(),
              hideLabel: 'g5.kirish.login.hide'.tr(),
              autofillHints: const [AutofillHints.newPassword],
              error: _passwordError,
              onChanged: (_) => setState(() => _passwordError = null),
            ),
            if (_password.text.isNotEmpty)
              Semantics(
                label: 'g5.kirish.setup.strength.$strength'.tr(),
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
                      Text(
                        'g5.kirish.setup.strength.$strength'.tr(),
                        style: GText.caption,
                      ),
                    ],
                  ),
                ),
              ),
            GTextField(
              label: 'g5.kirish.setup.repeat'.tr(),
              controller: _repeat,
              enabled: !_busy,
              obscure: true,
              showLabel: 'g5.kirish.login.show'.tr(),
              hideLabel: 'g5.kirish.login.hide'.tr(),
              autofillHints: const [AutofillHints.newPassword],
              error: _repeatError,
              onChanged: (_) => setState(() => _repeatError = null),
            ),
            GGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const GTile(
                        icon: GIcons.fingerprint,
                        hue: GHue.green,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'g5.kirish.setup.key'.tr(),
                              style: GText.itemTitle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              keyAvailable
                                  ? (_key
                                            ? 'g5.kirish.setup.keyAdded'
                                            : 'g5.kirish.setup.keyBody')
                                        .tr()
                                  : 'g5.kirish.setup.keyUnavailable'.tr(),
                              style: GText.caption,
                            ),
                          ],
                        ),
                      ),
                      GSwitch(
                        value: _key,
                        semanticLabel: 'g5.kirish.setup.key'.tr(),
                        onChanged: keyAvailable && !_busy ? _toggleKey : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null)
              GNote(
                text: _error!,
                kind: GNoteKind.warn,
                icon: GIcons.warningCircle,
              ),
          ],
        ),
      ),
    );
  }
}

/// Parol muammosi → maydon ostidagi matn. Qisqa, harfsiz, raqamsiz va noma'lum
/// sabab — umumiy qoida matni.
String passwordIssueText(PasswordIssue? issue) => switch (issue) {
  PasswordIssue.sameAsCurrent => 'g5.kirish.setup.sameAsCurrent',
  PasswordIssue.tooCommon => 'g5.kirish.setup.tooCommon',
  PasswordIssue.tooLong => 'g5.kirish.setup.tooLong',
  PasswordIssue.sameAsLogin => 'g5.kirish.setup.sameAsLogin',
  _ => 'g5.kirish.setup.weak',
}.tr();

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.hue, this.labelKey);

  final GIconData icon;
  final GHue hue;
  final String labelKey;

  @override
  Widget build(BuildContext context) => GListItem(
    leading: GTile(icon: icon, hue: hue, size: 40),
    title: labelKey.tr(),
  );
}
