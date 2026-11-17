// A03 · Akkauntni tiklash va A04 · Tiklash holati. Kanal — tasdiqlangan
// ota-ona yoki maktab xodimi; aynan o'sha akkaunt tiklanadi (yangisi
// ochilmaydi). So'rov chiptasi qurilmada (secure storage) — holat shu bilan
// so'raladi: A04 ko'rinib turganda har 20 soniyada va ilovaga qaytilganda,
// so'rov ko'rib chiqilguncha. Server login borligini hech qachon aytmaydi.

import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _ticketKey = 'g5_recovery_ticket_v1';

/// A04 holati shu oraliqda qayta so'raladi (so'rov ko'rib chiqilguncha).
const kRecoveryPollInterval = Duration(seconds: 20);

/// Chiptani yozish shundan uzoq cho'zilsa — A04 baribir ochiladi.
const _storeTimeout = Duration(seconds: 5);

final recoveryTicketStoreProvider = Provider<AccountStore>(
  (_) => const SecureAccountStore(),
);

Future<RecoveryTicket?> _readTicket(AccountStore store) async {
  try {
    final raw = await store.read(_ticketKey);
    return raw == null ? null : RecoveryTicket.tryFromJson(jsonDecode(raw));
  } on Object catch (e) {
    debugPrint('[kirish] tiklash chiptasi o\'qilmadi: ${e.runtimeType}');
    return null;
  }
}

Future<void> _writeTicket(AccountStore store, RecoveryTicket? ticket) async {
  try {
    await store
        .write(_ticketKey, ticket == null ? null : jsonEncode(ticket.toJson()))
        .timeout(_storeTimeout);
  } on Object catch (e) {
    // Keychain / Keystore xatosi — oqim to'xtamaydi (A04 chiptani `extra`
    // bilan oladi).
    debugPrint('[kirish] tiklash chiptasi yozilmadi: ${e.runtimeType}');
  }
}

/// Qurilmada saqlangan tiklash chiptasi (`null` — yo'q yoki o'qilmadi).
final recoveryTicketProvider = FutureProvider.autoDispose<RecoveryTicket?>(
  (ref) => _readTicket(ref.watch(recoveryTicketStoreProvider)),
);

/// Qurilmada tiklash so'rovi chiptasi bormi (A02 dan A04 ga havola uchun).
/// Ekrandan chaqirilganda `store: ref.read(recoveryTicketStoreProvider)`
/// berilsin (testlardagi almashtirish ham hisobga olinadi).
Future<bool> hasPendingRecoveryTicket({AccountStore? store}) async =>
    await _readTicket(store ?? const SecureAccountStore()) != null;

/// [RecoveryTicket] bo'yicha so'rov holati (A04).
final recoveryStatusProvider = FutureProvider.autoDispose
    .family<RecoveryStatus, RecoveryTicket>(
      (ref, ticket) =>
          ref.watch(kirishRepositoryProvider).recoveryStatus(ticket),
    );

/// So'rov endi faol emas: server chiptani tanimadi (404).
bool _isNotFound(Object? error) =>
    error is KirishException && error.error == KirishError.notFound;

/// So'rov ko'rib chiqildi (tiklandi yoki rad etildi) — boshqa so'ralmaydi.
bool _isResolved(RecoveryStatus? status) =>
    status != null && status.state != RecoveryState.received;

String _clock(DateTime at) =>
    '${localizedDayMonth(at)}, ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

class KirishRecoveryScreen extends ConsumerStatefulWidget {
  const KirishRecoveryScreen({super.key});

  @override
  ConsumerState<KirishRecoveryScreen> createState() =>
      _KirishRecoveryScreenState();
}

class _KirishRecoveryScreenState extends ConsumerState<KirishRecoveryScreen> {
  final _login = TextEditingController();
  var _channel = RecoveryChannel.parent;
  var _busy = false;
  String? _error;

  /// So'rovlar limiti tugadi. Har urinish kunlik limitni yeydi, shuning uchun
  /// «Qayta urinish» taklif qilinmaydi: login o'zgarmaguncha tugma yopiq.
  var _limited = false;

  @override
  void dispose() {
    _login.dispose();
    super.dispose();
  }

  void _onLoginChanged(String _) {
    if (!_limited) return;
    setState(() {
      _limited = false;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy || _limited) return;
    final login = _login.text.trim().toLowerCase();
    if (!kLoginPattern.hasMatch(login)) {
      setState(() => _error = 'g5.kirish.login.invalid'.tr());
      return;
    }
    final store = ref.read(recoveryTicketStoreProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final RecoveryTicket ticket;
    try {
      ticket = await ref
          .read(kirishRepositoryProvider)
          .requestRecovery(login: login, channel: _channel);
    } on KirishException catch (e) {
      _failed(e.error);
      return;
    } on Object catch (e) {
      // Kutilmagan xato ham tugmani «band» holatida qoldirmasin.
      debugPrint('[kirish] tiklash so\'rovi: ${e.runtimeType}');
      _failed(KirishError.unknown);
      return;
    }
    // So'rov yaratildi: chipta saqlanmasa ham A04 shu chipta bilan ochiladi.
    await _writeTicket(store, ticket);
    if (!mounted) return;
    ref.invalidate(recoveryTicketProvider);
    context.pushReplacement(GrowthV5Routes.kirishRecoveryStatus, extra: ticket);
  }

  void _failed(KirishError error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _limited =
          error == KirishError.locked || error == KirishError.rateLimited;
      _error = switch (error) {
        KirishError.network => 'g5.kirish.recovery.network'.tr(),
        KirishError.locked ||
        KirishError.rateLimited => 'g5.kirish.recovery.tooMany'.tr(),
        _ => 'g5.kirish.login.failed'.tr(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.kirish.recovery.title'.tr(),
        ),
        dock: GButton(
          label: _error != null && !_busy && !_limited
              ? 'g5.kirish.recovery.retry'.tr()
              : 'g5.kirish.recovery.submit'.tr(),
          loading: _busy,
          onPressed: _busy || _limited ? null : _submit,
        ),
        children: [
          GTextField(
            label: 'g5.kirish.recovery.login'.tr(),
            hint: 'g5.kirish.login.loginHint'.tr(),
            controller: _login,
            enabled: !_busy,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.username],
            onChanged: _onLoginChanged,
          ),
          GOption(
            label: 'g5.kirish.recovery.parent'.tr(),
            subtitle: 'g5.kirish.recovery.parentBody'.tr(),
            selected: _channel == RecoveryChannel.parent,
            onTap: _busy
                ? null
                : () => setState(() => _channel = RecoveryChannel.parent),
          ),
          GOption(
            label: 'g5.kirish.recovery.school'.tr(),
            subtitle: 'g5.kirish.recovery.schoolBody'.tr(),
            selected: _channel == RecoveryChannel.school,
            onTap: _busy
                ? null
                : () => setState(() => _channel = RecoveryChannel.school),
          ),
          GNote(
            text: 'g5.kirish.recovery.note'.tr(),
            kind: GNoteKind.info,
            icon: GIcons.shieldCheck,
          ),
          if (_error != null)
            GNote(text: _error!, kind: GNoteKind.warn, icon: GIcons.wifiSlash),
        ],
      ),
    );
  }
}

class KirishRecoveryStatusScreen extends ConsumerStatefulWidget {
  const KirishRecoveryStatusScreen({super.key, this.ticket});

  /// A03 uzatgan chipta — qurilmaga saqlab bo'lmagan bo'lsa ham holat shu
  /// bilan so'raladi. `null` — qurilmada saqlangani o'qiladi.
  final RecoveryTicket? ticket;

  @override
  ConsumerState<KirishRecoveryStatusScreen> createState() =>
      _KirishRecoveryStatusScreenState();
}

class _KirishRecoveryStatusScreenState
    extends ConsumerState<KirishRecoveryStatusScreen> {
  Timer? _poll;
  late final AppLifecycleListener _lifecycle;

  /// Ilova old planda (fonda bo'lsa so'ralmaydi).
  var _foreground = true;

  /// Ekran ko'rinib turibdi (ustida boshqa ekran ochilmagan).
  var _onScreen = true;

  /// Server so'rovni tanimadi (404): chipta o'chirildi, so'rov faol emas.
  var _expired = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _poll = Timer.periodic(kRecoveryPollInterval, (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ustiga boshqa ekran ochilsa navigator bu ekranni «o'chiradi».
    _onScreen = TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  RecoveryTicket? get _ticket =>
      widget.ticket ?? ref.read(recoveryTicketProvider).valueOrNull;

  void _onLifecycle(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    // Ilovaga qaytildi — 20 soniyani kutmasdan yangilanadi.
    if (foreground) _refresh();
  }

  /// Holatni qayta so'raydi: faqat ekran ko'rinib turganda va so'rov hali
  /// ko'rib chiqilmagan bo'lsa. Tiklangan, rad etilgan yoki faol bo'lmagan
  /// so'rov uchun so'rash butunlay to'xtaydi.
  void _refresh() {
    if (!mounted || !_foreground || !_onScreen) return;
    final ticket = _ticket;
    if (ticket == null) return;
    final status = ref.read(recoveryStatusProvider(ticket));
    if (_expired ||
        _isNotFound(status.error) ||
        _isResolved(status.valueOrNull)) {
      _poll?.cancel();
      return;
    }
    if (status.isLoading) return;
    ref.invalidate(recoveryStatusProvider(ticket));
  }

  /// 404: so'rov endi faol emas — chipta qurilmadan o'chiriladi.
  Future<void> _expire() async {
    if (_expired) return;
    setState(() => _expired = true);
    _poll?.cancel();
    await _writeTicket(ref.read(recoveryTicketStoreProvider), null);
    if (mounted) ref.invalidate(recoveryTicketProvider);
  }

  Future<void> _backToLogin() async {
    final ticket = _ticket;
    final status = ticket == null
        ? null
        : ref.read(recoveryStatusProvider(ticket)).valueOrNull;
    if (_isResolved(status)) {
      // Tiklash tugadi (yoki rad etildi) — chipta endi kerak emas.
      await _writeTicket(ref.read(recoveryTicketStoreProvider), null);
    }
    if (mounted) context.go(GrowthV5Routes.kirishLogin);
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(recoveryTicketProvider);
    final ticket = widget.ticket ?? stored.valueOrNull;
    final async = ticket == null
        ? null
        : ref.watch(recoveryStatusProvider(ticket));
    if (ticket != null) {
      ref.listen(recoveryStatusProvider(ticket), (_, next) {
        if (_isNotFound(next.error)) unawaited(_expire());
      });
    }
    final inactive =
        _expired ||
        _isNotFound(async?.error) ||
        (ticket == null && !stored.isLoading);
    final restored = async?.valueOrNull?.state == RecoveryState.restored;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.close(
            label: 'g5.kirish.recoveryStatus.close'.tr(),
            onPressed: () => _backToLogin(),
          ),
          title: 'g5.kirish.recoveryStatus.title'.tr(),
        ),
        onRefresh: inactive
            ? null
            : () async => ref.invalidate(recoveryStatusProvider),
        dock: inactive
            ? GButton(
                label: 'g5.kirish.recoveryStatus.newRequest'.tr(),
                onPressed: () =>
                    context.pushReplacement(GrowthV5Routes.kirishRecovery),
              )
            : GButton(
                label: 'g5.kirish.recoveryStatus.back'.tr(),
                kind: restored ? GButtonKind.primary : GButtonKind.ghost,
                onPressed: () => _backToLogin(),
              ),
        children: inactive
            ? [
                GNote(
                  text: 'g5.kirish.recoveryStatus.inactive'.tr(),
                  kind: GNoteKind.warn,
                  icon: GIcons.warningCircle,
                ),
              ]
            : [
                _RecoverySteps(ticket: ticket, status: async?.valueOrNull),
                if (restored)
                  GNote(
                    text: 'g5.kirish.recoveryStatus.restoredBody'.tr(),
                    kind: GNoteKind.ok,
                    icon: GIcons.checkCircle,
                  ),
                if (async?.hasError ?? false)
                  GNote(
                    text: 'g5.kirish.login.network'.tr(),
                    kind: GNoteKind.warn,
                    icon: GIcons.wifiSlash,
                    action: GLink(
                      label: 'g5.kirish.recoveryStatus.refresh'.tr(),
                      onPressed: () => ref.invalidate(recoveryStatusProvider),
                    ),
                  ),
              ],
      ),
    );
  }
}

/// A04 bosqichlari: qabul qilindi → tekshiruv → tiklandi → eski qurilmadan
/// chiqildi (yoki rad etildi).
class _RecoverySteps extends StatelessWidget {
  const _RecoverySteps({required this.ticket, required this.status});

  final RecoveryTicket? ticket;
  final RecoveryStatus? status;

  @override
  Widget build(BuildContext context) {
    final ticket = this.ticket;
    final status = this.status;
    final restored = status?.state == RecoveryState.restored;
    final rejected = status?.state == RecoveryState.rejected;
    final channel = status?.channel ?? ticket?.channel;
    final school = channel == RecoveryChannel.school;
    final waitingSub = switch ((restored, school)) {
      (true, true) => 'g5.kirish.recoveryStatus.reviewedSchool',
      (true, false) => 'g5.kirish.recoveryStatus.reviewedParent',
      (false, true) => 'g5.kirish.recoveryStatus.waitingSchool',
      (false, false) => 'g5.kirish.recoveryStatus.waitingParent',
    }.tr();
    return GGlass(
      child: GSteps(
        items: [
          GStepItem(
            title: 'g5.kirish.recoveryStatus.received'.tr(),
            subtitle: ticket == null ? null : _clock(ticket.createdAt),
            state: GStepState.done,
            stateLabel: 'g5.kirish.recoveryStatus.done'.tr(),
          ),
          if (rejected)
            GStepItem(
              title: 'g5.kirish.recoveryStatus.rejected'.tr(),
              state: GStepState.warn,
            )
          else ...[
            GStepItem(
              title:
                  (restored
                          ? 'g5.kirish.recoveryStatus.reviewed'
                          : 'g5.kirish.recoveryStatus.waiting')
                      .tr(),
              subtitle: waitingSub,
              state: restored ? GStepState.done : GStepState.now,
              stateLabel:
                  (restored
                          ? 'g5.kirish.recoveryStatus.done'
                          : 'g5.kirish.recoveryStatus.now')
                      .tr(),
            ),
            GStepItem(
              title: 'g5.kirish.recoveryStatus.restored'.tr(),
              subtitle: switch (status?.restoredAt) {
                final DateTime at => _clock(at),
                null => null,
              },
              state: restored ? GStepState.done : GStepState.todo,
            ),
            GStepItem(
              title: 'g5.kirish.recoveryStatus.signedOut'.tr(),
              subtitle: switch (status?.signedOutAt) {
                final DateTime at => _clock(at),
                null => null,
              },
              state: status?.signedOutAt != null
                  ? GStepState.done
                  : GStepState.todo,
            ),
          ],
        ],
      ),
    );
  }
}
