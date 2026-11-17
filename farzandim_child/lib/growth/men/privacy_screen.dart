// I09 · Maxfiylik va ma'lumotlarim: bolaga tushunarli — kim nimani ko'radi,
// ota-ona roziligi sanasi va ma'lumotni o'chirishni so'rash (ota-ona va
// maktab ko'rib chiqadi; hech narsa avtomatik o'chmaydi). «Qabul qilindi»
// faqat server tasdig'idan keyin.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/men/data/men_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MePrivacyScreen extends ConsumerStatefulWidget {
  const MePrivacyScreen({super.key});

  @override
  ConsumerState<MePrivacyScreen> createState() => _MePrivacyScreenState();
}

class _MePrivacyScreenState extends ConsumerState<MePrivacyScreen> {
  var _sending = false;
  String? _error;

  Future<void> _request() async {
    final confirmed = await showGSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('g5.men.privacy.confirmTitle'.tr(), style: GText.h2),
          ),
          const SizedBox(height: 6),
          Text('g5.men.privacy.deletionBody'.tr(), style: GText.body),
          const SizedBox(height: 16),
          GButton(
            label: 'g5.men.privacy.send'.tr(),
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 10),
          GButton(
            label: 'g5.men.privacy.cancel'.tr(),
            kind: GButtonKind.ghost,
            size: GButtonSize.second,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(menRepositoryProvider).requestDeletion();
      ref.invalidate(latestDeletionRequestProvider);
    } on MenUnavailable {
      if (mounted) setState(() => _error = 'g5.men.privacy.unavailable'.tr());
    } on Object {
      if (mounted) setState(() => _error = 'g5.men.privacy.failed'.tr());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(consentDateProvider).valueOrNull;
    final request = ref.watch(latestDeletionRequestProvider).valueOrNull;
    final rows = [
      ('me', GIcons.userCircle, GHue.blue),
      ('parents', GIcons.users, GHue.rose),
      ('school', GIcons.backpack, GHue.green),
      ('psych', GIcons.handHeart, GHue.sky),
      ('anon', GIcons.eyeSlash, GHue.teal),
    ];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.privacy.title'.tr(),
        ),
        onRefresh: () async => ref
          ..invalidate(consentDateProvider)
          ..invalidate(latestDeletionRequestProvider),
        children: [
          GSection(
            title: 'g5.men.privacy.whoSees'.tr(),
            child: GList(
              children: [
                for (final (key, icon, hue) in rows)
                  GListItem(
                    leading: GTile(icon: icon, hue: hue, size: 40),
                    title: 'g5.men.privacy.$key'.tr(),
                    subtitle: 'g5.men.privacy.${key}What'.tr(),
                  ),
              ],
            ),
          ),
          GNote(
            text: consent == null
                ? 'g5.men.privacy.consentUnknown'.tr()
                : 'g5.men.privacy.consent'.tr(
                    namedArgs: {'date': localizedDayMonth(consent)},
                  ),
            kind: GNoteKind.ok,
            icon: GIcons.sealCheck,
          ),
          GList(
            children: [
              GListItem(
                leading: const GTile(
                  icon: GIcons.shieldCheck,
                  hue: GHue.sky,
                  size: 40,
                ),
                title: 'g5.men.privacy.permissions'.tr(),
                onTap: () => GrowthLinks.mePermissions(context),
              ),
            ],
          ),
          GGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const GTile(icon: GIcons.trash, hue: GHue.slate, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'g5.men.privacy.deletion'.tr(),
                        style: GText.itemTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('g5.men.privacy.deletionBody'.tr(), style: GText.caption),
                const SizedBox(height: 12),
                if (request != null)
                  GNote(
                    text:
                        '${'g5.men.privacy.sent'.tr()}. ${'g5.men.privacy.sentAt'.tr(namedArgs: {'date': localizedDayMonth(request.createdAt)})}',
                    kind: GNoteKind.ok,
                    icon: GIcons.checkCircle,
                  )
                else ...[
                  if (_error != null) ...[
                    GNote(
                      text: _error!,
                      kind: GNoteKind.warn,
                      icon: GIcons.wifiSlash,
                    ),
                    const SizedBox(height: 10),
                  ],
                  GButton(
                    label: 'g5.men.privacy.send'.tr(),
                    kind: GButtonKind.ghost,
                    size: GButtonSize.md,
                    loading: _sending,
                    onPressed: _sending ? null : _request,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
