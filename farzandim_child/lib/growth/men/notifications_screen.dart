// I07 · Bildirishnoma sozlamalari: qaysi bildirishnomalar keladi va ularda
// matn ko'rinadimi. Har bir kalit darhol serverga saqlanadi (xato bo'lsa
// avvalgi holatga qaytadi). Psixolog xabarlari doim yashirin; SOS va oila
// qo'ng'iroqlari sozlamadan qat'i nazar ishlaydi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:farzandim_child/growth/men/data/men_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Kunlik eslatma vaqti oralig'i (server bilan bir xil).
const _earliestReminder = TimeOfDay(hour: 6, minute: 0);
const _latestReminder = TimeOfDay(hour: 21, minute: 0);

class MeNotificationsScreen extends ConsumerStatefulWidget {
  const MeNotificationsScreen({super.key});

  @override
  ConsumerState<MeNotificationsScreen> createState() =>
      _MeNotificationsScreenState();
}

class _MeNotificationsScreenState extends ConsumerState<MeNotificationsScreen> {
  NotificationPrefs? _local;
  var _saveFailed = false;

  Future<void> _save(NotificationPrefs before, NotificationPrefs next) async {
    setState(() {
      _local = next;
      _saveFailed = false;
    });
    try {
      final saved = await ref
          .read(menRepositoryProvider)
          .saveNotificationPrefs(next);
      if (mounted) setState(() => _local = saved);
    } on Object {
      if (mounted) {
        setState(() {
          _local = before;
          _saveFailed = true;
        });
      }
    }
  }

  Future<void> _pickTime(NotificationPrefs prefs) async {
    final parts = prefs.dailyReminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: int.tryParse(parts.last) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'g5.men.notify.time'.tr(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    int minutes(TimeOfDay t) => t.hour * 60 + t.minute;
    final clamped = minutes(picked) < minutes(_earliestReminder)
        ? _earliestReminder
        : minutes(picked) > minutes(_latestReminder)
        ? _latestReminder
        : picked;
    final value =
        '${clamped.hour.toString().padLeft(2, '0')}:${clamped.minute.toString().padLeft(2, '0')}';
    await _save(prefs, prefs.copyWith(dailyReminderTime: value));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPrefsProvider);
    final prefs = _local ?? async.valueOrNull;
    final unavailable = async.hasValue && async.value == null;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.gold,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.notify.title'.tr(),
        ),
        children: [
          if (async.isLoading && prefs == null)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (unavailable)
            GNote(
              text: 'g5.men.notify.unavailable'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.bellSlash,
            )
          else if (prefs == null)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(notificationPrefsProvider),
              ),
            )
          else ...[
            if (_saveFailed)
              GNote(
                text: 'g5.men.notify.saveFailed'.tr(),
                kind: GNoteKind.warn,
                icon: GIcons.wifiSlash,
              ),
            GList(
              children: [
                _Toggle(
                  icon: GIcons.clipboardText,
                  hue: GHue.blue,
                  title: 'g5.men.notify.homework'.tr(),
                  subtitle: 'g5.men.notify.homeworkSub'.tr(),
                  value: prefs.homeworkReminder,
                  onChanged: (v) =>
                      _save(prefs, prefs.copyWith(homeworkReminder: v)),
                ),
                _Toggle(
                  icon: GIcons.bell,
                  hue: GHue.teal,
                  title: 'g5.men.notify.announcements'.tr(),
                  value: prefs.schoolAnnouncements,
                  onChanged: (v) =>
                      _save(prefs, prefs.copyWith(schoolAnnouncements: v)),
                ),
                _Toggle(
                  icon: GIcons.users,
                  hue: GHue.rose,
                  title: 'g5.men.notify.family'.tr(),
                  value: prefs.familyMessages,
                  onChanged: (v) =>
                      _save(prefs, prefs.copyWith(familyMessages: v)),
                ),
                _Toggle(
                  icon: GIcons.alarm,
                  hue: GHue.gold,
                  title: 'g5.men.notify.daily'.tr(),
                  subtitle: 'g5.men.notify.dailySub'.tr(
                    namedArgs: {'time': prefs.dailyReminderTime},
                  ),
                  value: prefs.dailyReminder,
                  onChanged: (v) =>
                      _save(prefs, prefs.copyWith(dailyReminder: v)),
                ),
                if (prefs.dailyReminder)
                  GListItem(
                    leading: const GTile(
                      icon: GIcons.clock,
                      hue: GHue.slate,
                      size: 40,
                    ),
                    title: 'g5.men.notify.time'.tr(),
                    trailing: Text(
                      prefs.dailyReminderTime,
                      style: GText.display(16),
                    ),
                    onTap: () => _pickTime(prefs),
                  ),
              ],
            ),
            GSection(
              title: 'g5.men.notify.privacy'.tr(),
              child: GList(
                children: [
                  _Toggle(
                    icon: GIcons.eyeSlash,
                    hue: GHue.sky,
                    title: 'g5.men.notify.hideText'.tr(),
                    subtitle: 'g5.men.notify.hideTextSub'.tr(),
                    value: prefs.hideText,
                    onChanged: (v) => _save(prefs, prefs.copyWith(hideText: v)),
                  ),
                ],
              ),
            ),
            GNote(
              text: 'g5.men.notify.psychNote'.tr(),
              kind: GNoteKind.info,
              icon: GIcons.lockKey,
            ),
          ],
          GNote(
            text: 'g5.men.notify.sosNote'.tr(),
            kind: GNoteKind.plain,
            icon: GIcons.shieldCheck,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.hue,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final GIconData icon;
  final GHue hue;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GListItem(
    leading: GTile(icon: icon, hue: hue, size: 40),
    title: title,
    subtitle: subtitle,
    trailing: GSwitch(value: value, semanticLabel: title, onChanged: onChanged),
  );
}
