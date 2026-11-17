// Qurilmadagi akkauntlar (A10). Ikki xil akkaunt bor:
//
//   • Qurilma EGASI — ota-ona juftlagan (oilaviy kod / QR) yoki shu qurilmada
//     birinchi bo'lib kirgan (asosiy qurilma) bola. Tokenlari odatiy
//     kalitlarda: fon isolate'i, joylashuv, ekran vaqti va bloklash faqat
//     shu bola uchun ishlaydi (ota-ona nazorati qurilmaga bog'langan).
//   • MEHMON akkaunt — shu qurilmada login bilan kirgan boshqa bola. Tokenlari
//     `acct_<childId>_` kalitlarida; faqat o'qish/maktab/xabarlar, nazorat yo'q.
//
// Ro'yxat Riverpod'dan TASHQARIDA (ilova ildizi faol akkauntga qarab
// ProviderScope'ni qayta quradi), shuning uchun oddiy ChangeNotifier.

import 'dart:convert';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class DeviceAccount {
  const DeviceAccount({
    required this.childId,
    required this.name,
    required this.owner,
    this.login,
    this.className,
    this.deviceKey = false,
    this.sessionId,
    this.lastUsedAt,
    this.parentId,
    this.userId,
  });

  static DeviceAccount? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['childId'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    return DeviceAccount(
      childId: id,
      name: name,
      owner: json['owner'] == true,
      login: json['login'] is String ? json['login'] as String : null,
      className: json['className'] is String
          ? json['className'] as String
          : null,
      deviceKey: json['deviceKey'] == true,
      sessionId: json['sessionId'] is String
          ? json['sessionId'] as String
          : null,
      lastUsedAt: DateTime.tryParse('${json['lastUsedAt']}'),
      parentId: json['parentId'] is String ? json['parentId'] as String : null,
      userId: json['userId'] is String ? json['userId'] as String : null,
    );
  }

  final String childId;
  final String name;

  /// Qurilma egasi (nazorat shu bola uchun).
  final bool owner;

  /// Login (A10 da tanlanganda A02 maydoni oldindan to'ldiriladi).
  final String? login;
  final String? className;

  /// Qurilma kaliti (barmoq izi / yuz) bilan kirish yoqilgan.
  final bool deviceKey;

  /// Login sessiyasi id'si (`session:closed` hodisasini tanish uchun).
  final String? sessionId;
  final DateTime? lastUsedAt;

  /// Bolaning ota-onasi va foydalanuvchi id'si — mehmon akkauntda
  /// yozishmalar (SOS, oila) shu ota-onaga boradi.
  final String? parentId;
  final String? userId;

  DeviceAccount copyWith({
    String? name,
    bool? owner,
    String? login,
    String? className,
    bool? deviceKey,
    String? sessionId,
    DateTime? lastUsedAt,
    String? parentId,
    String? userId,
  }) => DeviceAccount(
    childId: childId,
    name: name ?? this.name,
    owner: owner ?? this.owner,
    login: login ?? this.login,
    className: className ?? this.className,
    deviceKey: deviceKey ?? this.deviceKey,
    sessionId: sessionId ?? this.sessionId,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    parentId: parentId ?? this.parentId,
    userId: userId ?? this.userId,
  );

  Map<String, Object> toJson() => {
    'childId': childId,
    'name': name,
    'owner': owner,
    'login': ?login,
    'className': ?className,
    'deviceKey': deviceKey,
    'sessionId': ?sessionId,
    'lastUsedAt': ?lastUsedAt?.toIso8601String(),
    'parentId': ?parentId,
    'userId': ?userId,
  };
}

/// Mehmon akkaunt token kalitlari prefiksi (sessiya hodisalari ham shu bilan
/// belgilanadi); qurilma egasi — odatiy kalitlar (`''`).
String guestTokenScope(String childId) => 'acct_${childId}_';

/// Mehmon akkaunt tokenlari.
TokenStorage guestTokenStorage(String childId) =>
    TokenStorage(keyPrefix: guestTokenScope(childId));

abstract interface class AccountStore {
  Future<String?> read(String key);

  /// `null` — kalit o'chiriladi.
  Future<void> write(String key, String? value);
}

class SecureAccountStore implements AccountStore {
  const SecureAccountStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

/// Sessiya nima uchun yopildi (A12 matni).
enum SessionClosedReason {
  recovered,
  permissions,
  signedInElsewhere,
  signedOut,
  other,
}

/// Server sababi (`SESSION_REVOKED.reason`, `session:closed.reason`,
/// `child:unpaired.reason`) → A12 matni. Noma'lumi — umumiy matn.
SessionClosedReason closedReasonFromWire(String? reason) => switch (reason) {
  'RECOVERED' => SessionClosedReason.recovered,
  'PERMISSIONS_CHANGED' => SessionClosedReason.permissions,
  'SIGNED_IN_ELSEWHERE' => SessionClosedReason.signedInElsewhere,
  'SIGNED_OUT' => SessionClosedReason.signedOut,
  _ => SessionClosedReason.other,
};

class AccountRegistry extends ChangeNotifier {
  AccountRegistry(
    this._store, {
    TokenStorage Function(String)? guestTokens,
    Future<void> Function(String childId)? clearLocalData,
  }) : _guestTokens = guestTokens ?? guestTokenStorage,
       _clearLocalData = clearLocalData ?? clearAccountLocalData;

  /// Ilova bo'ylab yagona ro'yxat (main.dart da `load()` qilinadi).
  static AccountRegistry instance = AccountRegistry(const SecureAccountStore());

  static const _accountsKey = 'g5_accounts_v1';
  static const _activeKey = 'g5_active_account_v1';

  final AccountStore _store;
  final TokenStorage Function(String childId) _guestTokens;

  /// Akkauntdan chiqishda shaxsiy mahalliy ma'lumotlar (A12: «o'chirildi»).
  final Future<void> Function(String childId) _clearLocalData;

  var _accounts = <DeviceAccount>[];
  String? _activeId;
  SessionClosedReason? _closedNotice;

  /// Ro'yxat o'qib bo'lmagan bo'lsa (masalan kalitlar ombori vaqtincha
  /// ishlamadi) diskdagi yozuvlar bo'sh ro'yxat bilan almashtirilmaydi.
  var _loaded = true;

  /// Shu qurilmada qayta kirish ketayotgan akkauntlar: server eski sessiyani
  /// SIGNED_OUT bilan yopadi — bu hodisa akkauntni chiqarib yubormasin.
  final _reauth = <String>{};

  List<DeviceAccount> get accounts => List.unmodifiable(_accounts);

  DeviceAccount? get owner => _accounts.where((a) => a.owner).firstOrNull;

  DeviceAccount? get active =>
      _accounts.where((a) => a.childId == _activeId).firstOrNull;

  /// Faol mehmon akkaunt — UI shu bolaning konteynerida quriladi.
  /// `null`: qurilma egasi (yoki hech kim) faol.
  DeviceAccount? get activeGuest {
    final a = active;
    return a != null && !a.owner ? a : null;
  }

  DeviceAccount? accountById(String childId) =>
      _accounts.where((a) => a.childId == childId).firstOrNull;

  /// Login bo'yicha (A02 da qayta kirishni tanish uchun).
  DeviceAccount? accountByLogin(String login) {
    final normalized = login.trim().toLowerCase();
    return _accounts.where((a) => a.login == normalized).firstOrNull;
  }

  /// Ko'rsatilishi kerak bo'lgan «Bu qurilmada chiqildi» (A12) sababi.
  SessionClosedReason? get closedNotice => _closedNotice;

  Future<void> load() async {
    try {
      final raw = await _store.read(_accountsKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      _accounts = decoded is List
          ? decoded.map(DeviceAccount.tryFromJson).nonNulls.toList()
          : [];
      _activeId = await _store.read(_activeKey);
      _loaded = true;
    } on Object catch (e) {
      debugPrint('[accounts] o\'qilmadi: ${e.runtimeType}');
      _accounts = [];
      _activeId = null;
      _loaded = false;
    }
    notifyListeners();
  }

  /// Akkauntni qo'shadi yoki yangilaydi; [activate] — darhol faol qiladi.
  /// Mavjud yozuv bilan birlashtiriladi: qurilma egasi hech qachon mehmonga
  /// aylanmaydi, qurilma kaliti faqat [setDeviceKey] bilan o'chadi.
  Future<void> upsert(DeviceAccount account, {bool activate = false}) async {
    final existing = accountById(account.childId);
    final merged = DeviceAccount(
      childId: account.childId,
      name: account.name.isNotEmpty ? account.name : existing?.name ?? '',
      owner: account.owner || (existing?.owner ?? false),
      login: account.login ?? existing?.login,
      className: account.className ?? existing?.className,
      deviceKey: account.deviceKey || (existing?.deviceKey ?? false),
      sessionId: account.sessionId ?? existing?.sessionId,
      lastUsedAt: DateTime.now(),
      parentId: account.parentId ?? existing?.parentId,
      userId: account.userId ?? existing?.userId,
    );
    _accounts = [
      for (final a in _accounts)
        if (a.childId != account.childId && !(merged.owner && a.owner)) a,
      merged,
    ];
    if (activate) _activeId = account.childId;
    await _save();
    // Mehmon qurilma egasiga aylandi — mehmon tokenlari endi kerak emas.
    if (merged.owner && existing != null && !existing.owner) {
      await _clearGuestTokens(account.childId);
    }
  }

  /// Qurilma kalitini yoqish / o'chirish.
  Future<void> setDeviceKey(String childId, {required bool enabled}) async {
    _accounts = [
      for (final a in _accounts)
        a.childId == childId
            ? DeviceAccount(
                childId: a.childId,
                name: a.name,
                owner: a.owner,
                login: a.login,
                className: a.className,
                deviceKey: enabled,
                sessionId: a.sessionId,
                lastUsedAt: a.lastUsedAt,
                parentId: a.parentId,
                userId: a.userId,
              )
            : a,
    ];
    await _save();
  }

  /// [childId] akkauntini faol qiladi (`null` — qurilma egasi).
  Future<void> activate(String? childId) async {
    _activeId = childId;
    _accounts = [
      for (final a in _accounts)
        a.childId == childId ? a.copyWith(lastUsedAt: DateTime.now()) : a,
    ];
    await _save();
  }

  void beginReauth(String childId) => _reauth.add(childId);

  void endReauth(String childId) => _reauth.remove(childId);

  bool isReauthenticating(String childId) => _reauth.contains(childId);

  /// Mehmon akkauntdan chiqish (tokenlari o'chiriladi). Allaqachon
  /// chiqarilgan akkaunt yoki qurilma egasi uchun hech narsa qilmaydi.
  /// [notice] faqat shu akkaunt faol bo'lsa ko'rsatiladi (A12).
  Future<void> signOutGuest(
    String childId, {
    SessionClosedReason? notice,
  }) async {
    final account = accountById(childId);
    if (account == null || account.owner) return;
    final wasActive = _activeId == childId;
    await _clearGuestTokens(childId);
    _accounts = [
      for (final a in _accounts)
        if (a.childId != childId) a,
    ];
    if (wasActive) {
      _activeId = owner?.childId;
      if (notice != null) _closedNotice = notice;
    }
    await _save();
    await _clearLocalData(childId);
  }

  /// Qurilma egasining sessiyasi yopildi (juftlash bekor qilindi). Egasi
  /// bo'lmasa hech narsa qilmaydi; [notice] faqat egasi faol bo'lgan bo'lsa.
  Future<void> ownerClosed({SessionClosedReason? notice}) async {
    final current = owner;
    if (current == null) return;
    final wasActive = _activeId == null || _activeId == current.childId;
    _accounts = [
      for (final a in _accounts)
        if (!a.owner) a,
    ];
    if (wasActive) {
      _activeId = null;
      if (notice != null) _closedNotice = notice;
    }
    await _save();
    await _clearLocalData(current.childId);
  }

  void clearClosedNotice() {
    if (_closedNotice == null) return;
    _closedNotice = null;
    notifyListeners();
  }

  Future<void> _clearGuestTokens(String childId) async {
    try {
      await _guestTokens(childId).clear();
    } on Object catch (e) {
      debugPrint('[accounts] tokenlar o\'chirilmadi: ${e.runtimeType}');
    }
  }

  Future<void> _save() async {
    notifyListeners();
    if (!_loaded) return;
    try {
      await _store.write(
        _accountsKey,
        _accounts.isEmpty
            ? null
            : jsonEncode([for (final a in _accounts) a.toJson()]),
      );
      await _store.write(_activeKey, _activeId);
    } on Object catch (e) {
      debugPrint('[accounts] saqlanmadi: ${e.runtimeType}');
    }
  }
}
