// I10 · Ilova qulfi (Men): 4 xonali PIN-kod o'rnatish, o'zgartirish,
// o'chirish; barmoq izi bilan ochish va avtomatik qulflash vaqti.
// O'zgartirish va o'chirish oldidan joriy kod so'raladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/growth/men/lock/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Telefonda ekran qulfi bormi (unutilgan kodni tiklash uchun kerak).
final _deviceSecureProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(deviceKeyProvider).isDeviceSecure(),
);

class MeLockScreen extends ConsumerWidget {
  const MeLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) => Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: GTopBar(
            leading: GTopBar.back(
              label: 'g5.common.back'.tr(),
              onPressed: () => context.pop(),
            ),
            title: 'g5.lock.settings.title'.tr(),
          ),
          dock: lock.isEnabled
              ? GButton(
                  label: 'g5.lock.settings.turnOff'.tr(),
                  kind: GButtonKind.ghost,
                  onPressed: () => _turnOff(context, lock),
                )
              : GButton(
                  label: 'g5.lock.settings.setUp'.tr(),
                  icon: GIcons.lockKey,
                  onPressed: () => _setUp(context, lock),
                ),
          children: lock.isEnabled
              ? _enabled(context, ref, lock)
              : _disabled(context, ref),
        ),
      ),
    );
  }

  List<Widget> _disabled(BuildContext context, WidgetRef ref) {
    final secure = ref.watch(_deviceSecureProvider).valueOrNull ?? true;
    return [
      GGlass(
        glowHue: GHue.blue,
        child: Column(
          children: [
            const SizedBox(height: 6),
            const GTile(icon: GIcons.lockKey, hue: GHue.blue, size: 64),
            const SizedBox(height: 16),
            Text(
              'g5.lock.settings.heroTitle'.tr(),
              textAlign: TextAlign.center,
              style: GText.display(20),
            ),
            const SizedBox(height: 8),
            Text(
              'g5.lock.settings.heroBody'.tr(),
              textAlign: TextAlign.center,
              style: GText.onest(14, color: GColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
      GList(
        children: [
          _Point(GIcons.lockSimple, GHue.blue, 'g5.lock.settings.point1'),
          _Point(GIcons.fingerprint, GHue.green, 'g5.lock.settings.point2'),
          _Point(GIcons.lifebuoy, GHue.gold, 'g5.lock.settings.point3'),
        ],
      ),
      if (!secure)
        GNote(
          kind: GNoteKind.warn,
          icon: GIcons.warningCircle,
          text: 'g5.lock.settings.noDeviceLock'.tr(),
        ),
    ];
  }

  List<Widget> _enabled(BuildContext context, WidgetRef ref, AppLock lock) {
    final bioAvailable =
        ref.watch(deviceKeyAvailableProvider).valueOrNull ?? false;
    return [
      GGlass(
        glowHue: GHue.green,
        child: Row(
          children: [
            const GTile(icon: GIcons.shieldCheck, hue: GHue.green, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('g5.lock.settings.onTitle'.tr(), style: GText.itemTitle),
                  const SizedBox(height: 3),
                  Text('g5.lock.settings.onBody'.tr(), style: GText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
      GSection(
        title: 'g5.lock.settings.options'.tr(),
        child: GList(
          children: [
            GListItem(
              leading: const GTile(
                icon: GIcons.fingerprint,
                hue: GHue.green,
                size: 40,
              ),
              title: 'g5.lock.settings.biometric'.tr(),
              subtitle: bioAvailable
                  ? null
                  : 'g5.lock.settings.biometricUnavailable'.tr(),
              trailing: GSwitch(
                value: lock.biometrics && bioAvailable,
                semanticLabel: 'g5.lock.settings.biometric'.tr(),
                onChanged: bioAvailable
                    ? (on) => _toggleBiometric(ref, lock, on)
                    : null,
              ),
            ),
            GListItem(
              leading: const GTile(icon: GIcons.timer, hue: GHue.sky, size: 40),
              title: 'g5.lock.settings.autoLock'.tr(),
              subtitle: 'g5.lock.auto.${lock.autoLock.name}'.tr(),
              onTap: () => _pickAutoLock(context, lock),
            ),
            GListItem(
              leading: const GTile(
                icon: GIcons.password,
                hue: GHue.blue,
                size: 40,
              ),
              title: 'g5.lock.settings.change'.tr(),
              onTap: () => _change(context, lock),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _setUp(BuildContext context, AppLock lock) async {
    final pin = await _newPin(context);
    if (pin == null) return;
    await lock.setPin(pin);
    HapticFeedback.mediumImpact();
    if (context.mounted) _toast(context, 'g5.lock.settings.setDone'.tr());
  }

  Future<void> _change(BuildContext context, AppLock lock) async {
    if (!await _confirmCurrent(context, lock) || !context.mounted) return;
    final pin = await _newPin(context);
    if (pin == null) return;
    await lock.setPin(pin);
    if (context.mounted) _toast(context, 'g5.lock.settings.changeDone'.tr());
  }

  Future<void> _turnOff(BuildContext context, AppLock lock) async {
    if (!await _confirmCurrent(context, lock)) return;
    await lock.disable();
    if (context.mounted) _toast(context, 'g5.lock.settings.offDone'.tr());
  }

  Future<void> _toggleBiometric(WidgetRef ref, AppLock lock, bool on) async {
    if (!on) {
      await lock.setBiometrics(false);
      return;
    }
    final reason = 'g5.lock.biometricReason'.tr();
    final ok = await lock.duringSystemAuth(
      () => ref.read(deviceKeyProvider).confirm(reason),
    );
    if (ok) await lock.setBiometrics(true);
  }

  Future<void> _pickAutoLock(BuildContext context, AppLock lock) async {
    final picked = await showGSheet<AutoLock>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('g5.lock.settings.autoLock'.tr(), style: GText.h2),
          ),
          const SizedBox(height: 6),
          Text('g5.lock.settings.autoLockHint'.tr(), style: GText.caption),
          const SizedBox(height: 14),
          for (final option in AutoLock.values) ...[
            GOption(
              label: 'g5.lock.auto.${option.name}'.tr(),
              selected: option == lock.autoLock,
              onTap: () => Navigator.of(sheetContext).pop(option),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    await lock.setAutoLock(picked);
  }

  /// Joriy kodni so'raydi (ko'p xatoda — kutish).
  Future<bool> _confirmCurrent(BuildContext context, AppLock lock) async {
    final pin = await showPinEntry(
      context,
      title: 'g5.lock.settings.currentTitle'.tr(),
      check: (pin) async => switch (await lock.verify(pin)) {
        PinCheck.ok => null,
        PinCheck.wrong => 'g5.lock.wrong'.tr(),
        PinCheck.blocked => pinBlockedText(lock.blockedUntil!, DateTime.now()),
      },
    );
    return pin != null;
  }

  /// Yangi kod: kiritish va takrorlash.
  Future<String?> _newPin(BuildContext context) async {
    final first = await showPinEntry(
      context,
      title: 'g5.lock.settings.newTitle'.tr(),
      subtitle: 'g5.lock.settings.newHint'.tr(),
    );
    if (first == null || !context.mounted) return null;
    return showPinEntry(
      context,
      title: 'g5.lock.settings.repeatTitle'.tr(),
      subtitle: 'g5.lock.settings.repeatHint'.tr(),
      check: (pin) async =>
          pin == first ? null : 'g5.lock.settings.mismatch'.tr(),
    );
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.hue, this.labelKey);

  final GIconData icon;
  final GHue hue;
  final String labelKey;

  @override
  Widget build(BuildContext context) => GListItem(
    leading: GTile(icon: icon, hue: hue, size: 40),
    title: labelKey.tr(),
  );
}

/// To'liq ekranli PIN kiritish; kod qabul qilinsa — o'sha kod, yopilsa —
/// `null`. [check] xato matn qaytarsa — panel tozalanib qayta so'raydi.
Future<String?> showPinEntry(
  BuildContext context, {
  required String title,
  String? subtitle,
  PinCheckFn? check,
}) {
  return Navigator.of(context).push<String>(
    PageRouteBuilder<String>(
      fullscreenDialog: true,
      pageBuilder: (_, _, _) =>
          _PinEntryPage(title: title, subtitle: subtitle, check: check),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PinEntryPage extends StatelessWidget {
  const _PinEntryPage({required this.title, this.subtitle, this.check});

  final String title;
  final String? subtitle;
  final PinCheckFn? check;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: GBackground()),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: PinKey(
                      plain: true,
                      semanticLabel: 'g5.common.back'.tr(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const GIcon(
                        GIcons.x,
                        size: 26,
                        color: GColors.text,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PinPanel(
                        title: title,
                        subtitle: subtitle,
                        onComplete: (pin) async {
                          final error = await check?.call(pin);
                          if (error == null && context.mounted) {
                            Navigator.of(context).pop(pin);
                          }
                          return error;
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
