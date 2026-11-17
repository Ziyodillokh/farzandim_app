// B01/B03 · Sozlama eslatmalari: yangi versiya (yumshoq yangilanish) va
// iOS'da nazorat ishlashi uchun yetishmayotgan ruxsatlar.
//
// Ekran vaqti (Family Controls) ruxsatisiz ota-ona cheklovlari iPhone'da
// umuman ishlamaydi — bu eslatma yopilmaydi. Joylashuv «Har doim» bo'lmasa
// ilova fonda uxlaydi; bu eslatma 7 kunga yopiladi (Apple 5.1.1: ruxsatga
// majburlovchi doimiy ogohlantirish bo'lmasin). Ilovaga qaytilganda holat
// qayta tekshiriladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';
import 'package:farzandim_child/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Joylashuv eslatmasi yopilgan vaqt (ms) — eski banner bilan bir kalit.
const _kLocationDismissedAtKey = 'ios_location_banner_dismissed_at_ms';
const _kLocationSnooze = Duration(days: 7);

/// Joylashuv «Har doim» berilganmi (xato bo'lsa — eslatma ko'rsatilmaydi).
final _locationAlwaysProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await Permission.locationAlways.isGranted;
  } on Object {
    return true;
  }
});

/// Joylashuv eslatmasi hozir yopiq (7 kun ichida yopilgan) holatdami.
final _locationSnoozedProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_kLocationDismissedAtKey);
    if (at == null) return false;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(at),
    );
    return !elapsed.isNegative && elapsed < _kLocationSnooze;
  } on Object {
    return false;
  }
});

class SetupReminders extends ConsumerStatefulWidget {
  const SetupReminders({super.key});

  @override
  ConsumerState<SetupReminders> createState() => _SetupRemindersState();
}

class _SetupRemindersState extends ConsumerState<SetupReminders>
    with WidgetsBindingObserver {
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
    if (state != AppLifecycleState.resumed || !PlatformCapabilities.isIOS) {
      return;
    }
    ref
      ..invalidate(screenTimeStatusProvider)
      ..invalidate(_locationAlwaysProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notes = [
      if (PlatformCapabilities.isIOS) ..._iosNotes(),
      ?_updateNote(),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final note in notes)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: note),
      ],
    );
  }

  List<Widget> _iosNotes() {
    final screenTime = ref.watch(screenTimeStatusProvider).valueOrNull;
    if (screenTime != null && !screenTime.isAuthorized) {
      return [
        GNote(
          kind: GNoteKind.warn,
          icon: GIcons.hourglassMedium,
          text: 'g5.setup.screenTime'.tr(),
          action: GLink(
            label: 'g5.setup.screenTimeAction'.tr(),
            onPressed: () => context.push('/screen-time'),
          ),
        ),
      ];
    }
    final isAlways = ref.watch(_locationAlwaysProvider).valueOrNull;
    final isSnoozed = ref.watch(_locationSnoozedProvider).valueOrNull ?? true;
    if (isAlways != false || isSnoozed) return const [];
    return [
      GNote(
        kind: GNoteKind.info,
        icon: GIcons.mapPin,
        text: 'g5.setup.location'.tr(),
        action: Wrap(
          spacing: 16,
          children: [
            GLink(
              label: 'g5.setup.openSettings'.tr(),
              onPressed: openAppSettings,
            ),
            GLink(label: 'g5.setup.later'.tr(), onPressed: _snoozeLocation),
          ],
        ),
      ),
    ];
  }

  Widget? _updateNote() {
    final status = ref.watch(appUpdateProvider).valueOrNull;
    final url = status?.targetUrl;
    final info = status?.info;
    if (status?.state != UpdateState.softUpdateAvailable ||
        url == null ||
        info == null) {
      return null;
    }
    final latest = PlatformCapabilities.isIOS
        ? info.ios.latest
        : info.android.latest;
    return GNote(
      kind: GNoteKind.info,
      icon: GIcons.downloadSimple,
      text: 'g5.setup.update'.tr(namedArgs: {'version': latest}),
      action: Wrap(
        spacing: 16,
        children: [
          GLink(
            label: 'g5.setup.updateAction'.tr(),
            onPressed: () => _openStore(url),
          ),
          GLink(
            label: 'g5.setup.later'.tr(),
            onPressed: () =>
                ref.read(appUpdateProvider.notifier).dismissSoftUpdate(latest),
          ),
        ],
      ),
    );
  }

  Future<void> _snoozeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kLocationDismissedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } on Object catch (e) {
      debugPrint('[setup] joylashuv eslatmasi yopilmadi: ${e.runtimeType}');
    }
    if (mounted) ref.invalidate(_locationSnoozedProvider);
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('[setup] do\'kon ochilmadi: ${e.runtimeType}');
    }
  }
}
