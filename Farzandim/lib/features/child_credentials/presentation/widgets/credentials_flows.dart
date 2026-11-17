// ─────────────────────────────────────────────────────────────────────
// credentials_flows — "berish" va "yangilash" oqimlari (varaq → parol varag'i)
// ─────────────────────────────────────────────────────────────────────
//
// Ikkala oqim ham bir xil tugaydi: forma/tasdiq varag'i so'rovni yuboradi va
// natijani qaytaradi, so'ng vaqtinchalik parol BIR MARTA ko'rsatiladi.
// Ekran ("Login va parol berish", "Parolni yangilash") va so'rov kartasi
// ("Parolni tiklash") shu funksiyalarni ishlatadi.

import 'package:farzandim/features/child_credentials/presentation/widgets/issue_credentials_sheet.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/reset_credentials_sheet.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/temporary_password_sheet.dart';
import 'package:flutter/widgets.dart';

/// Birinchi marta login va parol berish. [shareName] — bolaga yuboriladigan
/// matndagi haqiqiy ism (bola yuklanmagan bo'lsa `null`).
Future<void> runIssueCredentialsFlow(
  BuildContext context, {
  required String childId,
  required String childName,
  String? shareName,
}) async {
  final issued = await showIssueCredentialsSheet(
    context,
    childId: childId,
    childName: childName,
  );
  if (issued == null || !context.mounted) return;
  await showTemporaryPasswordSheet(
    context,
    childName: childName,
    shareName: shareName,
    issued: issued,
  );
}

/// Parolni yangilash ([fromRecovery] — bolaning so'rovidan: "tiklash");
/// [shareName] yuqoridagidek.
Future<void> runResetCredentialsFlow(
  BuildContext context, {
  required String childId,
  required String childName,
  String? shareName,
  bool fromRecovery = false,
}) async {
  final outcome = await showResetCredentialsSheet(
    context,
    childId: childId,
    childName: childName,
    fromRecovery: fromRecovery,
  );
  if (outcome == null || !context.mounted) return;
  await showTemporaryPasswordSheet(
    context,
    childName: childName,
    shareName: shareName,
    issued: outcome.issued,
    signedOutDevices: outcome.signedOutDevices,
  );
}
