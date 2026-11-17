// Test yordamchisi: tarmoqsiz soxta backend repository'lari.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_unlock_request_repository.dart';
import 'package:farzandim_child/features/schedules/data/models/schedule.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_routine_repository.dart';
import 'package:farzandim_child/features/schedules/data/repositories/backend_schedule_repository.dart';

/// Barcha soxta repo'lar umumiy "darvoza"ni kutadi — bir vaqtdagi
/// so'rovlarni sinash uchun.
class FetchGate {
  Completer<void>? _gate;

  void close() => _gate = Completer<void>();

  void open() {
    _gate?.complete();
    _gate = null;
  }

  Future<void> pass() async {
    final gate = _gate;
    if (gate != null) await gate.future;
  }
}

class FakeScheduleRepo extends BackendScheduleRepository {
  FakeScheduleRepo(this.gate) : super(dio: Dio());

  final FetchGate gate;
  List<AppSchedulePolicy>? result = const [];
  int calls = 0;

  @override
  Future<List<AppSchedulePolicy>?> getSchedules(String childId) async {
    calls++;
    await gate.pass();
    return result;
  }
}

class FakeAppLimitRepo extends BackendAppLimitRepository {
  FakeAppLimitRepo(this.gate) : super(dio: Dio());

  final FetchGate gate;
  List<AppLimit>? result = const [];

  @override
  Future<List<AppLimit>?> getLimits(String childId) async {
    await gate.pass();
    return result;
  }
}

class FakeRoutineRepo extends BackendRoutineRepository {
  FakeRoutineRepo(this.gate) : super(dio: Dio());

  final FetchGate gate;
  List<Schedule>? result = const [];

  @override
  Future<List<Schedule>?> getRoutines(String childId) async {
    await gate.pass();
    return result;
  }
}

class FakeDevicePolicyRepo extends BackendDevicePolicyRepository {
  FakeDevicePolicyRepo() : super(dio: Dio());

  ({bool? blockUnknownSources, bool? blockAllApps, bool? blockUninstall})
  result = (
    blockUnknownSources: false,
    blockAllApps: false,
    blockUninstall: null,
  );
  bool reportOk = true;
  int reports = 0;

  @override
  Future<
    ({bool? blockUnknownSources, bool? blockAllApps, bool? blockUninstall})
  >
  getDevicePolicy(String childId) async => result;

  @override
  Future<bool> reportUninstallGuardDisabled(String childId) async {
    reports++;
    return reportOk;
  }
}

class FakeUnlockRepo extends BackendUnlockRequestRepository {
  FakeUnlockRepo() : super(dio: Dio());

  List<ActiveUnlockGrant>? result = const [];

  @override
  Future<List<ActiveUnlockGrant>?> getActiveGrants() async => result;
}

AppLimit fullBlock(String pkg) =>
    AppLimit(id: pkg, packageName: pkg, dailyLimitMs: 0);

AppLimit timeLimit(String pkg, int minutes) =>
    AppLimit(id: pkg, packageName: pkg, dailyLimitMs: minutes * 60000);
