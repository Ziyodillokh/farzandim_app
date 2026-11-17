// ─────────────────────────────────────────────────────────────────────
// credentials_card — "Kirish ma'lumotlari" ekranining asosiy kartalari
// ─────────────────────────────────────────────────────────────────────
//
// `CredentialsCard` — berilgan login: nusxalanadigan login, holat belgisi
// (birinchi kirish kutilmoqda / faol), kim va qachon bergan, oxirgi kirish.
// `NoCredentialsCard` — hali berilmagan: tushuntirish va "Login va parol
// berish". Parol bu kartalarda HECH QACHON ko'rsatilmaydi (u faqat berilgan
// lahzada, bir marta).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/credentials_ui.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/school_status_chip.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

/// Berilgan login kartasi.
class CredentialsCard extends StatelessWidget {
  const CredentialsCard({
    required this.credentials,
    required this.childName,
    required this.onCopyLogin,
    super.key,
  });

  final ChildCredentials credentials;
  final String childName;
  final VoidCallback onCopyLogin;

  @override
  Widget build(BuildContext context) {
    final pending = credentials.isFirstLoginPending;
    final issuedAt = credentials.issuedAt;
    final lastLogin = credentials.lastLoginAt;
    return CredCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CredIconChip(icon: SolarIconsBold.key),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'childCredentials.card.login'.tr(),
                      style: CredStyle.pop(13, c: CredStyle.dim),
                    ),
                    Text(
                      credentials.login,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CredStyle.unb(20),
                    ),
                  ],
                ),
              ),
              Semantics(
                container: true,
                button: true,
                label: 'childCredentials.card.copyLogin'.tr(),
                onTap: onCopyLogin,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('card-copy-login'),
                  onTap: onCopyLogin,
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
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SchoolPill(
              label: pending
                  ? 'childCredentials.card.statusPending'.tr()
                  : 'childCredentials.card.statusActive'.tr(),
              color: pending ? CredStyle.amber : CredStyle.green,
            ),
          ),
          if (pending) ...[
            const SizedBox(height: 8),
            Text(
              'childCredentials.card.pendingHint'.tr(
                namedArgs: {'name': childName},
              ),
              style: CredStyle.pop(13, c: CredStyle.dim),
            ),
            if (credentials.temporaryPasswordExpiresAt case final expires?) ...[
              const SizedBox(height: 4),
              Text(
                'childCredentials.card.tempExpires'.tr(
                  namedArgs: {'date': schoolStampLabel(expires)},
                ),
                style: CredStyle.pop(13, c: CredStyle.dim),
              ),
            ],
          ],
          const Divider(height: 28, color: CredStyle.cardBorder),
          CredInfoRow(
            label: 'childCredentials.card.issuedBy'.tr(),
            value: _issuerLabel(credentials.issuedBy),
          ),
          if (issuedAt != null)
            CredInfoRow(
              label: 'childCredentials.card.issuedAt'.tr(),
              value: schoolStampLabel(issuedAt),
            ),
          CredInfoRow(
            label: 'childCredentials.card.lastLogin'.tr(),
            value: lastLogin == null
                ? 'childCredentials.card.neverLoggedIn'.tr()
                : schoolStampLabel(lastLogin),
          ),
        ],
      ),
    );
  }

  /// Backend yangi turdagi beruvchi yuborsa (eski ilova) — chiziqcha.
  static String _issuerLabel(CredentialsIssuer issuer) => switch (issuer) {
    CredentialsIssuer.parent => 'childCredentials.card.issuedByParent'.tr(),
    CredentialsIssuer.school => 'childCredentials.card.issuedBySchool'.tr(),
    CredentialsIssuer.unknown => '—',
  };
}

/// Hali login berilmagan: tushuntirish va asosiy tugma.
class NoCredentialsCard extends StatelessWidget {
  const NoCredentialsCard({
    required this.childName,
    required this.onIssue,
    super.key,
  });

  final String childName;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return CredCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: CredIconChip(icon: SolarIconsBold.key, size: 72)),
          const SizedBox(height: 18),
          Text(
            'childCredentials.none.title'.tr(),
            textAlign: TextAlign.center,
            style: CredStyle.unb(17),
          ),
          const SizedBox(height: 8),
          Text(
            'childCredentials.none.body'.tr(namedArgs: {'name': childName}),
            textAlign: TextAlign.center,
            style: CredStyle.pop(14, c: CredStyle.dim),
          ),
          const SizedBox(height: 22),
          ParvozPrimaryButton(
            label: 'childCredentials.none.action'.tr(),
            onPressed: onIssue,
            showArrow: false,
          ),
        ],
      ),
    );
  }
}
