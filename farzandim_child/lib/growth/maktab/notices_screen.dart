// M06 · Maktab e'lonlari: sanali ro'yxat, e'lon shu yerda ochiladi/yopiladi;
// tasdiqlangan yuboruvchi va roli, auditoriya (sinf yoki butun maktab).
// Ochilgan e'lon o'qilgan deb belgilanadi; o'qilmagani rang va «Yangi» bilan.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_models.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  String? _openId;
  final _readNow = <String>{};

  void _toggle(SchoolNotice notice) {
    setState(() => _openId = _openId == notice.id ? null : notice.id);
    if (!notice.read && !_readNow.contains(notice.id)) {
      _readNow.add(notice.id);
      ref.read(schoolV5RepositoryProvider).markNoticeRead(notice.id).catchError(
        (Object e) {
          debugPrint('[notices] o\'qildi belgisi yuborilmadi: $e');
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolNoticesProvider);
    final items = async.valueOrNull?.items ?? const <SchoolNotice>[];
    final error = async.error;
    final unavailable =
        error is SchoolException && error.code == SchoolErrorCode.unavailable;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.school.announcementsScreen.title'.tr(),
        ),
        onRefresh: () async => ref.invalidate(schoolNoticesProvider),
        children: [
          if (async.isLoading && !async.hasValue)
            Text(
              'g5.common.loading'.tr(),
              textAlign: TextAlign.center,
              style: GText.caption,
            )
          else if (unavailable)
            GNote(
              text: 'g5.school.unavailable'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.megaphoneSimple,
            )
          else if (error != null && items.isEmpty)
            GNote(
              text: 'g5.school.loadError'.tr(),
              kind: GNoteKind.warn,
              icon: GIcons.wifiSlash,
              action: GLink(
                label: 'g5.common.retry'.tr(),
                onPressed: () => ref.invalidate(schoolNoticesProvider),
              ),
            )
          else if (items.isEmpty)
            GNote(
              text: 'g5.school.announcementsScreen.empty'.tr(),
              kind: GNoteKind.plain,
              icon: GIcons.megaphoneSimple,
            )
          else
            for (final n in items)
              _NoticeCard(
                notice: n,
                open: _openId == n.id,
                unread: !n.read && !_readNow.contains(n.id),
                onToggle: () => _toggle(n),
              ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.open,
    required this.unread,
    required this.onToggle,
  });

  final SchoolNotice notice;
  final bool open;
  final bool unread;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final role = notice.authorRole.isEmpty
        ? ''
        : 'g5.school.announcementsScreen.role.${notice.authorRole}'.tr();
    final audience = notice.forClass
        ? 'g5.school.announcementsScreen.forClass'.tr(
            namedArgs: {'class': notice.className ?? ''},
          )
        : 'g5.school.announcementsScreen.forSchool'.tr();
    return GGlass(
      kind: open ? GGlassKind.feat : GGlassKind.plain,
      glowHue: GHue.sky,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GTile(
                icon: GIcons.megaphoneSimple,
                hue: GHue.sky,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.title, style: GText.itemTitle),
                    const SizedBox(height: 2),
                    Text(
                      [
                        notice.authorName,
                        role,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: GText.caption,
                    ),
                    Text(
                      '$audience · ${localizedDayMonth(notice.sentAt)}',
                      style: GText.caption,
                    ),
                  ],
                ),
              ),
              if (unread || notice.important) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (notice.important)
                      GChip(
                        label: 'g5.school.announcementsScreen.important'.tr(),
                        kind: GChipKind.warn,
                      ),
                    if (unread) ...[
                      if (notice.important) const SizedBox(height: 4),
                      GChip(
                        label: 'g5.notifications.newChip'.tr(),
                        kind: GChipKind.info,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          if (open) ...[
            const SizedBox(height: 12),
            Text(notice.body, style: GText.body),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: GLink(
              label:
                  (open
                          ? 'g5.school.announcementsScreen.less'
                          : 'g5.school.announcementsScreen.more')
                      .tr(),
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
