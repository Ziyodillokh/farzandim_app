// Kirish oqimining umumiy qadamlari: muvaffaqiyatli sessiyani qurilmaga
// joylash (egasi yoki mehmon), profil tugaganini belgilash va onboarding'dan
// keyingi yo'l.

import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/onboarding/data/onboarding_prefs.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A06 (sinf va ta'lim tili) shu bola uchun tugaganmi.
String profileDoneKey(String childId) => 'g5_profile_done_$childId';

Future<bool> isProfileDone(String childId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(profileDoneKey(childId)) ?? false;
}

Future<void> markProfileDone(String childId, {required bool owner}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(profileDoneKey(childId), true);
  // Eski «qiziqishlar» onboarding'i v5 da A06 bilan almashgan — bu belgi
  // qurilma egasiniki (mehmon tugatgani egasining A06'sini o'tkazib yubormasin).
  if (owner) await prefs.setBool(kOnboardingSeenKey, true);
}

/// Sessiyani joylash natijasi.
enum SessionPlacement {
  /// UI joriy konteynerda qoladi — chaqiruvchi o'zi yo'naltiradi.
  ownerInPlace,

  /// UI boshqa akkaunt konteyneriga o'tadi — navigatsiya kerak emas
  /// (yangi router splash'dan boshlaydi).
  rebuilding,
}

/// Login / birinchi sozlashdan keyingi sessiyani qurilmaga joylaydi.
///
/// Kerakli obyektlar birinchi `await`dan OLDIN olinadi: ekran yopilsa ham
/// joylash oxirigacha boradi.
Future<SessionPlacement> placeSession(
  WidgetRef ref,
  ChildSession session, {
  required String login,
  bool deviceKey = false,
}) => placeSessionWith(
  registry: ref.read(accountRegistryProvider),
  ownerPairing: ref.read(ownerPairingProvider),
  session: session,
  login: login,
  deviceKey: deviceKey,
);

/// [placeSession] ning o'zi (testlar to'g'ridan-to'g'ri chaqiradi).
///
/// - Qurilma egasining O'ZI qayta kirdi (server shu qurilmadagi eski
///   sessiyasini almashtirdi): yangi tokenlar odatiy kalitlarga, egasi
///   yozuvi (qurilma kaliti bilan) saqlanadi — nazorat o'chmaydi.
/// - Asosiy qurilma (server `MAIN`) va qurilmada hali egasi yo'q — bola shu
///   qurilma egasi bo'ladi: juftlash sozlamalari yoziladi va nazorat
///   xizmatlari ishga tushadi. Ota-onasi aniqlanmasa joylash bekor qilinadi.
/// - Aks holda — mehmon akkaunt (alohida tokenlar, nazoratsiz).
Future<SessionPlacement> placeSessionWith({
  required AccountRegistry registry,
  required PairingNotifier ownerPairing,
  required ChildSession session,
  required String login,
  bool deviceKey = false,
  Future<String?> Function(TokenStorage tokens, String childId)? fetchParentId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final ownerChildId = registry.owner?.childId ?? prefs.getString('childId');
  final guestBefore = registry.activeGuest?.childId;
  final ownerAccount = DeviceAccount(
    childId: session.childId,
    name: session.childName,
    owner: true,
    login: login,
    deviceKey: deviceKey,
    sessionId: session.sessionId,
    parentId: session.parentId,
    userId: session.userId,
  );

  if (ownerChildId == session.childId) {
    final tokens = TokenStorage();
    await tokens.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    await prefs.remove(SessionEvents.ownerReasonKey);
    // Juftlash sozlamalari tozalangan bo'lsa (masalan sessiya yopilgach
    // egasi o'zi qayta kirdi) — tiklanadi.
    final pairedUid = prefs.getString('parentUid');
    if (pairedUid == null || prefs.getString('childId') == null) {
      final parentUid =
          session.parentId ??
          await (fetchParentId ?? _fetchParentId)(tokens, session.childId);
      if (parentUid == null) throw const KirishException(KirishError.network);
      await ownerPairing.restoreFromRecovery(
        parentUid: parentUid,
        childId: session.childId,
        childName: session.childName,
        currentUserId: session.userId,
      );
    }
    await registry.upsert(ownerAccount, activate: true);
    return guestBefore == null
        ? SessionPlacement.ownerInPlace
        : SessionPlacement.rebuilding;
  }

  if (session.role == DeviceRole.main && ownerChildId == null) {
    final tokens = TokenStorage();
    await tokens.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    final parentUid =
        session.parentId ??
        await (fetchParentId ?? _fetchParentId)(tokens, session.childId);
    if (parentUid == null) {
      // Ota-onasiz egasi bo'lmaydi (chat, joylashuv va h.k. unga bog'liq) —
      // yarim joylashni qoldirmaymiz; bola qayta urinadi.
      await tokens.clear();
      throw const KirishException(KirishError.network);
    }
    await prefs.remove(SessionEvents.ownerReasonKey);
    await ownerPairing.restoreFromRecovery(
      parentUid: parentUid,
      childId: session.childId,
      childName: session.childName,
      currentUserId: session.userId,
    );
    await registry.upsert(ownerAccount, activate: true);
    return guestBefore == null
        ? SessionPlacement.ownerInPlace
        : SessionPlacement.rebuilding;
  }

  await guestTokenStorage(session.childId).saveTokens(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
  );
  await registry.upsert(
    DeviceAccount(
      childId: session.childId,
      name: session.childName,
      owner: false,
      login: login,
      deviceKey: deviceKey,
      sessionId: session.sessionId,
      parentId: session.parentId,
      userId: session.userId,
    ),
    activate: true,
  );
  // Xuddi shu mehmon qayta kirgan bo'lsa konteyner o'zgarmaydi.
  return guestBefore == session.childId
      ? SessionPlacement.ownerInPlace
      : SessionPlacement.rebuilding;
}

/// Ota-onani yangi tokenlar bilan so'raydi (tarmoq xatosida bir marta qayta).
Future<String?> _fetchParentId(TokenStorage tokens, String childId) async {
  final repo = ApiKirishRepository(authed: createBackendDio(tokens));
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final id = await repo.parentIdOf(childId);
      return id == null || id.isEmpty ? null : id;
    } on KirishException catch (e) {
      if (e.error != KirishError.network) return null;
    }
  }
  return null;
}

/// Kirish ekranlari Maktab bo'limidan (onboarding'dan emas) ochilganda:
/// `?from=maktab` — chiqish Maktab bo'limiga qaytaradi.
const kirishFromParam = 'from';
const kirishFromMaktab = 'maktab';

bool openedFromMaktab(BuildContext context) =>
    GoRouterState.of(context).uri.queryParameters[kirishFromParam] ==
    kirishFromMaktab;

/// Shu kirish oqimidagi keyingi ekran yo'li (`from` belgisi saqlanadi).
String kirishPath(BuildContext context, String path) =>
    openedFromMaktab(context)
    ? Uri(
        path: path,
        queryParameters: const {kirishFromParam: kirishFromMaktab},
      ).toString()
    : path;

/// Kirish ekranidan chiqish: Maktab bo'limidan ochilgan bo'lsa — o'sha yerga
/// (yoki [target]ga), aks holda onboarding oqimi ([goAfterOnboarding]).
void leaveKirish(BuildContext context, WidgetRef ref, {String? target}) {
  if (openedFromMaktab(context)) {
    context.go(target ?? GrowthV5Routes.school);
  } else {
    goAfterOnboarding(context, ref, target: target);
  }
}

/// Profil (A06) va maktab (A05/A07) qadamlaridan keyin: qurilma egasi
/// splash orqali (ruxsatlar sozlamasi kerak bo'lishi mumkin), mehmon —
/// to'g'ri «Bugun»ga.
void goAfterOnboarding(BuildContext context, WidgetRef ref, {String? target}) {
  final guest = ref.read(accountRegistryProvider).activeGuest;
  if (guest == null) {
    context.go('/splash');
  } else {
    context.go(target ?? GrowthV5Routes.today);
  }
}
