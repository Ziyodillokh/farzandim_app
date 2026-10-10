// ─────────────────────────────────────────────────────────────────────
// ScreenTimeScreen — iOS "Ekran vaqti" (Apple Family Controls)
// ─────────────────────────────────────────────────────────────────────
//
// 1) Ota-ona tasdig'i — AuthorizationCenter(.child): ota-ona Apple ID bilan,
//    Family Sharing orqali (Apple sharti). Tasdiqdan keyin ilovani ota-ona
//    ruxsatisiz o'chirib bo'lmaydi.
// 2) Cheklanadigan ilovalar — FamilyActivityPicker, ota-ona PIN'i bilan.
//    Tanlov faqat qurilmada (App Group), serverga yuborilmaydi.
// 3) Holat — jadval/"hammasini bloklash" bo'yicha cheklov hozir faolmi,
//    ota-ona bergan qo'shimcha vaqt.
// 4) Doimiy himoya — kattalar saytlari filtri, ilova o'rnatishni taqiqlash
//    (ota-ona PIN'i bilan).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farzandim_child/features/app_restrictions/presentation/providers/restrictions_sync_provider.dart';
import 'package:farzandim_child/features/permissions/presentation/widgets/permission_setup_widgets.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';
import 'package:farzandim_child/features/screen_time/presentation/widgets/parent_pin_dialog.dart';

const _card = Color(0xFF181C22);
const _danger = Color(0xFFFF6B6B);

/// Native xato kodlari, ular uchun alohida tarjima bor.
const _knownErrorCodes = {
  'invalidAccountType',
  'authorizationCanceled',
  'restricted',
  'networkError',
  'authenticationMethodUnavailable',
  'authorizationConflict',
};

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(screenTimeStatusProvider);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ScreenTimeException catch (e) {
      final key = _knownErrorCodes.contains(e.code) ? e.code : 'generic';
      if (mounted) setState(() => _error = 'screenTime.err.$key'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(screenTimeStatusProvider);
    }
  }

  Future<void> _requestAuthorization() => _run(() async {
        await ref.read(screenTimeChannelProvider).requestAuthorization();
        // Ruxsatdan keyin jadvallar ro'yxatdan o'tkazilsin.
        unawaited(ref.read(restrictionsSyncServiceProvider).sync());
      });

  Future<void> _setExtras(
    ScreenTimeStatus status, {
    bool? blockAdultWebsites,
    bool? denyAppInstallation,
  }) =>
      _run(() async {
        final isParent = await confirmParent(
          context,
          ref.read(parentPinStoreProvider),
        );
        if (!isParent) return;
        await ref.read(screenTimeChannelProvider).setExtras(
              blockAdultWebsites:
                  blockAdultWebsites ?? status.blockAdultWebsites,
              denyAppInstallation:
                  denyAppInstallation ?? status.denyAppInstallation,
            );
      });

  Future<void> _pickApps() => _run(() async {
        final isParent = await confirmParent(
          context,
          ref.read(parentPinStoreProvider),
        );
        if (!isParent) return;
        final picked = await ref.read(screenTimeChannelProvider).pickApps(
              title: 'screenTime.pickerTitle'.tr(),
              cancel: 'screenTime.pickerCancel'.tr(),
              done: 'screenTime.pickerDone'.tr(),
            );
        if (picked != null) {
          unawaited(ref.read(restrictionsSyncServiceProvider).sync());
        }
      });

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(screenTimeStatusProvider);
    return Scaffold(
      backgroundColor: PermColors.bg,
      appBar: AppBar(
        backgroundColor: PermColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(
          'screenTime.title'.tr(),
          style: GoogleFonts.unbounded(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: status.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: PermColors.blueLight),
          ),
          error: (_, __) => _LoadError(
            onRetry: () => ref.invalidate(screenTimeStatusProvider),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(ScreenTimeStatus status) {
    final error = _error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('screenTime.intro'.tr(), style: _body(14)),
        const SizedBox(height: 18),
        _StepCard(
          title: 'screenTime.stepAuthTitle'.tr(),
          body: 'screenTime.stepAuthBody'.tr(),
          trailing: status.isAuthorized
              ? _Badge(text: 'screenTime.authApproved'.tr(), isOn: true)
              : null,
          action: status.isAuthorized
              ? null
              : _ActionButton(
                  label: 'screenTime.authButton'.tr(),
                  isBusy: _busy,
                  onTap: _requestAuthorization,
                ),
          note: status.authorization == ScreenTimeAuthorization.denied
              ? 'screenTime.authDenied'.tr()
              : null,
        ),
        const SizedBox(height: 12),
        _StepCard(
          title: 'screenTime.stepAppsTitle'.tr(),
          body: 'screenTime.stepAppsBody'.tr(),
          summary: status.hasSelection
              ? 'screenTime.appsSummary'.tr(namedArgs: {
                  'apps': '${status.apps}',
                  'categories': '${status.categories}',
                  'sites': '${status.webDomains}',
                })
              : 'screenTime.appsNone'.tr(),
          action: _ActionButton(
            label: status.hasSelection
                ? 'screenTime.appsChange'.tr()
                : 'screenTime.appsChoose'.tr(),
            isBusy: _busy,
            onTap: status.isAuthorized ? _pickApps : null,
          ),
          note: status.isAuthorized ? null : 'screenTime.appsNeedAuth'.tr(),
        ),
        const SizedBox(height: 12),
        _StepCard(
          title: 'screenTime.statusTitle'.tr(),
          body: 'screenTime.statusBody'.tr(),
          trailing: _Badge(
            text: status.isBlocking
                ? 'screenTime.statusBlocking'.tr()
                : 'screenTime.statusFree'.tr(),
            isOn: status.isBlocking,
          ),
          summary: _unlockSummary(status.unlockedUntil),
        ),
        const SizedBox(height: 12),
        _StepCard(
          title: 'screenTime.extrasTitle'.tr(),
          body: 'screenTime.extrasBody'.tr(),
          action: Column(
            children: [
              _SwitchRow(
                title: 'screenTime.extrasAdult'.tr(),
                value: status.blockAdultWebsites,
                onChanged: status.isAuthorized && !_busy
                    ? (v) => _setExtras(status, blockAdultWebsites: v)
                    : null,
              ),
              _SwitchRow(
                title: 'screenTime.extrasInstall'.tr(),
                value: status.denyAppInstallation,
                onChanged: status.isAuthorized && !_busy
                    ? (v) => _setExtras(status, denyAppInstallation: v)
                    : null,
              ),
            ],
          ),
          note: status.isAuthorized ? null : 'screenTime.appsNeedAuth'.tr(),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(error, style: _body(13.5, color: _danger)),
        ],
      ],
    );
  }
}

String? _unlockSummary(DateTime? until) {
  if (until == null) return null;
  final time = DateFormat.Hm().format(until);
  return 'screenTime.unlockedUntil'.tr(namedArgs: {'time': time});
}

TextStyle _body(double size, {Color color = PermColors.dim}) =>
    GoogleFonts.poppins(fontSize: size, height: 1.45, color: color);

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.body,
    this.summary,
    this.trailing,
    this.action,
    this.note,
  });

  final String title;
  final String body;
  final String? summary;
  final Widget? trailing;
  final Widget? action;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final trailing = this.trailing;
    final action = this.action;
    final note = this.note;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: _body(13)),
          if (summary != null) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action],
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: _body(12.5)),
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: PermColors.green,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.isOn});

  final String text;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    final color = isOn ? PermColors.green : PermColors.dim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null && !isBusy;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: isEnabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: PermColors.blue,
          disabledBackgroundColor: PermColors.blue.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'screenTime.loadError'.tr(),
              textAlign: TextAlign.center,
              style: _body(14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'screenTime.retry'.tr(),
                style: GoogleFonts.poppins(color: PermColors.blueLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
