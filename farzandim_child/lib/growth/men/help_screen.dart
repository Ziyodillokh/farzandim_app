// I08 · Yordam: bolalar uchun qisqa savol-javob. Har bir javob 2–3 qisqa
// gap; bosilsa shu yerda ochiladi. «Ma'lumotlarimni kim ko'radi?» —
// batafsil I09 da. Kirish va maktabga ulanish ekranlari (A03, A05) 5-bosqichda.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MeHelpScreen extends StatefulWidget {
  const MeHelpScreen({super.key});

  @override
  State<MeHelpScreen> createState() => _MeHelpScreenState();
}

class _MeHelpScreenState extends State<MeHelpScreen> {
  /// Boshida «Ishonchli katta kim?» ochiq (eng muhim javob).
  String? _open = 'trusted';

  @override
  Widget build(BuildContext context) {
    final items = [
      ('cantLogin', GIcons.signIn, GHue.blue),
      ('connectSchool', GIcons.backpack, GHue.green),
      ('whoSees', GIcons.eye, GHue.teal),
      ('trusted', GIcons.handHeart, GHue.rose),
    ];
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.green,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.men.help.title'.tr(),
        ),
        children: [
          for (final (key, icon, hue) in items)
            GPressable(
              onTap: () => setState(() => _open = _open == key ? null : key),
              pressedScale: .98,
              child: Semantics(
                expanded: _open == key,
                child: GGlass(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          GTile(icon: icon, hue: hue, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'g5.men.help.$key'.tr(),
                              style: GText.itemTitle,
                            ),
                          ),
                          GIcon(
                            _open == key ? GIcons.caretUp : GIcons.caretDown,
                            size: 18,
                            color: GColors.link,
                          ),
                        ],
                      ),
                      if (_open == key) ...[
                        const SizedBox(height: 10),
                        Text('g5.men.help.${key}A'.tr(), style: GText.body),
                        if (key == 'whoSees')
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GLink(
                              label: 'g5.men.help.openPrivacy'.tr(),
                              onPressed: () => GrowthLinks.mePrivacy(context),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
