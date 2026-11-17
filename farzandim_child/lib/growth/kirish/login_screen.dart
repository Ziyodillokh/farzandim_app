// A02 · Kabinetga kirish: faqat bola uchun — login, yashirin parol
// (ko'rsatish/yashirish), qurilma kaliti bilan kirish. Loginni kim berishi
// tushuntiriladi; telefon raqami so'ralmaydi. Xato bo'lsa faqat «Login yoki
// parol noto'g'ri» — boshqa akkaunt haqida hech narsa aytilmaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:farzandim_child/growth/kirish/recovery_screens.dart';
import 'package:farzandim_child/growth/kirish/switch_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A09 ga uzatiladigan ma'lumot.
class SetupArgs {
  const SetupArgs({
    required this.setupToken,
    required this.login,
    required this.childName,
  });

  final String setupToken;
  final String login;
  final String childName;
}

class KirishLoginScreen extends ConsumerStatefulWidget {
  const KirishLoginScreen({super.key, this.initialLogin});

  final String? initialLogin;

  @override
  ConsumerState<KirishLoginScreen> createState() => _KirishLoginScreenState();
}

class _KirishLoginScreenState extends ConsumerState<KirishLoginScreen> {
  late final _login = TextEditingController(text: widget.initialLogin ?? '');
  final _password = TextEditingController();
  var _busy = false;
  String? _error;
  var _invalid = false;
  bool _hasOwner = true;

  /// Yuborilgan tiklash so'rovi bor — «Kira olmayapman» uning holatini ochadi.
  bool _pendingRecovery = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _hasOwner = prefs.getString('childId') != null);
    });
    hasPendingRecoveryTicket().then((pending) {
      if (mounted && pending) setState(() => _pendingRecovery = true);
    });
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final login = _login.text.trim().toLowerCase();
    final password = _password.text;
    if (login.isEmpty || password.isEmpty) {
      setState(() {
        _invalid = true;
        _error = 'g5.kirish.login.invalid'.tr();
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _invalid = false;
    });
    // Ekran yopilsa ham kerak bo'ladiganlar — birinchi `await`dan oldin.
    final registry = ref.read(accountRegistryProvider);
    final repo = ref.read(kirishRepositoryProvider);
    final deviceFuture = ref.read(deviceDescriptorProvider.future);
    // Shu qurilmadagi akkaunt qayta kirmoqda: server eski sessiyasini
    // almashtiradi — o'sha «sessiya yopildi» hodisasi uni chiqarmasin.
    final known = registry.accountByLogin(login);
    if (known != null) registry.beginReauth(known.childId);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Qurilmada boshqa bolaning nazorati ishlasa, server bu sessiyani
      // asosiy qilmasin (nazoratni bu yerda yuritib bo'lmaydi).
      final hostsControl =
          registry.owner == null && prefs.getString('childId') == null;
      final device = (await deviceFuture).withHostsControl(hostsControl);
      final result = await repo.login(
        login: login,
        password: password,
        device: device,
      );
      if (!mounted) return;
      switch (result) {
        case LoginNeedsSetup(:final setupToken, :final childName):
          _password.clear();
          setState(() => _busy = false);
          context.push(
            GrowthV5Routes.kirishSetup,
            extra: SetupArgs(
              setupToken: setupToken,
              login: login,
              childName: childName,
            ),
          );
        case LoginOk(:final session):
          final placement = await placeSession(ref, session, login: login);
          if (!mounted || placement == SessionPlacement.rebuilding) return;
          context.go(
            await isProfileDone(session.childId)
                ? '/splash'
                : GrowthV5Routes.kirishProfile,
          );
      }
    } on KirishException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _invalid = e.error == KirishError.invalidCredentials;
        _error = switch (e.error) {
          KirishError.invalidCredentials => 'g5.kirish.login.invalid'.tr(),
          KirishError.locked ||
          KirishError.rateLimited => _lockedText(e.retryAfter),
          KirishError.network => 'g5.kirish.login.network'.tr(),
          KirishError.tempExpired => 'g5.kirish.login.tempExpired'.tr(),
          _ => 'g5.kirish.login.failed'.tr(),
        };
      });
    } on Object catch (e) {
      // Saqlash (kalitlar ombori, sozlamalar) xatosi — ekran qotib qolmasin.
      debugPrint('[kirish] kirish joylanmadi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'g5.kirish.login.failed'.tr();
      });
    } finally {
      if (known != null) registry.endReauth(known.childId);
    }
  }

  String _lockedText(Duration? retryAfter) {
    if (retryAfter == null) return 'g5.kirish.login.lockedSoon'.tr();
    final at = DateTime.now().add(retryAfter);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return 'g5.kirish.login.locked'.tr(namedArgs: {'time': time});
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(accountRegistryProvider);
    // Kalit faqat mehmon akkauntlarni ochadi — qurilma egasiga kalitsiz
    // o'tiladi (qurilma uniki).
    final keyAccounts = registry.accounts
        .where((a) => a.deviceKey && !a.owner)
        .toList();
    // Kirish ketayotganda orqaga chiqilmaydi (sessiya yarim joylanmasin).
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          theme: GBgTheme.blue,
          top: GTopBar(
            leading: context.canPop()
                ? GTopBar.back(
                    label: 'g5.common.back'.tr(),
                    onPressed: () => context.pop(),
                  )
                : null,
            title: 'g5.kirish.login.title'.tr(),
          ),
          dock: GButton(
            label: 'g5.kirish.login.submit'.tr(),
            trailingIcon: GIcons.arrowRight,
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          children: [
            AutofillGroup(
              child: Column(
                children: [
                  GTextField(
                    label: 'g5.kirish.login.login'.tr(),
                    hint: 'g5.kirish.login.loginHint'.tr(),
                    controller: _login,
                    enabled: !_busy,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    error: _invalid ? '' : null,
                  ),
                  const SizedBox(height: GSpace.gap),
                  GTextField(
                    label: 'g5.kirish.login.password'.tr(),
                    controller: _password,
                    enabled: !_busy,
                    obscure: true,
                    showLabel: 'g5.kirish.login.show'.tr(),
                    hideLabel: 'g5.kirish.login.hide'.tr(),
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    error: _error,
                  ),
                ],
              ),
            ),
            GNote(
              text: 'g5.kirish.login.who'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.users,
            ),
            if (keyAccounts.isNotEmpty)
              GButton(
                label: 'g5.kirish.login.deviceKey'.tr(),
                kind: GButtonKind.ghost,
                size: GButtonSize.md,
                icon: GIcons.fingerprint,
                onPressed: _busy
                    ? null
                    : () => keyAccounts.length == 1
                          ? switchToAccount(context, ref, keyAccounts.single)
                          : context.push(GrowthV5Routes.kirishAccounts),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                GLink(
                  label: _pendingRecovery
                      ? 'g5.kirish.login.recoveryStatus'.tr()
                      : 'g5.kirish.login.cantLogin'.tr(),
                  onPressed: () => context.push(
                    _pendingRecovery
                        ? GrowthV5Routes.kirishRecoveryStatus
                        : GrowthV5Routes.kirishRecovery,
                  ),
                ),
                if (!_hasOwner)
                  GLink(
                    label: 'g5.kirish.login.familyCode'.tr(),
                    onPressed: () => context.go('/pairing'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
