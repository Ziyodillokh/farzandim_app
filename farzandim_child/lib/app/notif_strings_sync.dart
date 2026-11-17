// ─────────────────────────────────────────────────────────────────────
// NotifStringsSync — fon xizmati va bloklash oynasi matnlari (tarjima)
// ─────────────────────────────────────────────────────────────────────
//
// FGS isolate'i va native RestrictionService `.tr()` qila olmaydi — matnlar
// UI isolate'da tarjima qilinib prefs'ga yoziladi. Avval bu `main()`da,
// tarjimalar YUKLANMASDAN oldin bajarilardi: har sovuq startda xom kalitlar
// ("blockScreen.blocked", "background.notificationTitle") yozilib, bloklash
// oynasi va doimiy bildirishnomada ko'rinardi.
//
// Endi: `MaterialApp.builder` ichida (Localizations o'z bolalarini faqat
// tarjimalar yuklangach quradi) — birinchi yuklanishda va har til
// almashganda, kadrdan keyin yoziladi. FGS ishlayotgan bo'lsa unga
// `parvoz:strings` yuboriladi (bildirishnoma matni yangilanadi).

import 'dart:async';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/background/data/services/background_service.dart';
import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class NotifStringsSync extends StatefulWidget {
  const NotifStringsSync({super.key, required this.child, this.onLoaded});

  final Widget child;

  /// Yuklangan til uchun bajariladi (standart — [syncBackgroundStrings]).
  final Future<void> Function(Locale locale)? onLoaded;

  @override
  State<NotifStringsSync> createState() => _NotifStringsSyncState();
}

class _NotifStringsSyncState extends State<NotifStringsSync> {
  Locale? _syncedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations o'zgarishiga bog'lanadi: yangi til yuklangach qayta
    // chaqiriladi (yuklanish davomida eski til ko'rsatilib turadi).
    final locale = Localizations.maybeLocaleOf(context);
    if (locale == null || locale == _syncedFor) return;
    _syncedFor = locale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited((widget.onLoaded ?? syncBackgroundStrings)(locale));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tarjimalarni prefs'ga yozadi va ishlayotgan FGS'ga xabar beradi
/// (faqat Android — FGS bildirishnomasi va native bloklash oynasi).
Future<void> syncBackgroundStrings(Locale locale) async {
  if (!PlatformCapabilities.hasForegroundService) return;
  try {
    await BackgroundService.cacheNotifStrings();
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(ParvozMessages.strings);
    }
  } catch (e) {
    debugPrint('[NotifStringsSync] matnlar yozilmadi ($locale): $e');
  }
}
