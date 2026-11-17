// Komponentlar galereyasi (faqat debug): dizayn tizimini kanvasdagi
// «Dizayn tizimi» artboard'i bilan yonma-yon solishtirish uchun.
// Matnlar ataylab tarjimasiz — bu ekran foydalanuvchiga chiqmaydi.

import 'package:farzandim_child/design/design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KitGalleryScreen extends StatefulWidget {
  const KitGalleryScreen({super.key});

  @override
  State<KitGalleryScreen> createState() => _KitGalleryScreenState();
}

class _KitGalleryScreenState extends State<KitGalleryScreen> {
  var _lang = 'Oʻzbek';
  String? _gender;
  int? _age = 12;
  var _notify = true;
  var _answer = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        top: GTopBar(
          title: 'Dizayn tizimi',
          subtitle: 'Tungi shisha v5',
          leading: GTopBar.back(
            label: 'Orqaga',
            onPressed: () => context.pop(),
          ),
        ),
        dock: GButton(
          label: 'Davom etish',
          trailingIcon: GIcons.arrowRight,
          onPressed: () {},
        ),
        children: [
          _typography(),
          _buttons(),
          _tilesAndChips(),
          _cards(),
          _notes(),
          _fields(),
          _choices(),
          _progress(),
          _chat(),
        ],
      ),
    );
  }

  Widget _typography() => GSection(
    title: 'Matn',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Salom, Aziza!', style: GText.h1),
        const SizedBox(height: 6),
        Text('Bugungi 15 daqiqa', style: GText.h2),
        const SizedBox(height: 6),
        Text('Matematika · Foizlar', style: GText.h3),
        const SizedBox(height: 6),
        Text(
          'Shaxsiy mashqlarni sinfingga moslaymiz. Oʻgʻil, gʻalaba, taʼlim.',
          style: GText.body,
        ),
        const SizedBox(height: 6),
        Text('Maktab tasdigʻi alohida', style: GText.caption),
        const SizedBox(height: 6),
        Text('480 DON', style: GText.display(28)),
      ],
    ),
  );

  Widget _buttons() => GSection(
    title: 'Tugmalar',
    child: Column(
      children: [
        GButton(label: 'Mashqni boshlash', icon: GIcons.play, onPressed: () {}),
        const SizedBox(height: 10),
        GButton(
          label: 'Keyinroq',
          kind: GButtonKind.ghost,
          size: GButtonSize.second,
          onPressed: () {},
        ),
        const SizedBox(height: 10),
        const GButton(label: 'Tekshirish', onPressed: null),
        const SizedBox(height: 10),
        GButton(label: 'SOS yuborish', kind: GButtonKind.sos, onPressed: () {}),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GButton(
              label: 'Ochish',
              size: GButtonSize.md,
              expand: false,
              onPressed: () {},
            ),
            GIconButton(
              icon: GIcons.bell,
              label: 'Xabarlar',
              badge: true,
              onPressed: () {},
            ),
            GLink(label: 'Bilmayman, keyinroq', onPressed: () {}),
          ],
        ),
      ],
    ),
  );

  Widget _tilesAndChips() => GSection(
    title: 'Plitalar va belgilar',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            GTile(icon: GIcons.mathOperations, hue: GHue.blue),
            GTile(icon: GIcons.textAa, hue: GHue.green),
            GTile(icon: GIcons.globeHemisphereWest, hue: GHue.sky),
            GTile(icon: GIcons.translate, hue: GHue.orange),
            GTile(icon: GIcons.scroll, hue: GHue.gold),
            GTile(icon: GIcons.plant, hue: GHue.teal),
            GTile(icon: GIcons.heart, hue: GHue.rose),
            GTile(icon: GIcons.lockKey, hue: GHue.slate),
          ],
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GChip(label: 'Tasdiqlandi', kind: GChipKind.ok),
            GChip(label: 'Kutilmoqda', kind: GChipKind.warn),
            GChip(label: 'Yangi', kind: GChipKind.info),
            GChip(label: '6-B sinf'),
            GChip(label: 'Shoshilinch', kind: GChipKind.sos),
          ],
        ),
      ],
    ),
  );

  Widget _cards() => GSection(
    title: 'Kartalar',
    actionLabel: 'Hammasi',
    onAction: () {},
    child: Column(
      children: [
        GGlass(
          kind: GGlassKind.feat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bugungi vazifa', style: GText.h3),
              const SizedBox(height: 4),
              Text('3 ta fandan 1 tasi bajarildi', style: GText.caption),
              const SizedBox(height: 12),
              const GProgressBar(value: 1 / 3),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GList(
          children: [
            GListItem(
              title: 'Ingliz tili',
              subtitle: '9/10 · +13 DON',
              leading: GTile(
                icon: GIcons.translate,
                hue: GHue.orange,
                size: 40,
              ),
              trailing: const GChip(label: 'Bajarildi', kind: GChipKind.ok),
              onTap: () {},
            ),
            GListItem(
              title: 'Matematika · Foizlar',
              subtitle: 'Navbatda',
              leading: GTile(icon: GIcons.mathOperations, size: 40),
              onTap: () {},
            ),
          ],
        ),
      ],
    ),
  );

  Widget _notes() => const GSection(
    title: 'Eslatmalar',
    child: Column(
      children: [
        GNote(
          text:
              'Shaxsiy mashqlarni sinfingga moslaymiz. Maktab tasdigʻi alohida.',
        ),
        SizedBox(height: 10),
        GNote(
          text: 'Tekshiruv tugaguncha maktab boʻlimi yopiq turadi.',
          kind: GNoteKind.warn,
        ),
        SizedBox(height: 10),
        GNote(text: 'Soʻrov qabul qilindi.', kind: GNoteKind.ok),
        SizedBox(height: 10),
        GNote(text: 'Xavf boʻlsa 1050 ga qoʻngʻiroq qil.', kind: GNoteKind.sos),
      ],
    ),
  );

  Widget _fields() => const GSection(
    title: 'Maydonlar',
    child: Column(
      children: [
        GTextField(label: 'Login', hint: 'aziza.karimova'),
        SizedBox(height: 12),
        GTextField(
          label: 'Yangi parol',
          obscure: true,
          showLabel: 'Parolni koʻrsatish',
          hideLabel: 'Parolni yashirish',
          error: 'Parollar bir xil emas',
        ),
        SizedBox(height: 12),
        GCodeField(semanticLabel: 'Maktab kodi'),
      ],
    ),
  );

  Widget _choices() => GSection(
    title: 'Tanlovlar',
    child: Column(
      children: [
        GSegmented<String>(
          options: const ['Oʻzbek', 'Rus', 'Qoraqalpoq'],
          selected: _lang,
          labelOf: (v) => v,
          onChanged: (v) => setState(() => _lang = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GStepper(
                value: _age,
                min: 6,
                max: 18,
                unit: 'yosh',
                decreaseLabel: 'Yoshni kamaytirish',
                increaseLabel: 'Yoshni oshirish',
                onChanged: (v) => setState(() => _age = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GSegmented<String>(
                options: const ['Oʻgʻil', 'Qiz'],
                selected: _gender,
                labelOf: (v) => v,
                onChanged: (v) => setState(() => _gender = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final (i, text) in ['20', '25', '30'].indexed) ...[
          GOption(
            label: text,
            selected: _answer == i,
            onTap: () => setState(() => _answer = i),
          ),
          const SizedBox(height: 8),
        ],
        GList(
          children: [
            GListItem(
              title: 'Uy vazifasi eslatmasi',
              trailing: GSwitch(
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GButton(
          label: 'Varaqni ochish',
          kind: GButtonKind.ghost,
          size: GButtonSize.second,
          onPressed: () => showGSheet<void>(
            context,
            builder: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mashqdan chiqasanmi?', style: GText.h2),
                const SizedBox(height: 8),
                Text('Javoblaring saqlanadi.', style: GText.body),
                const SizedBox(height: 16),
                GButton(
                  label: 'Davom etish',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _progress() => const GSection(
    title: 'Holatlar',
    child: Column(
      children: [
        GSegments(
          states: [
            GSegmentState.ok,
            GSegmentState.ok,
            GSegmentState.warn,
            GSegmentState.now,
            GSegmentState.empty,
            GSegmentState.empty,
          ],
        ),
        SizedBox(height: 16),
        GGlass(
          child: GSteps(
            items: [
              GStepItem(
                title: 'Yuborildi',
                subtitle: '5-noyabr, 10:40',
                state: GStepState.done,
              ),
              GStepItem(
                title: 'Koʻrib chiqilmoqda',
                subtitle: 'Psixolog oʻqidi',
                state: GStepState.now,
              ),
              GStepItem(title: 'Javob'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chat() => const GSection(
    title: 'Yozishma',
    child: Column(
      children: [
        Row(
          children: [
            GAvatar(initials: 'O', hue: GHue.rose),
            SizedBox(width: 10),
            Text('Onam'),
          ],
        ),
        SizedBox(height: 10),
        GBubble(mine: false, child: Text('Darsdan keyin qayerdasan?')),
        SizedBox(height: 8),
        GBubble(mine: true, child: Text('Kutubxonadaman, soat 4 da chiqaman.')),
      ],
    ),
  );
}
