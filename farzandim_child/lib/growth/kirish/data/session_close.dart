// Server signallari bo'yicha akkauntni shu qurilmadan chiqarish (v5).
//
// Har konteyner o'z socket'iga ega: qurilma egasi konteyneri egasining,
// mehmon konteyneri mehmonning xonasidagi hodisalarni oladi. Ishlovchilar
// faqat SHU konteyner akkauntiga tegishli hodisaga javob beradi — mehmonning
// hodisasi hech qachon egasining nazoratini o'chirmaydi va aksincha.

import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';

/// `child:unpaired` (`{ childId, reason, at }`): bolani qurilmadan uzish.
///
/// [guest] — mehmon konteynerida shu akkaunt, egasi konteynerida `null`;
/// [pairedChildId] — egasi konteynerida juftlangan bola.
Future<void> handleChildUnpaired(
  Object? payload, {
  required DeviceAccount? guest,
  required AccountRegistry registry,
  required PairingNotifier pairing,
  required String? pairedChildId,
}) async {
  final data = payload is Map ? payload : const <Object?, Object?>{};
  final childId = data['childId'];
  final reason = data['reason'];
  final notice = closedReasonFromWire(reason is String ? reason : null);
  if (guest != null) {
    if (childId is String && childId != guest.childId) return;
    await registry.signOutGuest(guest.childId, notice: notice);
    return;
  }
  if (childId is String && pairedChildId != null && childId != pairedChildId) {
    return;
  }
  await registry.ownerClosed(notice: notice);
  await pairing.unpair();
}

/// `session:closed` (`{ sessionIds, reason }`): shu konteyner akkauntining
/// login sessiyasi yopilgan bo'lsa — akkaunt chiqariladi (A12).
Future<void> handleSessionClosed(
  Object? payload, {
  required DeviceAccount? guest,
  required AccountRegistry registry,
  required PairingNotifier pairing,
}) async {
  if (payload is! Map) return;
  final ids = payload['sessionIds'];
  final reason = payload['reason'] is String
      ? payload['reason'] as String
      : null;
  final account = guest != null
      ? registry.accountById(guest.childId)
      : registry.owner;
  final sessionId = account?.sessionId;
  if (account == null || sessionId == null) return;
  if (ids is! List || !ids.contains(sessionId)) return;
  // Shu qurilmada qayta kirish: server eski sessiyani almashtirdi — akkaunt
  // yangi sessiya bilan qoladi.
  if (reason == 'SIGNED_OUT' && registry.isReauthenticating(account.childId)) {
    return;
  }
  final notice = closedReasonFromWire(reason);
  if (guest != null) {
    await registry.signOutGuest(guest.childId, notice: notice);
    return;
  }
  await registry.ownerClosed(notice: notice);
  await pairing.unpair();
}
