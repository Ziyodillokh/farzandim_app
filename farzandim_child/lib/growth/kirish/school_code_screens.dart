// A05 · Maktabga ulanish (6 xonali kod) va A11 · Urinishlar cheklandi.
// Kod xato bo'lsa maktab yoki bola nomi aytilmaydi. 15 daqiqada 5 xato →
// vaqtincha cheklov: tugash vaqti qurilmada (shu bola akkauntiga) saqlanadi,
// A05 ochilsa ham A11 ko'rsatiladi; shaxsiy mashq ochiq qoladi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cheklov tugash vaqti — asos kalit, akkauntga bog'lanadi ([accountKey]).
const kSchoolCodeLockKey = 'g5_school_code_lock_until_v1';

/// Server `retryAfterSeconds` bermasa — cheklov oynasi.
const _defaultLock = Duration(minutes: 15);

/// [childId] uchun kod kiritish cheklovi tugash vaqti (yo'q, o'tgan yoki hech
/// kim kirmagan — `null`).
Future<DateTime?> codeLockUntil(String? childId) async {
  if (childId == null) return null;
  final prefs = await SharedPreferences.getInstance();
  final until = DateTime.tryParse(
    prefs.getString(accountKey(kSchoolCodeLockKey, childId)) ?? '',
  );
  return until != null && until.isAfter(DateTime.now()) ? until : null;
}

Future<void> _saveLock(String? childId, Duration? retryAfter) async {
  if (childId == null) return;
  final prefs = await SharedPreferences.getInstance();
  final until = DateTime.now().add(retryAfter ?? _defaultLock);
  await prefs.setString(
    accountKey(kSchoolCodeLockKey, childId),
    until.toIso8601String(),
  );
}

String _hhmm(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

class KirishSchoolCodeScreen extends ConsumerStatefulWidget {
  const KirishSchoolCodeScreen({super.key});

  @override
  ConsumerState<KirishSchoolCodeScreen> createState() =>
      _KirishSchoolCodeScreenState();
}

class _KirishSchoolCodeScreenState
    extends ConsumerState<KirishSchoolCodeScreen> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_checkLock());
  }

  Future<void> _checkLock() async {
    if (await codeLockUntil(ref.read(currentChildIdProvider)) != null &&
        mounted) {
      context.replace(kirishPath(context, GrowthV5Routes.kirishLocked));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Kod to'lishi (yoki avtomatik to'ldirish) so'rov ketayotganda ham
    // chaqirishi mumkin — ikkinchi so'rov urinish hisobini yeydi.
    if (_busy) return;
    final code = _code.text;
    if (code.length != kSchoolCodeLength) {
      setState(() => _error = 'g5.kirish.code.invalid'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(kirishRepositoryProvider).linkSchool(code);
      if (mounted) context.go(kirishPath(context, GrowthV5Routes.kirishStatus));
    } on KirishException catch (e) {
      if (!mounted) return;
      if (e.error == KirishError.locked) {
        await _saveLock(ref.read(currentChildIdProvider), e.retryAfter);
        if (mounted) {
          context.replace(kirishPath(context, GrowthV5Routes.kirishLocked));
        }
        return;
      }
      if (e.error == KirishError.alreadyEnrolled) {
        context.go(kirishPath(context, GrowthV5Routes.kirishStatus));
        return;
      }
      setState(() {
        _busy = false;
        _code.clear();
        _error = switch (e.error) {
          KirishError.codeInvalid => 'g5.kirish.code.invalid'.tr(),
          KirishError.network => 'g5.kirish.code.network'.tr(),
          KirishError.rateLimited => 'g5.kirish.code.tooMany'.tr(),
          _ => 'g5.kirish.code.invalid'.tr(),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: context.canPop()
              ? GTopBar.back(
                  label: 'g5.common.back'.tr(),
                  onPressed: () => context.pop(),
                )
              : null,
          title: 'g5.kirish.code.title'.tr(),
        ),
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GButton(
              label: _error == 'g5.kirish.code.network'.tr()
                  ? 'g5.kirish.code.retry'.tr()
                  : 'g5.kirish.code.submit'.tr(),
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 8),
            GButton(
              label: 'g5.kirish.code.later'.tr(),
              kind: GButtonKind.ghost,
              size: GButtonSize.second,
              onPressed: _busy ? null : () => leaveKirish(context, ref),
            ),
          ],
        ),
        children: [
          Text('g5.kirish.code.prompt'.tr(), style: GText.h3),
          GCodeField(
            semanticLabel: 'g5.kirish.code.title'.tr(),
            length: kSchoolCodeLength,
            controller: _code,
            error: _error != null,
            enabled: !_busy,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onCompleted: (_) => _submit(),
          ),
          if (_error != null)
            GNote(
              text: _error!,
              kind: GNoteKind.warn,
              icon: GIcons.warningCircle,
            ),
          GNote(
            text: 'g5.kirish.code.note'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.users,
          ),
        ],
      ),
    );
  }
}

class KirishLockedScreen extends ConsumerStatefulWidget {
  const KirishLockedScreen({super.key});

  @override
  ConsumerState<KirishLockedScreen> createState() => _KirishLockedScreenState();
}

class _KirishLockedScreenState extends ConsumerState<KirishLockedScreen> {
  DateTime? _until;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  Future<void> _load() async {
    final until = await codeLockUntil(ref.read(currentChildIdProvider));
    if (mounted) setState(() => _until = until);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = _until;
    final open = until == null;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(kirishPath(context, GrowthV5Routes.kirishCode)),
          ),
          title: 'g5.kirish.code.title'.tr(),
        ),
        dock: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (open) ...[
              GButton(
                label: 'g5.kirish.locked.retry'.tr(),
                onPressed: () =>
                    context.go(kirishPath(context, GrowthV5Routes.kirishCode)),
              ),
              const SizedBox(height: 8),
            ],
            GButton(
              label: 'g5.kirish.locked.practice'.tr(),
              kind: open ? GButtonKind.ghost : GButtonKind.primary,
              size: open ? GButtonSize.second : GButtonSize.lg,
              onPressed: () =>
                  leaveKirish(context, ref, target: GrowthV5Routes.learn),
            ),
          ],
        ),
        children: [
          const SizedBox(height: 12),
          const Center(
            child: GTile(
              icon: GIcons.hourglassMedium,
              hue: GHue.gold,
              size: 72,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              'g5.kirish.locked.title'.tr(),
              textAlign: TextAlign.center,
              style: GText.h2,
            ),
          ),
          if (until != null)
            Text(
              'g5.kirish.locked.until'.tr(namedArgs: {'time': _hhmm(until)}),
              textAlign: TextAlign.center,
              style: GText.display(18),
            ),
          Text(
            'g5.kirish.locked.body'.tr(),
            textAlign: TextAlign.center,
            style: GText.body,
          ),
          GGlass(
            child: Row(
              children: [
                const GTile(icon: GIcons.backpack, hue: GHue.teal, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'g5.kirish.locked.advice'.tr(),
                        style: GText.itemTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'g5.kirish.locked.adviceBody'.tr(),
                        style: GText.caption,
                      ),
                    ],
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
