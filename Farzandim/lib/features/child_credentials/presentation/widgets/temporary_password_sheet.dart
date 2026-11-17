// ─────────────────────────────────────────────────────────────────────
// TemporaryPasswordSheet — vaqtinchalik parol BIR MARTA ko'rsatiladi
// ─────────────────────────────────────────────────────────────────────
//
// Login va vaqtinchalik parol, nusxalash va bolaga yuborish matni.
// Xavfsizlik:
//   - parol faqat shu varaqning holatida turadi: hech qaysi provayderga,
//     diskka yoki log'ga yozilmaydi; varaq yopilgach unutiladi (qayta
//     ko'rsatib bo'lmaydi — kerak bo'lsa yangi parol yaratiladi);
//   - ekran suratiga (skrinshot) TO'SIQ yo'q, lekin ogohlantirish bor;
//   - tasodifan yopilmasin: fon/tortish yopmaydi, orqaga/"Tayyor" esa
//     parol saqlanmagan bo'lsa avval so'raydi. "Saqlangan" = PAROL (yoki
//     parol bor matn) nusxalandi, yoki ulashish oynasida ilova tanlandi;
//     faqat login nusxalansa yoki ulashish oynasi yopilsa/xato bo'lsa — yo'q;
//   - nusxalangan parol ~90 s dan keyin buferdan tozalanadi
//     (`SecretClipboard`), varaq yopilganda emas — ota-ona yopib, boshqa
//     ilovaga o'tib qo'ya oladi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/data/secret_clipboard.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Varaqni ochadi; yopilganda tugaydi. [shareName] — bolaga yuboriladigan
/// matndagi HAQIQIY ism (noma'lum bo'lsa `null`: matn ismsiz).
/// [signedOutDevices] — yangilashda "boshqa qurilmalardan chiqarish" yoqilgan
/// edi: qayta ulash eslatmasi ko'rsatiladi.
Future<void> showTemporaryPasswordSheet(
  BuildContext context, {
  required String childName,
  required IssuedCredentials issued,
  String? shareName,
  bool signedOutDevices = false,
}) {
  return showCredentialsSheet<void>(
    context,
    dismissible: false,
    builder: (_) => TemporaryPasswordSheet(
      childName: childName,
      shareName: shareName,
      issued: issued,
      signedOutDevices: signedOutDevices,
    ),
  );
}

class TemporaryPasswordSheet extends ConsumerStatefulWidget {
  const TemporaryPasswordSheet({
    required this.childName,
    required this.issued,
    this.shareName,
    this.signedOutDevices = false,
    super.key,
  });

  /// Sarlavhada ko'rsatiladigan nom (bola yuklanmagan bo'lsa umumiy "Bola").
  final String childName;

  /// Bolaga yuboriladigan matndagi haqiqiy ism; `null` — ism yo'q. Umumiy
  /// "Bola" so'zi bolaning o'ziga yuboriladigan xabarga tushmasin.
  final String? shareName;
  final IssuedCredentials issued;
  final bool signedOutDevices;

  @override
  ConsumerState<TemporaryPasswordSheet> createState() =>
      _TemporaryPasswordSheetState();
}

class _TemporaryPasswordSheetState
    extends ConsumerState<TemporaryPasswordSheet> {
  /// PAROL saqlandi (nusxalandi yoki ulashish oynasida ilova tanlandi) —
  /// yopishda so'ramaymiz. Faqat login nusxalansa `true` bo'lmaydi.
  bool _saved = false;

  /// Bolaga yuboriladigan matn. Ism noma'lum bo'lsa — ismsiz variant.
  String get _shareText {
    final login = widget.issued.login;
    final password = widget.issued.temporaryPassword;
    final name = widget.shareName;
    if (name == null) {
      return 'childCredentials.reveal.shareMessageNoName'.tr(
        namedArgs: {'login': login, 'password': password},
      );
    }
    return 'childCredentials.reveal.shareMessage'.tr(
      namedArgs: {'name': name, 'login': login, 'password': password},
    );
  }

  /// Login maxfiy emas: oddiy nusxalash, "saqlandi" bo'lmaydi.
  Future<void> _copyLogin() async {
    final clipboard = ref.read(secretClipboardProvider);
    try {
      await clipboard.copy(widget.issued.login);
    } on Exception {
      _showCopyFailed();
      return;
    }
    if (!mounted) return;
    AppToast.success(context, 'childCredentials.reveal.copied'.tr());
  }

  /// Parol (yoki parol bor matn) nusxalandi: saqlandi, bufer ~90 s dan
  /// keyin tozalanadi. Nusxalab bo'lmasa (platforma xatosi) — saqlangan
  /// hisoblanmaydi va xabar chiqadi.
  Future<void> _copySecret(String text) async {
    final clipboard = ref.read(secretClipboardProvider);
    try {
      await clipboard.copySecret(text);
    } on Exception {
      _showCopyFailed();
      return;
    }
    if (!mounted) return;
    setState(() => _saved = true);
    AppToast.success(context, 'childCredentials.reveal.copied'.tr());
  }

  void _showCopyFailed() {
    if (mounted) AppToast.error(context, 'errors.generic'.tr());
  }

  Future<void> _share() async {
    final share = ref.read(shareTextProvider);
    final text = _shareText;
    final subject = 'childCredentials.reveal.shareSubject'.tr();
    try {
      final shared = await share(text, subject: subject);
      // Oyna yopilsa yoki natija noma'lum bo'lsa — yuborilgan hisoblanmaydi.
      if (shared && mounted) setState(() => _saved = true);
    } on Object {
      // Ulashish oynasi ochilmadi (platforma yo'q) — nusxalash qoladi.
      if (mounted) AppToast.error(context, 'errors.generic'.tr());
    }
  }

  /// Nusxalangan/yuborilgan bo'lsa — darrov yopiladi, aks holda parol
  /// qayta ko'rsatilmasligi haqida so'raladi.
  Future<void> _requestClose() async {
    if (!_saved) {
      final close = await showCredentialsConfirm(
        context,
        title: 'childCredentials.reveal.confirmTitle'.tr(),
        body: 'childCredentials.reveal.confirmBody'.tr(),
        confirmLabel: 'childCredentials.reveal.confirmClose'.tr(),
        cancelLabel: 'childCredentials.reveal.confirmStay'.tr(),
        destructive: true,
      );
      if (!close || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final issued = widget.issued;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: SchoolSheetFrame(
        title: 'childCredentials.reveal.title'.tr(),
        subtitle: 'childCredentials.reveal.subtitle'.tr(
          namedArgs: {'name': widget.childName},
        ),
        children: [
          CredCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SecretField(
                  label: 'childCredentials.reveal.login'.tr(),
                  value: issued.login,
                  copyKey: const ValueKey('reveal-copy-login'),
                  copyLabel: 'childCredentials.reveal.copyLogin'.tr(),
                  onCopy: () => unawaited(_copyLogin()),
                ),
                const Divider(height: 24, color: CredStyle.cardBorder),
                _SecretField(
                  label: 'childCredentials.reveal.password'.tr(),
                  value: issued.temporaryPassword,
                  copyKey: const ValueKey('reveal-copy-password'),
                  copyLabel: 'childCredentials.reveal.copyPassword'.tr(),
                  onCopy: () =>
                      unawaited(_copySecret(issued.temporaryPassword)),
                  large: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _WarningBox(
            title: 'childCredentials.reveal.warnTitle'.tr(),
            body: 'childCredentials.reveal.warnBody'.tr(),
          ),
          if (widget.signedOutDevices) ...[
            const SizedBox(height: 10),
            SchoolNote(
              icon: SolarIconsBold.logout,
              text: 'childCredentials.reveal.signedOutNote'.tr(),
            ),
          ],
          const SizedBox(height: 18),
          ParvozPrimaryButton(
            label: 'childCredentials.reveal.share'.tr(),
            onPressed: () => unawaited(_share()),
            showArrow: false,
          ),
          const SizedBox(height: 10),
          ParvozSecondaryButton(
            label: 'childCredentials.reveal.copyAll'.tr(),
            leading: const Icon(
              SolarIconsOutline.copy,
              size: 20,
              color: Colors.white,
            ),
            onPressed: () => unawaited(_copySecret(_shareText)),
          ),
          const SizedBox(height: 4),
          SchoolTextButton(
            label: 'childCredentials.reveal.done'.tr(),
            onTap: () => unawaited(_requestClose()),
          ),
        ],
      ),
    );
  }
}

/// Yorliq + katta qiymat + nusxalash tugmasi.
class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.label,
    required this.value,
    required this.copyKey,
    required this.copyLabel,
    required this.onCopy,
    this.large = false,
  });

  final String label;
  final String value;
  final Key copyKey;
  final String copyLabel;
  final VoidCallback onCopy;

  /// Parol: kattaroq, harflar orasi ochiq (o'qish va ko'chirish oson).
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: CredStyle.pop(13, c: CredStyle.dim)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: large
                      ? CredStyle.unb(28, w: FontWeight.w700, ls: 3)
                      : CredStyle.unb(20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          container: true,
          button: true,
          label: copyLabel,
          onTap: onCopy,
          excludeSemantics: true,
          child: GestureDetector(
            key: copyKey,
            onTap: onCopy,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                SolarIconsOutline.copy,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sariq ogohlantirish: parol bir marta ko'rsatiladi, skrinshot haqida.
class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CredStyle.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CredStyle.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            SolarIconsBold.dangerTriangle,
            size: 20,
            color: CredStyle.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CredStyle.pop(14, w: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body, style: CredStyle.pop(13, c: CredStyle.dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
