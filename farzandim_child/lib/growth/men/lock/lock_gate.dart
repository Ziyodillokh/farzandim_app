// Ilova qulfi darvozasi: ilova ildizida (routerdan yuqorida) turadi — qulf
// ochiq paytda butun ilova ustida qulf ekrani, orqasidagi ekranlar holati
// saqlanadi. Fonga o'tish / qaytishni kuzatadi, qulf paytida orqa tugmasi
// ilovani orqaga qaytarmaydi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/growth/men/lock/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.lock, required this.child});

  final AppLock lock;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Router'dan oldin ro'yxatga olinadi — qulf paytida orqa tugmasi shu
    // yerda ushlanadi.
    WidgetsBinding.instance.addObserver(this);
    widget.lock.addListener(_onLockChanged);
  }

  @override
  void dispose() {
    widget.lock.removeListener(_onLockChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onLockChanged() {
    // Qulflanganda ochiq klaviatura yopiladi (matn qulf ostida qolmasin).
    if (widget.lock.isLocked) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        widget.lock.onBackground();
      case AppLifecycleState.resumed:
        widget.lock.onForeground();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Future<bool> didPopRoute() async => widget.lock.isLocked;

  @override
  Widget build(BuildContext context) {
    final locked = widget.lock.isLocked;
    return Stack(
      children: [
        ExcludeSemantics(excluding: locked, child: widget.child),
        if (locked) Positioned.fill(child: LockScreen(lock: widget.lock)),
      ],
    );
  }
}

/// Qulf ekrani: logotip, PIN paneli, barmoq izi va «PIN-kodni unutdim».
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.lock});

  final AppLock lock;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _biometricReady = false;
  bool _biometricAsked = false;
  String? _forgotNote;

  AppLock get _lock => widget.lock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick();
    unawaited(_prepareBiometric());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Har qulflanishda barmoq izi bir marta o'zi so'raladi.
    if (state == AppLifecycleState.resumed && !_biometricAsked) {
      unawaited(_askBiometric());
    }
  }

  /// Kutish paytida har soniya qolgan vaqtni yangilaydi.
  void _tick() {
    _ticker?.cancel();
    if (_lock.blockedUntil == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lock.blockedUntil == null) _ticker?.cancel();
      setState(() {});
    });
  }

  Future<void> _prepareBiometric() async {
    if (!_lock.biometrics) return;
    final ready = await ref.read(deviceKeyProvider).isAvailable();
    if (!mounted || !ready) return;
    setState(() => _biometricReady = true);
    await _askBiometric();
  }

  Future<void> _askBiometric() async {
    if (!_biometricReady || _lock.blockedUntil != null) return;
    _biometricAsked = true;
    final reason = 'g5.lock.biometricReason'.tr();
    final ok = await _lock.duringSystemAuth(
      () => ref.read(deviceKeyProvider).confirm(reason),
    );
    if (ok) _lock.unlockTrusted();
  }

  Future<String?> _check(String pin) async {
    final result = await _lock.unlock(pin);
    if (result == PinCheck.blocked) _tick();
    return switch (result) {
      PinCheck.ok => null,
      PinCheck.wrong => 'g5.lock.wrong'.tr(),
      PinCheck.blocked => pinBlockedText(_lock.blockedUntil!, DateTime.now()),
    };
  }

  Future<void> _forgot() async {
    final deviceKey = ref.read(deviceKeyProvider);
    if (!await deviceKey.isDeviceSecure()) {
      if (mounted) setState(() => _forgotNote = 'g5.lock.forgotNoLock'.tr());
      return;
    }
    final reason = 'g5.lock.forgotReason'.tr();
    final ok = await _lock.duringSystemAuth(
      () => deviceKey.confirmDevice(reason),
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await _lock.disable();
    messenger?.showSnackBar(SnackBar(content: Text('g5.lock.forgotDone'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final blockedUntil = _lock.blockedUntil;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: GBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  // Ekran bo'ylab to'liq kenglik: aks holda ustun eng keng
                  // bolasigacha torayib chapga yopishadi.
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/icons/growth_logo.png',
                                width: 64,
                                height: 64,
                              ),
                            ),
                            const SizedBox(height: 22),
                            PinPanel(
                              title: 'g5.lock.title'.tr(),
                              subtitle: 'g5.lock.subtitle'.tr(),
                              blockedText: blockedUntil == null
                                  ? null
                                  : pinBlockedText(
                                      blockedUntil,
                                      DateTime.now(),
                                    ),
                              onComplete: _check,
                              leftKey: _biometricReady
                                  ? PinKey(
                                      plain: true,
                                      semanticLabel: 'g5.lock.biometric'.tr(),
                                      onTap: _askBiometric,
                                      child: const GIcon(
                                        GIcons.fingerprint,
                                        size: 32,
                                        color: GColors.text,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            children: [
                              if (_forgotNote != null) ...[
                                GNote(
                                  kind: GNoteKind.info,
                                  icon: GIcons.info,
                                  text: _forgotNote!,
                                ),
                                const SizedBox(height: 10),
                              ],
                              GLink(
                                label: 'g5.lock.forgot'.tr(),
                                onPressed: _forgot,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
