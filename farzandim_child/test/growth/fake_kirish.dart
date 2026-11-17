// Kirish (A01–A12) testlari va skrinshotlari uchun soxta manbalar.

import 'dart:async';

import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_device.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeKirishRepository implements KirishRepository {
  FakeKirishRepository({
    this.loginResult,
    this.loginError,
    this.linkResult = LinkStatus.none,
    this.linkError,
    this.status = LinkStatus.none,
    this.recovery,
  });

  LoginResult? loginResult;
  KirishException? loginError;
  KirishException? setupError;
  LinkStatus linkResult;
  KirishException? linkError;

  /// Berilsa — maktab kodi so'rovi shu tugaguncha «yo'lda» turadi.
  Completer<void>? linkGate;
  LinkStatus status;
  RecoveryStatus? recovery;
  KirishException? recoveryError;
  KirishException? statusError;
  KirishException? correctionError;
  KirishException? passwordError;

  /// Muvaffaqiyatli parol almashtirishlar: (joriy, yangi).
  final passwordChanges = <(String, String)>[];

  final logins = <String>[];
  final setups = <String>[];
  final recoveries = <String>[];

  /// Tiklash holati necha marta so'ralgani (A04).
  var statusChecks = 0;
  final codes = <String>[];
  final corrections = <String>[];
  final profiles = <({int? age, String gender, EducationLanguage language})>[];
  var loggedOut = false;

  static ChildSession session({
    String childId = 'child-9',
    String name = 'Jasur Karimov',
    DeviceRole role = DeviceRole.secondary,
  }) => ChildSession(
    accessToken: 'access-$childId',
    refreshToken: 'refresh-$childId',
    childId: childId,
    childName: name,
    sessionId: 'sid-$childId',
    role: role,
    parentId: 'parent-1',
  );

  @override
  Future<LoginResult> login({
    required String login,
    required String password,
    required DeviceDescriptor device,
  }) async {
    logins.add(login);
    if (loginError != null) throw loginError!;
    return loginResult ?? LoginOk(session());
  }

  @override
  Future<ChildSession> completeSetup({
    required String setupToken,
    required String newPassword,
    required DeviceDescriptor device,
  }) async {
    setups.add(newPassword);
    if (setupError != null) throw setupError!;
    return session();
  }

  /// Soxta server bergan tiklash chiptasi (kanal so'rovdagidek).
  static final recoveryTicket = RecoveryTicket(
    requestId: 'rq-1',
    pollToken: 'poll-1',
    channel: RecoveryChannel.parent,
    createdAt: DateTime(2026, 11, 5, 9, 41),
  );

  @override
  Future<RecoveryTicket> requestRecovery({
    required String login,
    required RecoveryChannel channel,
  }) async {
    recoveries.add(login);
    if (recoveryError != null) throw recoveryError!;
    return RecoveryTicket(
      requestId: recoveryTicket.requestId,
      pollToken: recoveryTicket.pollToken,
      channel: channel,
      createdAt: recoveryTicket.createdAt,
    );
  }

  @override
  Future<RecoveryStatus> recoveryStatus(RecoveryTicket ticket) async {
    statusChecks++;
    if (statusError != null) throw statusError!;
    return recovery ??
        RecoveryStatus(
          state: RecoveryState.received,
          createdAt: DateTime(2026, 11, 5, 9, 41),
        );
  }

  @override
  Future<String?> parentIdOf(String childId) async => 'parent-1';

  @override
  Future<LinkStatus> linkSchool(String code) async {
    codes.add(code);
    await linkGate?.future;
    if (linkError != null) throw linkError!;
    status = linkResult;
    return linkResult;
  }

  @override
  Future<LinkStatus> linkStatus() async => status;

  @override
  Future<void> requestCorrection({
    required String note,
    required String clientRequestId,
  }) async {
    corrections.add(clientRequestId);
    if (correctionError != null) throw correctionError!;
  }

  @override
  Future<void> saveProfile({
    required int? age,
    required String gender,
    required EducationLanguage language,
  }) async => profiles.add((age: age, gender: gender, language: language));

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final error = passwordError;
    if (error != null) throw error;
    passwordChanges.add((current, next));
  }

  @override
  Future<void> logout() async => loggedOut = true;
}

class MemoryAccountStore implements AccountStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class FakeDeviceKey implements DeviceKey {
  FakeDeviceKey({this.available = true, this.allow = true});

  bool available;
  bool allow;
  var asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> confirm(String reason) async {
    asked++;
    return allow;
  }

  /// Telefonda ekran qulfi bor.
  bool secure = true;
  var deviceAsked = 0;

  @override
  Future<bool> isDeviceSecure() async => secure;

  @override
  Future<bool> confirmDevice(String reason) async {
    deviceAsked++;
    return allow;
  }
}

/// Qurilma egasi hali yo'q (yangi o'rnatish) — `restoreFromRecovery` yoziladi.
class FakeOwnerPairing extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  FakeOwnerPairing({bool paired = false})
    : super(
        paired
            ? const AppPairingState(
                status: PairingStatus.paired,
                parentUid: 'parent-1',
                childId: 'child-1',
                childName: 'Aziza Karimova',
              )
            : const AppPairingState(),
      );

  final restored = <String>[];
  var sessionNoticeCleared = false;

  @override
  Future<void> restoreFromRecovery({
    required String parentUid,
    required String childId,
    required String childName,
    String? currentUserId,
  }) async {
    restored.add(childId);
    // Haqiqiy PairingNotifier kabi juftlash sozlamalarini yozadi.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parentUid', parentUid);
    await prefs.setString('childId', childId);
    await prefs.setString('childName', childName);
    state = AppPairingState(
      status: PairingStatus.paired,
      parentUid: parentUid,
      childId: childId,
      childName: childName,
    );
  }

  @override
  void clearSessionEndedNotice() => sessionNoticeCleared = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const kTestDevice = DeviceDescriptor(
  id: 'install-1',
  platform: 'android',
  model: 'Galaxy A15',
);

List<Override> kirishOverrides({
  required FakeKirishRepository repo,
  required AccountRegistry registry,
  FakeDeviceKey? deviceKey,
}) => [
  kirishRepositoryProvider.overrideWithValue(repo),
  accountRegistryProvider.overrideWithValue(registry),
  deviceDescriptorProvider.overrideWith((ref) async => kTestDevice),
  deviceKeyProvider.overrideWithValue(deviceKey ?? FakeDeviceKey()),
];
