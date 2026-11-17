// ─────────────────────────────────────────────────────────────────────
// ResetCredentialsSheet — parolni yangilash / tiklash tasdiqlash varag'i
// ─────────────────────────────────────────────────────────────────────
//
// Yangi vaqtinchalik parol yaratiladi, eski parol ishlamay qoladi.
// "Boshqa qurilmalardan chiqarish" (standart: YOQILGAN, `signOutDevices`):
// bolaning barcha qurilmalari — ota-ona ulagan telefon ham — tizimdan
// chiqadi va uni qayta ulash kerak bo'ladi (QR kod yoki oila kodi bilan).
// Ota-ona buni bilib qaror qilishi uchun oqibat aniq yoziladi.
// "Parolni tiklash" (bolaning so'rovi) ham shu varaq — faqat sarlavha boshqa.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Yangilash natijasi: yangi parol va qurilmalar chiqarilganmi (varaqdagi
/// tanlov) — parol varag'i shunga qarab qayta ulash eslatmasini ko'rsatadi.
typedef ResetOutcome = ({IssuedCredentials issued, bool signedOutDevices});

/// Varaqni ochadi. Parol yangilansa — [ResetOutcome], bekor qilinsa — `null`.
Future<ResetOutcome?> showResetCredentialsSheet(
  BuildContext context, {
  required String childId,
  required String childName,
  bool fromRecovery = false,
}) {
  return showCredentialsSheet<ResetOutcome>(
    context,
    builder: (_) => ResetCredentialsSheet(
      childId: childId,
      childName: childName,
      fromRecovery: fromRecovery,
    ),
  );
}

class ResetCredentialsSheet extends ConsumerStatefulWidget {
  const ResetCredentialsSheet({
    required this.childId,
    required this.childName,
    this.fromRecovery = false,
    super.key,
  });

  final String childId;
  final String childName;

  /// Bolaning "parolni unutdim" so'rovidan ochilgan — sarlavha "tiklash".
  final bool fromRecovery;

  @override
  ConsumerState<ResetCredentialsSheet> createState() =>
      _ResetCredentialsSheetState();
}

class _ResetCredentialsSheetState extends ConsumerState<ResetCredentialsSheet> {
  /// Standart yoqilgan (D7): xavfsizlik uchun avval hamma qurilma chiqadi.
  bool _signOut = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    final actions = ref.read(childCredentialsActionsProvider);
    final signOut = _signOut;
    setState(() {
      _busy = true;
      _error = null;
    });
    final CredentialsResult<IssuedCredentials> result;
    try {
      result = await actions.reset(widget.childId, signOutDevices: signOut);
    } on Object {
      // Kutilmagan dastur xatosi: varaq band holatda qotib qolmasin.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'errors.generic'.tr();
        });
      }
      rethrow;
    }
    if (!mounted) return;
    final issued = result.data;
    if (issued != null) {
      Navigator.of(context).pop((issued: issued, signedOutDevices: signOut));
      return;
    }
    setState(() {
      _busy = false;
      _error = (result.failure?.messageKey ?? 'errors.generic').tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recover = widget.fromRecovery;
    final error = _error;
    return PopScope(
      canPop: !_busy,
      child: SchoolSheetFrame(
        title:
            (recover
                    ? 'childCredentials.reset.recoverTitle'
                    : 'childCredentials.reset.title')
                .tr(),
        subtitle: 'childCredentials.reset.subtitle'.tr(
          namedArgs: {'name': widget.childName},
        ),
        children: [
          _SignOutRow(
            value: _signOut,
            onChanged: _busy
                ? null
                : (value) => setState(() => _signOut = value),
          ),
          const SizedBox(height: 12),
          SchoolNote(
            icon: _signOut
                ? SolarIconsBold.dangerTriangle
                : SolarIconsBold.infoCircle,
            text:
                (_signOut
                        ? 'childCredentials.reset.signOutOn'
                        : 'childCredentials.reset.signOutOff')
                    .tr(),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            SchoolInlineError(message: error),
          ],
          const SizedBox(height: 22),
          ParvozPrimaryButton(
            label:
                (recover
                        ? 'childCredentials.reset.recoverSubmit'
                        : 'childCredentials.reset.submit')
                    .tr(),
            onPressed: _submit,
            loading: _busy,
            showArrow: false,
          ),
          const SizedBox(height: 4),
          SchoolTextButton(
            label: 'common.cancel'.tr(),
            onTap: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// "Boshqa qurilmalardan chiqarish" qatori: ikon, nom, o'tkazgich.
class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Semantics(
      container: true,
      toggled: value,
      label: 'childCredentials.reset.signOut'.tr(),
      onTap: onChanged == null ? null : () => onChanged(!value),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CredStyle.row,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CredStyle.rowBorder),
          ),
          child: Row(
            children: [
              const CredIconChip(icon: SolarIconsBold.logout, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'childCredentials.reset.signOut'.tr(),
                  style: CredStyle.pop(15, w: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 10),
              AppSwitch(
                value: value,
                onChanged: onChanged,
                activeColor: CredStyle.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
