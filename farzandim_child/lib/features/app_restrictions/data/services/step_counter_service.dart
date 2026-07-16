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
import 'dart:math' as math;

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
    this.onStepsUpdated,
  })  : _backendRepo = backendRepo,
        _childId = childId;

  final BackendInstalledAppsRepository _backendRepo;
  final String _childId;

  /// Bugungi qadam soni o'zgarganda chaqiriladi — UI (todayStepsProvider)
  /// keshini yangilash uchun. Aks holda Health Connect'dan kelgan haqiqiy son
  /// yozilsa ham ekranda eski (yangi o'rnatishda 0) qiymat turib qolardi.
  final void Function()? onStepsUpdated;

  static const _kLastCumulative = 'step.lastCumulative.v1';
  static const _kTodaySteps = 'step.todaySteps.v1';
  static const _kTodayDate = 'step.todayDate.v1';

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

    final prefs = await SharedPreferences.getInstance();
    _lastCumulative = prefs.getInt(_kLastCumulative) ?? -1;
    _todaySteps = prefs.getInt(_kTodaySteps) ?? 0;
    _todayKey = prefs.getString(_kTodayDate) ?? _tashkentDayKey();

    // ─── 1) HEALTH CONNECT (asosiy manba) ───
    // MUHIM: bu ACTIVITY_RECOGNITION'dan MUSTAQIL. Avval pedometer ruxsati
    // tekshirilib, yo'q bo'lsa butun servis `return` qilardi → Health Connect
    // umuman ishlamay, YANGI O'RNATISHDA qadam 0 bo'lib qolardi. Endi HC
    // birinchi va mustaqil ishga tushadi.
    await _ensureHealthPermission();
    // Bugungi HAQIQIY jamini darhol olamiz — pedometer baseline sababli
    // yo'qolgan (ilovagacha yurilgan) qadamlar shu yerda tiklanadi. Yangi
    // o'rnatishda ham darhol to'g'ri son ko'rinadi.
    await _syncFromHealth();
    await _sync();

    // ─── 2) PEDOMETER (jonli qo'shimcha / HC bo'lmasa fallback) ───
    // Faqat shu qism ACTIVITY_RECOGNITION talab qiladi. Ruxsat bo'lmasa
    // servis TO'XTAMAYDI — Health Connect va davriy sync ishlayveradi.
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      await _sub?.cancel();
      _sub = Pedometer.stepCountStream.listen(
        _onStep,
        onError: (Object e) => debugPrint('StepCounter stream xato: $e'),
        cancelOnError: false,
      );
    } else {
      debugPrint(
        "StepCounter: ACTIVITY_RECOGNITION yo'q — faqat Health Connect",
      );
    }

    // Stream jim bo'lsa ham (harakatsiz) 5 daqiqada bir: Health Connect'dan
    // haqiqiy jamini olib, keyin backendga yangilaymiz.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _syncFromHealth();
      await _sync();
    });

    debugPrint('=== StepCounterService.start childId=$_childId ===');
  }

  /// Health Connect qadam o'qish ruxsatini ta'minlaydi.
  ///
  /// Ruxsat berilmagunicha HAR ishga tushishda so'raladi. Avval `_kHcAsked`
  /// bayrog'i bor edi va u so'rashdan OLDIN yoqilardi: foydalanuvchi ruxsatni
  /// bir marta rad etsa (yoki oyna ochilmay qolsa) Health Connect ABADIY
  /// o'chib qolardi — qayta so'raydigan yo'l umuman yo'q edi. Natijada qadam
  /// doim pedometerdan kelardi va telefondagi sondan kam ko'rinardi
  /// (telefonda 932, ilovada ~200).
  ///
  /// `start()` ilova ishga tushganda bir marta chaqiriladi, shuning uchun bu
  /// eng ko'pi bilan sessiyaga bitta so'rov. Ruxsat berilgach Health Connect
  /// oynasi umuman chiqmaydi (`hasPermission` darhol `true`).
  Future<void> _ensureHealthPermission() async {
    final hc = HealthStepsService.instance;
    try {
      if (!await hc.isAvailable()) return;
      if (await hc.hasPermission()) return;
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
      final hc = hcSteps.clamp(0, _dayStepMax);
      final today = _tashkentDayKey();
      final sameDay = today == _todayKey;
      // Kun almashgan bo'lsa kalitni ham yangilaymiz (HC allaqachon yangi
      // kunning jamini beradi).
      _todayKey = today;
      // Kun ICHIDA qadam faqat oshadi. Samsung Health ma'lumotni Health
      // Connect'ga kechikib yozadi (~10 daqiqa), shuning uchun HC soni
      // pedometer qo'shib ulgurgan jonli qadamdan ORQADA bo'lishi mumkin —
      // to'g'ridan-to'g'ri yozsak ekrandagi son kamayib, keyin yana oshib
      // sakrardi. Kun ALMASHGANDA esa HC yangi kunning (kichik) sonini
      // beradi — o'shanda to'g'ridan-to'g'ri yozamiz.
      _todaySteps = sameDay ? math.max(hc, _todaySteps) : hc;
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
      // UI keshini yangilaymiz — aks holda ekranda eski son (yangi
      // o'rnatishda 0) turib qolardi.
      onStepsUpdated?.call();
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
