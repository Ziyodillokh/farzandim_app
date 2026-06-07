// ─────────────────────────────────────────────────────────────────────
// StepCounterService — Parvoz qadam sanagich (pedometer → backend)
// ─────────────────────────────────────────────────────────────────────
//
// Android TYPE_STEP_COUNTER sensori reboot'dan beri KUMULYATIV qadamni
// beradi. Bu yerda undan KUNLIK qadamni hisoblaymiz:
//   delta = joriy_kumulyativ - oxirgi_kumulyativ  (reboot bo'lsa = joriy)
//   bugungi_qadam += delta
// Kun chegarasi Toshkent (UTC+5). Holat SharedPreferences'da saqlanadi —
// ilova qayta ochilganda yo'qolgan qadamlar delta orqali tiklanadi
// (sensor fon'da ham sanaydi). Kunlik qadam backendga periodik yuboriladi.

import 'dart:async';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepCounterService {
  StepCounterService({
    required BackendInstalledAppsRepository backendRepo,
    required String childId,
  })  : _backendRepo = backendRepo,
        _childId = childId;

  final BackendInstalledAppsRepository _backendRepo;
  final String _childId;

  static const _kLastCumulative = 'step.lastCumulative.v1';
  static const _kTodaySteps = 'step.todaySteps.v1';
  static const _kTodayDate = 'step.todayDate.v1';

  StreamSubscription<StepCount>? _sub;
  Timer? _syncTimer;
  int _lastCumulative = -1;
  int _todaySteps = 0;
  String _todayKey = '';
  DateTime? _lastSyncAt;
  bool _started = false;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Toshkent (UTC+5) kun kaliti — app-usage bilan bir xil chegarada.
  String _tashkentDayKey([DateTime? at]) {
    final d = (at ?? DateTime.now()).toUtc().add(const Duration(hours: 5));
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      debugPrint('StepCounter: ACTIVITY_RECOGNITION ruxsati yo\'q');
      _started = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _lastCumulative = prefs.getInt(_kLastCumulative) ?? -1;
    _todaySteps = prefs.getInt(_kTodaySteps) ?? 0;
    _todayKey = prefs.getString(_kTodayDate) ?? _tashkentDayKey();

    await _sub?.cancel();
    _sub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (Object e) => debugPrint('StepCounter stream xato: $e'),
      cancelOnError: false,
    );

    // Stream jim bo'lsa ham (harakatsiz) 5 daqiqada bir backendga yangilaymiz.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_sync()),
    );

    debugPrint('=== StepCounterService.start childId=$_childId ===');
  }

  Future<void> _onStep(StepCount event) async {
    final cumulative = event.steps;
    final today = _tashkentDayKey();

    // Kun almashdi — avvalgi kun yakunini yuborib, bugunni noldan boshlaymiz.
    if (today != _todayKey) {
      if (_todaySteps > 0) {
        await _sync(dateKey: _todayKey, steps: _todaySteps);
      }
      _todayKey = today;
      _todaySteps = 0;
    }

    int delta;
    if (_lastCumulative < 0) {
      delta = 0; // birinchi o'qish — faqat baseline
    } else if (cumulative >= _lastCumulative) {
      delta = cumulative - _lastCumulative;
    } else {
      delta = cumulative; // reboot — sensor noldan boshladi
    }
    _todaySteps += delta;
    _lastCumulative = cumulative;
    await _persist();

    // Throttle: 60 sekundda bir marta yuboramiz.
    if (_lastSyncAt == null ||
        DateTime.now().difference(_lastSyncAt!).inSeconds > 60) {
      await _sync();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastCumulative, _lastCumulative);
      await prefs.setInt(_kTodaySteps, _todaySteps);
      await prefs.setString(_kTodayDate, _todayKey);
    } catch (_) {}
  }

  Future<void> _sync({String? dateKey, int? steps}) async {
    _lastSyncAt = DateTime.now();
    try {
      await _backendRepo.upsertSteps(
        childId: _childId,
        entries: [
          {'date': dateKey ?? _todayKey, 'steps': steps ?? _todaySteps},
        ],
      );
    } catch (e) {
      debugPrint('StepCounter sync xato: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _syncTimer?.cancel();
    _sub = null;
    _syncTimer = null;
    _started = false;
  }
}
