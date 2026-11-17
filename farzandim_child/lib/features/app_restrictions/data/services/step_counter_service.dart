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
// (sensor fon'da ham sanaydi). Batareya: holat ko'pi bilan 60 s da bir
// (va to'xtashda) yoziladi, backend'ga ko'pi bilan 5 daqiqada bir va faqat
// son o'zgarganda yuboriladi; davriy taymer yo'q (BackgroundJobs tick'i
// `syncIfDue`, ilova ochilishi `syncNow`).

import 'dart:async';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_installed_apps_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/boot_time_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/health_steps_service.dart';
import 'package:farzandim_child/features/background/data/services/job_timing.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepCounterService {
  StepCounterService({
    required BackendInstalledAppsRepository backendRepo,
    required String childId,
    this.onStepsUpdated,
  }) : _backendRepo = backendRepo,
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

  /// Holat prefs'ga ko'pi bilan shu oraliqda (har yozuv — butun fayl + fsync).
  static const _persistInterval = Duration(seconds: 60);

  /// Backend'ga ko'pi bilan shu oraliqda yuboriladi (kun yakuni bundan mustasno).
  static const _postInterval = Duration(minutes: 5);

  StreamSubscription<StepCount>? _sub;

  Timer? _persistTimer; // bir martalik (davriy taymer yo'q)
  Timer? _postTimer;
  DateTime? _lastPersistAt;
  DateTime? _lastHealthAt;
  bool _isDirty = false;
  bool _hasSyncedOnce = false;
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

  /// Health Connect bu sessiyada bugungi HAQIQIY (noldan katta) jamini bergani.
  /// `true` bo'lsa pedometer seed'i (boot-today) qo'llanmaydi — HC ustun manba.
  bool _healthProvidedToday = false;

  /// Health Connect O'QILDI (ruxsat bor, javob keldi) — qiymati 0 bo'lsa ham.
  ///
  /// ⚠️ Nega alohida: avval faqat `_healthProvidedToday` bor edi va u FAQAT
  /// `hc > _todaySteps` shartining ICHIDA `true` bo'lardi. Samsung'da HC BOR,
  /// lekin Samsung Health → Health Connect sinxronizatsiyasi yoqilmagan bo'lsa
  /// `hc = 0` keladi → bayroq `false` qolib, kod qurilmani "HC YO'Q (Honor)"
  /// deb hisoblardi va pastdagi xavfli boot-seed tarmog'iga tushardi:
  /// Samsung sensori reboot'da nolga TUSHMAGANI uchun `cumulative` yuz minglab
  /// bo'lib, qadam 200 000 ga sakrardi yoki (boot eski bo'lsa) faqat
  /// o'rnatilgan lahzadan sanalib, telefondagi sondan ancha kam chiqardi.
  bool _healthReadableToday = false;

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
    _lastPersistAt = DateTime.now();

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
    _lastHealthAt = DateTime.now();
    await _syncFromHealth();
    await _sync();

    // ─── 2) PEDOMETER (jonli qo'shimcha / HC bo'lmasa fallback) ───
    // Faqat shu qism ACTIVITY_RECOGNITION talab qiladi. Ruxsat bo'lmasa
    // servis TO'XTAMAYDI — Health Connect va davriy sync ishlayveradi.
    // iOS'da activityRecognition yo'q — CoreMotion `sensors` (faqat holat,
    // so'rov ruxsatlar ekranida).
    final status = PlatformCapabilities.isIOS
        ? await Permission.sensors.status
        : await Permission.activityRecognition.request();
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

    // Davriy taymer YO'Q: Health Connect'ni BackgroundJobs tick'i
    // (`syncIfDue`) va ilova ochilishi (`syncNow`) yangilaydi; pedometer
    // qadamlari bir martalik taymer bilan ko'pi bilan 5 daqiqada yuboriladi.
    debugPrint('=== StepCounterService.start childId=$_childId ===');
  }

  /// Foreground'da (app ochilganda / qaytganda / statistika ekrani) Health
  /// Connect'dagi HAQIQIY jamini DARHOL tortadi (HC yo'q — jim). Son
  /// o'zgarmagan bo'lsa backend'ga yuborilmaydi.
  Future<void> syncNow() async {
    if (!_started || kIsWeb) return;
    _lastHealthAt = DateTime.now();
    await _syncFromHealth();
    await _sync();
  }

  /// BackgroundJobs tick'i: oxirgi o'qishdan ≥ 5 daqiqa o'tgan bo'lsa Health
  /// Connect'dan o'qib, son o'zgargan bo'lsa yuboradi.
  Future<void> syncIfDue() async {
    if (!_started || kIsWeb) return;
    final now = DateTime.now();
    if (!isDue(_lastHealthAt, now, _postInterval)) return;
    _lastHealthAt = now;
    await _syncFromHealth();
    if (isDue(_lastSyncAt, now, _postInterval)) await _sync();
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
  ///
  /// iOS'da bu yerda SO'RALMAYDI — Motion ruxsati ruxsatlar ekranida (izoh
  /// bilan) so'raladi; ishga tushishda kontekstsiz tizim oynasi chiqmasin.
  Future<void> _ensureHealthPermission() async {
    if (PlatformCapabilities.isIOS) return;
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
      if (hcSteps == null) return; // HC yo'q/ruxsatsiz — pedometer davom etadi
      final hc = hcSteps.clamp(0, _dayStepMax);
      final today = _tashkentDayKey();

      // Kun almashgan bo'lsa: avvalgi kun yakunini backendga yuborib, bugunni
      // noldan boshlaymiz. Aks holda quyidagi taqqoslash eski kunning KATTA
      // soni bilan bo'lib, bugungi kichik HC qabul qilinmay qolardi.
      if (today != _todayKey) {
        if (_todaySteps > 0) {
          await _sync(dateKey: _todayKey, steps: _todaySteps);
        }
        _todayKey = today;
        _dayBaseline = -1;
        _baseSteps = 0;
        _todaySteps = 0;
        _healthProvidedToday = false;
        _healthReadableToday = false;
      }

      // HC javob berdi (ruxsat bor) — qiymati 0 bo'lsa ham buni belgilaymiz.
      // Bu qurilmada Health Connect BOR degani; pastdagi pedometer seed'i
      // "HC yo'q qurilma" tarmog'iga tushmasligi uchun kritik.
      _healthReadableToday = true;

      // HEALTH CONNECT — hc > 0 bo'lsa TELEFON HAQIQATI deb qabul qilamiz
      // (pasaytirishga ham ruxsat), chunki foydalanuvchi telefonida aynan shu
      // sonni ko'radi va bizning vazifamiz unga MOS KELISH.
      //
      // ⚠️ hc == 0 — ALOHIDA holat: Samsung'da HC bor, lekin Samsung Health
      // qadam sinxronizatsiyasi yoqilmagan bo'lsa 0 keladi. Bunda pedometer
      // sanog'ini SAQLAYMIZ (aks holda har sync'da qadam 0 ga tushardi —
      // avvalgi regressiya). Ya'ni: 0 hech qachon pasaytirmaydi, musbat
      // qiymat esa har doim haqiqat.
      if (hc > 0 && hc != _todaySteps) {
        // baseline defer → keyingi `_onStep` FRESH cumulative bilan anchor
        // qiladi (today = hc), so'ng pedometer jonli delta qo'shib boradi.
        _dayBaseline = -1;
        _baseSteps = 0;
        _todaySteps = hc;
        _healthProvidedToday = true;
        await _persist();
      } else if (hc > 0) {
        _healthProvidedToday = true;
      }
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
      } else if (_healthReadableToday) {
        // HC BOR, lekin bugun 0 qaytardi (Samsung Health → Health Connect
        // sinxronizatsiyasi yoqilmagan). Boot-seed QILMAYMIZ: Samsung
        // sensori reboot'da nolga tushmasligi mumkin va `cumulative` yuz
        // minglab bo'lib, qadam 200 000 ga sakrardi. Xavfsiz yo'l — hozirdan
        // oldinga sanash; HC keyinroq ma'lumot bersa yuqoridagi anchor uni
        // to'g'rilaydi.
        _dayBaseline = cumulative;
      } else {
        // HC YO'Q qurilma (HONOR/Huawei): TYPE_STEP_COUNTER "yoqilgandan beri
        // jami". Telefon O'CHIQ paytda qadam sanalmaydi → telefon BUGUN
        // yoqilgan bo'lsa cumulative = AYNAN bugungi qadam → baseline = 0.
        final bootedToday =
            _bootTime != null && _tashkentDayKey(_bootTime) == today;
        // Ishonchlilik tekshiruvi: boot'dan beri o'tgan soatlarda jismonan
        // mumkin bo'lgan maksimal qadam. Sensor reboot'da nolga tushmagan
        // bo'lsa (ba'zi Samsung/Xiaomi) cumulative bu chegaradan oshadi va
        // biz uni "bugungi qadam" deb qabul qilmaymiz.
        final hoursSinceBoot = _bootTime == null
            ? 0
            : DateTime.now().difference(_bootTime!).inHours + 1;
        final plausibleMax = (hoursSinceBoot * 2000).clamp(0, _seedFromBootMax);
        if (bootedToday && cumulative <= plausibleMax) {
          _dayBaseline = 0; // today = cumulative (ANIQ)
        } else if (_bootTime == null && cumulative <= _seedFromBootMax) {
          _dayBaseline = 0; // boot noma'lum, ehtiyotkor: cumulative deb olamiz
        } else {
          // Boot bugundan oldin YOKI cumulative ishonchsiz katta → hozirdan
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
    _todaySteps = (_baseSteps + (cumulative - _dayBaseline)).clamp(
      0,
      _dayStepMax,
    );
    _lastCumulative = cumulative;

    // ── Har qadamda disk/tarmoq YO'Q (60 s / 5 daq cheklovi). ──
    _schedulePersist();
    _schedulePost();
  }

  void _schedulePersist() {
    _isDirty = true;
    _persistTimer = _throttle(
      _persistTimer,
      _lastPersistAt,
      _persistInterval,
      _persist,
    );
  }

  void _schedulePost() {
    if (_todaySteps == _lastSyncSteps) return;
    _postTimer = _throttle(_postTimer, _lastSyncAt, _postInterval, _sync);
  }

  /// [last] dan [interval] o'tgan bo'lsa darhol, aks holda qolgan vaqtdan
  /// keyin bir marta (kutayotgan taymer bo'lsa — o'sha).
  static Timer? _throttle(
    Timer? pending,
    DateTime? last,
    Duration interval,
    Future<void> Function() run,
  ) {
    if (pending != null) return pending;
    final wait = last == null
        ? Duration.zero
        : interval - DateTime.now().difference(last);
    if (wait <= Duration.zero) {
      unawaited(run());
      return null;
    }
    return Timer(wait, () => unawaited(run()));
  }

  Future<void> _persist({bool notify = true}) async {
    _persistTimer?.cancel();
    _persistTimer = null;
    _lastPersistAt = DateTime.now();
    _isDirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastCumulative, _lastCumulative);
      await prefs.setInt(_kTodaySteps, _todaySteps);
      await prefs.setInt(_kDayBaseline, _dayBaseline);
      await prefs.setInt(_kBaseSteps, _baseSteps);
      await prefs.setString(_kTodayDate, _todayKey);
      // UI keshini yangilaymiz — aks holda ekranda eski son (yangi
      // o'rnatishda 0) turib qolardi.
      if (notify) onStepsUpdated?.call();
    } catch (_) {}
  }

  /// Backend'ga yuborish. [dateKey] — o'tgan kun yakuni (doim yuboriladi);
  /// aks holda son o'zgarmagan bo'lsa (birinchi yuborishdan keyin) POST yo'q.
  Future<void> _sync({String? dateKey, int? steps}) async {
    _postTimer?.cancel();
    _postTimer = null;
    final sent = steps ?? _todaySteps;
    final isDayFinal = dateKey != null;
    if (!isDayFinal && _hasSyncedOnce && sent == _lastSyncSteps) return;
    _lastSyncAt = DateTime.now();
    try {
      final ok = await _backendRepo.upsertSteps(
        childId: _childId,
        entries: [
          {'date': dateKey ?? _todayKey, 'steps': sent},
        ],
      );
      // Backend real-time push shu POST'da yuboriladi — oxirgi yuborilgan
      // sonni eslab qolamiz (o'zgarmagan son qayta yuborilmaydi).
      if (ok && !isDayFinal) {
        _lastSyncSteps = sent;
        _hasSyncedOnce = true;
      }
    } catch (e) {
      debugPrint('StepCounter sync xato: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    _postTimer?.cancel();
    _postTimer = null;
    // To'xtashda yozilmagan holat saqlanadi (UI keshi yangilanmaydi).
    if (_isDirty) unawaited(_persist(notify: false));
    _started = false;
  }
}
