// Kirish ma'lumotlari testlari uchun soxta repository: server holatini
// (saqlangan login, ochiq so'rovlar) o'zi yuritadi, har chaqiruvni yozib
// oladi, xato va "kutilmoqda" holatlarini boshqarish mumkin.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/features/child_credentials/data/child_credentials_repository.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';

// Sanalar atayin o'tgan oyda: "Bugun, 14:30" emas, doim "05.10.2026, 14:30"
// ko'rinadi (test sana o'tgani bilan buzilmaydi).

/// Serverda berilgan holat: bola hali kirmagan, vaqtinchalik parol amalda.
ChildCredentials pendingCredentials({
  String login = 'aziza.k24',
  CredentialsIssuer issuedBy = CredentialsIssuer.parent,
}) => ChildCredentials(
  login: login,
  issuedBy: issuedBy,
  mustChangePassword: true,
  issuedAt: DateTime(2026, 10, 5, 14, 30),
);

/// Bola kirgan, o'z parolini o'rnatgan.
ChildCredentials activeCredentials({String login = 'aziza.k24'}) =>
    ChildCredentials(
      login: login,
      issuedBy: CredentialsIssuer.parent,
      mustChangePassword: false,
      issuedAt: DateTime(2026, 10, 1, 9),
      lastLoginAt: DateTime(2026, 10, 5, 17, 45),
    );

RecoveryRequest openRecovery({
  String id = 'r-1',
  RecoveryChannel channel = RecoveryChannel.parent,
}) => RecoveryRequest(
  id: id,
  channel: channel,
  status: RecoveryStatus.received,
  createdAt: DateTime(2026, 10, 6, 8, 15),
);

class FakeCredentialsRepository extends ChildCredentialsRepository {
  FakeCredentialsRepository({this.stored, this.recovery = const []})
    : super(dio: Dio());

  /// Serverdagi holat (`null` — hali berilmagan).
  ChildCredentials? stored;
  List<RecoveryRequest> recovery;

  /// Yozuv amallari: `issue:<login|->`, `reset:<signOut>`, `reject:<id>`.
  final List<String> calls = [];
  int credentialFetches = 0;
  int recoveryFetches = 0;

  /// Vaqtinchalik parol, server har safar shuni beradi.
  String password = 'k7m2xq9p';

  /// Berilsa, tegishli chaqiruv shuni otadi.
  Exception? fetchError;
  Exception? recoveryError;
  Exception? issueError;
  Exception? resetError;
  Exception? rejectError;

  /// Berilsa, chaqiruv shu tugaguncha kutadi (yuklanmoqda/band holati).
  Completer<void>? holdFetch;
  Completer<void>? holdIssue;
  Completer<void>? holdReset;

  @override
  Future<ChildCredentials?> fetchCredentials(String childId) async {
    credentialFetches++;
    await holdFetch?.future;
    if (fetchError case final error?) throw error;
    return stored;
  }

  @override
  Future<List<RecoveryRequest>> fetchRecoveryRequests(String childId) async {
    recoveryFetches++;
    if (recoveryError case final error?) throw error;
    return recovery;
  }

  @override
  Future<IssuedCredentials> issueCredentials(
    String childId, {
    String? login,
  }) async {
    calls.add('issue:${login ?? '-'}');
    await holdIssue?.future;
    if (issueError case final error?) throw error;
    final issued = login ?? 'aziza.k24';
    stored = pendingCredentials(login: issued);
    return IssuedCredentials(login: issued, temporaryPassword: password);
  }

  @override
  Future<IssuedCredentials> resetCredentials(
    String childId, {
    required bool signOutDevices,
  }) async {
    calls.add('reset:$signOutDevices');
    await holdReset?.future;
    if (resetError case final error?) throw error;
    final current = stored ?? pendingCredentials();
    stored = ChildCredentials(
      login: current.login,
      issuedBy: current.issuedBy,
      mustChangePassword: true,
      issuedAt: current.issuedAt,
      lastLoginAt: current.lastLoginAt,
    );
    // Server ochiq so'rovlarni "tiklandi" qiladi.
    recovery = const [];
    return IssuedCredentials(login: current.login, temporaryPassword: password);
  }

  @override
  Future<void> rejectRecoveryRequest(String childId, String requestId) async {
    calls.add('reject:$requestId');
    if (rejectError case final error?) throw error;
    recovery = [
      for (final request in recovery)
        if (request.id != requestId) request,
    ];
  }
}
