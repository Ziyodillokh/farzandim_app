// ─────────────────────────────────────────────────────────────────────
// StepCounterService — Parvoz qadam sanagich (Health Connect + pedometer)
// ─────────────────────────────────────────────────────────────────────
//
// MANBALAR (muhimlik tartibida):
//  1. HEALTH CONNECT — bugungi JAMI qadam (telefon o'zi ko'rsatadigan son;
//     Samsung Health ham shu yerga yozadi). Har sync'da haqiqat manbai
//     sifatida olinadi → ilovadagi son telefondagi son bilan MOS keladi.
//  2. PEDOMETER (TYPE_STEP_COUNTER) — reboot'dan beri kumulyativ. Health
//     Connect o'qishlari orasida JONLI qo'shimcha beradi (delta), va HC
//     bo'lmagan/ruxsat berilmagan qurilmada yagona manba (fallback).
//
// NEGA: pedometer faqat "yoqilgandan beri jami"ni beradi — ilova kuzatuvni
// boshlagunga qadar bugun yurilgan qadamlarni tiklab bo'lmaydi (telefonda
// 932, ilovada 200 ko'rinardi). Health Connect butun kunni beradi.
//
// Kun chegarasi Toshkent (UTC+5). Holat SharedPreferences'da saqlanadi —
// ilova qayta ochilganda yo'qolgan qadamlar delta orqali tiklanadi
// (sensor fon'da ham sanaydi). Kunlik qadam backendga periodik yuboriladi.

import 'dart:async';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/health_steps_service.dart';
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

  /// Health Connect ruxsati bir marta so'ralgani — har start'da qayta
  /// so'rab foydalanuvchini bezovta qilmaslik uchun.
  static const _kHcAsked = 'step.hcAsked.v1';

  /// Bir kunlik maqbul qadam shifti (backend clamp bilan bir xil) — qadam
  /// RAQAMI shundan oshib ketmaydi.
  static const int _dayStepMax = 200000;

  /// Sensor "kamaydi" (reboot/glitch) holatida BITTA o'qishda qo'shiladigan
  /// maksimum. Haqiqiy reboot'da `cumulative` = boot'dan beri qadam (kichik).
  /// Glitch'da esa `cumulative` hali katta bo'lishi mumkin — uni butunlay
  /// qo'shsak qadam soni keskin noto'g'ri sakrardi.
  static const int _rebootAddMax = 60000;

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

    // Web'da Pedometer va ACTIVITY_RECOGNITION mavjud emas — jim chiqamiz.
    if (kIsWeb) {
      _started = false;
      return;
    }

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

    // Health Connect ruxsatini BIR MARTA so'raymiz (keyin qayta bezovta
    // qilmaymiz). Berilsa — bugungi jami telefonникi bilan mos bo'ladi.
    await _ensureHealthPermission(prefs);
    // Darhol bugungi HAQIQIY jamini olamiz — pedometer baseline sababli
    // yo'qolgan (ilovagacha yurilgan) qadamlar shu yerda tiklanadi.
    await _syncFromHealth();

    await _sub?.cancel();
    _sub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (Object e) => debugPrint('StepCounter stream xato: $e'),
      cancelOnError: false,
    );

    // Stream jim bo'lsa ham (harakatsiz) 5 daqiqada bir: Health Connect'dan
    // haqiqiy jamini olib, keyin backendga yangilaymiz.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _syncFromHealth();
      await _sync();
    });

    debugPrint('=== StepCounterService.start childId=$_childId ===');
  }

  /// Health Connect ruxsatini bir marta so'raydi (`_kHcAsked` bayrog'i bilan).
  /// Rad etilsa/HC bo'lmasa — jim, pedometer fallback ishlaydi.
  Future<void> _ensureHealthPermission(SharedPreferences prefs) async {
    final hc = HealthStepsService.instance;
    try {
      if (!await hc.isAvailable()) return;
      if (await hc.hasPermission()) return;
      if (prefs.getBool(_kHcAsked) ?? false) return;
      await prefs.setBool(_kHcAsked, true);
      await hc.requestPermission();
    } catch (e) {
      debugPrint('StepCounter: Health ruxsat xato: $e');
    }
  }

  /// Health Connect'dagi BUGUNGI jamini `_todaySteps`ga yozadi — bu telefon
  /// (Samsung) ko'rsatadigan son. HC yo'q/ruxsat yo'q bo'lsa hech nima
  /// qilmaydi va pedometer hisobi saqlanadi (fallback).
  Future<void> _syncFromHealth() async {
    try {
      final hcSteps = await HealthStepsService.instance.stepsForToday();
      if (hcSteps == null) return;
      // Kun almashgan bo'lsa kalitni ham yangilaymiz (HC allaqachon yangi
      // kunning jamini beradi).
      _todayKey = _tashkentDayKey();
      _todaySteps = hcSteps.clamp(0, _dayStepMax);
      await _persist();
    } catch (e) {
      debugPrint('StepCounter: Health sync xato: $e');
    }
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
      // Sensor kamaydi: reboot (0'dan boshladi) YOKI glitch. Reboot'da
      // `cumulative` = boot'dan beri qadam (kichik) → qo'shamiz. Glitch'da
      // `cumulative` hali katta bo'lishi mumkin — butunlay qo'shsak qadam
      // RAQAMI keskin noto'g'ri sakrardi, shuning uchun maqbul chegaradan
      // oshsa qo'shmaymiz, faqat baseline'ni tiklaymiz.
      delta = cumulative <= _rebootAddMax ? cumulative : 0;
    }
    // Kunlik shift — glitch/xatolar qadam RAQAMINI 96k+ ga sakratmasin.
    _todaySteps = (_todaySteps + delta).clamp(0, _dayStepMax);
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
