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
// HC BO'LMAGAN qurilma (HONOR/Huawei) uchun ANIQ yechim: BOOT vaqtini
// (`BootTimeService`, SystemClock.elapsedRealtime) tekshiramiz. Telefon O'CHIQ
// paytda qadam sanalmaydi, shuning uchun telefon BUGUN yoqilgan bo'lsa
// "yoqilgandan beri jami" = AYNAN "bugungi jami" → cumulative'ni bugungi qadam
// deb qabul qilamiz (taxmin emas, ANIQ). Ilovadagi son telefon widjetidagi son
// bilan mos keladi (avval ilova ochilgunga qadar yurilgan qadamlar yo'qolib,
// 182 o'rniga 26 ko'rinardi).
//   • Telefon BUGUNDAN OLDIN yoqilgan bo'lsa: bugungi baseline yo'q → seed
//     qilmaymiz (over-count YO'Q), hozirdan oldinga sanaymiz; ilova yarim
//     tundan tirik bo'lsa keyingi kunlar telefon bilan aniq mos keladi.
//   • Boot vaqti aniqlanmasa (kanal yo'q): ehtiyotkor cap (`_seedFromBootMax`)
//     bilan taxminiy seed (fallback).
//
// Kun chegarasi Toshkent (UTC+5). Holat SharedPreferences'da saqlanadi —
// ilova qayta ochilganda yo'qolgan qadamlar delta orqali tiklanadi
// (sensor fon'da ham sanaydi). Kunlik qadam backendga periodik yuboriladi.

import 'dart:async';

import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/boot_time_service.dart';
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

  /// Joriy boot sessiyasidagi TYPE_STEP_COUNTER "0 qadam" nuqtasi. Bugungi
  /// qadam DOIM qayta hisoblanadi (yig'ilmaydi → self-healing):
  /// `todaySteps = baseSteps + (cumulative - dayBaseline)`. Shu sabab bitta
  /// noto'g'ri o'qish jamlanib qolmaydi va son telefon bilan o'z-o'zidan
  /// tuzalib turadi. Yangi kalit → eski o'rnatishlar avtomatik qayta hisoblaydi.
  static const _kDayBaseline = 'step.dayBaseline.v1';

  /// Bugun AVVALGI boot sessiyalarida sanalgan qadam (kun ichida reboot
  /// bo'lganda saqlanadi) — `todaySteps = baseSteps + (cumulative-dayBaseline)`.
  static const _kBaseSteps = 'step.baseSteps.v1';

  /// Bir kunlik maqbul qadam shifti (backend clamp bilan bir xil) — qadam
  /// RAQAMI shundan oshib ketmaydi.
  static const int _dayStepMax = 200000;

  /// Health Connect BO'LMAGAN qurilmada (HONOR/Huawei kabi) birinchi o'qishda
  /// TYPE_STEP_COUNTER "yoqilgandan beri jami"ni bugungi qadam deb qabul
  /// qilishning maqbul yuqori chegarasi. Telefon BUGUN qayta yoqilgan bo'lsa
  /// (odatiy holat) cumulative = bugungi qadam. Undan katta bo'lsa telefon
  /// bir necha kundan beri yoqiq — bunda seed qilmaymiz (noldan sanaymiz).
  /// ~50k = juda faol kun; realroq kunlik qadam bundan past bo'ladi.
  static const int _seedFromBootMax = 50000;

  StreamSubscription<StepCount>? _sub;
  Timer? _syncTimer;
  int _lastCumulative = -1;
  int _todaySteps = 0;

  /// Joriy boot sessiyasi baseline (yuqoridagi `_kDayBaseline`). `-1` — hali
  /// aniqlanmagan (birinchi o'qishda seed qilinadi).
  int _dayBaseline = -1;

  /// Bugun avvalgi boot sessiyalarida sanalgan qadam (reboot uchun).
  int _baseSteps = 0;
  String _todayKey = '';
  DateTime? _lastSyncAt;

  /// Oxirgi backend'ga yuborilgan qadam soni — sezilarli o'zgarishda darhol
  /// yuborish (real-time) uchun.
  int _lastSyncSteps = 0;
  bool _started = false;

  /// Health Connect bu sessiyada bugungi HAQIQIY jamini bergani. `true` bo'lsa
  /// pedometer seed'i (boot-today) qo'llanmaydi — HC ustun manba.
  bool _healthProvidedToday = false;

  /// Qurilma oxirgi marta yoqilgan (boot) vaqti — `start()`da bir marta
  /// olinadi. Boot BUGUN bo'lsa cumulative = bugungi qadam (ANIQ), aks holda
  /// seed qilinmaydi. `null` — aniqlanmadi (ehtiyotkor cap fallback ishlaydi).
  DateTime? _bootTime;

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
    _dayBaseline = prefs.getInt(_kDayBaseline) ?? -1;
    _baseSteps = prefs.getInt(_kBaseSteps) ?? 0;
    _todayKey = prefs.getString(_kTodayDate) ?? _tashkentDayKey();
    _lastSyncSteps = _todaySteps;

    // Boot vaqti — cumulative'ni bugungi qadam deb qabul qilish uchun (HC yo'q
    // qurilmada). Bir marta olamiz; xato bo'lsa null (ehtiyotkor fallback).
    // MUHIM: `_onStep` HAR o'qishda boot-today'ni tekshirib, cumulative'ni
    // to'g'ridan-to'g'ri bugungi qadam sifatida oladi (SELF-HEALING). Shu sabab
    // avvalgi bir martalik migratsiya OLIB TASHLANDI — u faqat bir marta
    // ishlab, eski o'rnatishlarda tuzatib ulgurmasdi.
    _bootTime = await BootTimeService.bootTime();

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

  /// Foreground'da (app ochilganda / qaytganda / statistika ekrani ochilganda)
  /// Health Connect'dagi HAQIQIY jamini DARHOL tortadi — 5 daqiqalik davriy
  /// sync'ni kutmasdan telefon soniga yaqinlashish uchun. Ekrandagi son
  /// foydalanuvchi qaraganda eng yangi bo'ladi. HC yo'q/ruxsatsiz bo'lsa
  /// `_syncFromHealth` jim qaytadi (pedometer jonli sanashda davom etadi).
  Future<void> syncNow() async {
    if (!_started || kIsWeb) return;
    await _syncFromHealth();
    await _sync();
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

  /// Health Connect'dagi BUGUNGI jamini telefon truth sifatida oladi va
  /// day-baseline'ni shunga ANCHOR qiladi: `dayBaseline = cumulative - hc`.
  /// Shunda `todaySteps = cumulative - dayBaseline = hc` (telefon bilan aynan),
  /// va HC sync'lar orasida pedometer jonli delta qo'shib turadi (recompute).
  /// HC yo'q/ruxsat yo'q bo'lsa hech nima qilmaydi (pedometer fallback).
  Future<void> _syncFromHealth() async {
    try {
      final hcSteps = await HealthStepsService.instance.stepsForToday();
      if (hcSteps == null) return;
      final hc = hcSteps.clamp(0, _dayStepMax);
      final today = _tashkentDayKey();
      _todayKey = today;
      // HC = telefon truth. Ekranga darhol hc'ni qo'yamiz; baseline esa
      // keyingi `_onStep`da FRESH cumulative bilan anchor qilinadi. MUHIM:
      // bu yerda _lastCumulative ESKI (fon'da yurilgan qadam qo'shilmagan)
      // bo'lishi mumkin — undan baseline hisoblasak, fon qadami ikki marta
      // sanalib son oshib ketardi. Shu sabab `_dayBaseline = -1` (defer) →
      // `_onStep` joriy cumulative bilan aniq anchor qiladi (today = hc).
      // Har HC sync son telefon soniga qaytadi, oradagi pedometer jonli qo'shadi.
      _dayBaseline = -1;
      _baseSteps = 0;
      _todaySteps = hc;
      // HC haqiqiy jamini berdi — bundan keyin boot-today seed qo'llanmaydi.
      _healthProvidedToday = true;
      await _persist();
    } catch (e) {
      debugPrint('StepCounter: Health sync xato: $e');
    }
  }

  Future<void> _onStep(StepCount event) async {
    final cumulative = event.steps;
    final today = _tashkentDayKey();

    // ── Kun almashdi — avvalgi kun yakunini yuborib, bugunni noldan
    // boshlaymiz (baseline = hozirgi cumulative, baseSteps = 0). ──
    if (today != _todayKey) {
      if (_todaySteps > 0) {
        await _sync(dateKey: _todayKey, steps: _todaySteps);
      }
      _todayKey = today;
      _dayBaseline = cumulative;
      _baseSteps = 0;
      _todaySteps = 0;
    }

    // ── Baseline hali aniqlanmagan (yangi kalit / yangi o'rnatish / HC sync
    // defer) → seed. FRESH cumulative bilan anchor qilamiz. ──
    if (_dayBaseline < 0) {
      _baseSteps = 0;
      if (_healthProvidedToday) {
        // HC bugungi sonini bergan (_todaySteps = hc) → today = hc bo'lsin.
        // cumulative >= hc: baseSteps=0, baseline = cumulative - hc.
        // cumulative < hc (fon'da reboot → pedometer tarixi kichik): HC'ga
        // ishonamiz — baseSteps = hc, baseline = cumulative (kelgusi qadam
        // qo'shiladi, HC hozirgi jamini beradi).
        if (cumulative >= _todaySteps) {
          _dayBaseline = cumulative - _todaySteps;
        } else {
          _baseSteps = _todaySteps;
          _dayBaseline = cumulative;
        }
      } else {
        // HC yo'q (HONOR/Huawei): TYPE_STEP_COUNTER "yoqilgandan beri jami".
        // Telefon O'CHIQ paytda qadam sanalmaydi → telefon BUGUN yoqilgan
        // bo'lsa cumulative = AYNAN bugungi qadam → baseline = 0.
        final bootedToday = _bootTime != null &&
            _tashkentDayKey(_bootTime) == today;
        if (bootedToday) {
          _dayBaseline = 0; // today = cumulative (ANIQ)
        } else if (_bootTime == null && cumulative <= _seedFromBootMax) {
          _dayBaseline = 0; // boot noma'lum, ehtiyotkor: cumulative deb olamiz
        } else {
          // Boot bugundan oldin → bugungi baseline noma'lum → hozirdan
          // oldinga sanaymiz (over-count yo'q; yarim tundan aniq bo'ladi).
          _dayBaseline = cumulative;
        }
      }
    }

    // ── Reboot / sensor reset: counter avvalgi o'qishdan kichik bo'lib qoldi.
    // Sanalgan bugungi qadamni `baseSteps`ga muzlatamiz va yangi sessiyani shu
    // nuqtadan boshlaymiz → qadam YO'QOLMAYDI (dayBaseline=0 bo'lsa ham). ──
    if (_lastCumulative >= 0 && cumulative < _lastCumulative) {
      _baseSteps = _todaySteps.clamp(0, _dayStepMax);
      _dayBaseline = cumulative;
    }

    // ── Bugungi qadam DOIM qayta hisoblanadi (yig'ilmaydi → self-healing). ──
    _todaySteps =
        (_baseSteps + (cumulative - _dayBaseline)).clamp(0, _dayStepMax);
    _lastCumulative = cumulative;
    await _persist();

    // ── Real-time: 5s'da bir YOKI ≥20 qadam o'zgarganda darhol yuboramiz. ──
    final elapsed = _lastSyncAt == null
        ? 999
        : DateTime.now().difference(_lastSyncAt!).inSeconds;
    final changed = (_todaySteps - _lastSyncSteps).abs();
    if (elapsed > 5 || changed >= 20) {
      await _sync();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastCumulative, _lastCumulative);
      await prefs.setInt(_kTodaySteps, _todaySteps);
      await prefs.setInt(_kDayBaseline, _dayBaseline);
      await prefs.setInt(_kBaseSteps, _baseSteps);
      await prefs.setString(_kTodayDate, _todayKey);
      // UI keshini yangilaymiz — aks holda ekranda eski son (yangi
      // o'rnatishda 0) turib qolardi.
      onStepsUpdated?.call();
    } catch (_) {}
  }

  Future<void> _sync({String? dateKey, int? steps}) async {
    _lastSyncAt = DateTime.now();
    final sent = steps ?? _todaySteps;
    try {
      await _backendRepo.upsertSteps(
        childId: _childId,
        entries: [
          {'date': dateKey ?? _todayKey, 'steps': sent},
        ],
      );
      // Backend real-time push shu POST'da yuboriladi — oxirgi yuborilgan
      // sonni eslab qolamiz (sezilarli o'zgarishda darhol qayta yuborish uchun).
      _lastSyncSteps = sent;
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
