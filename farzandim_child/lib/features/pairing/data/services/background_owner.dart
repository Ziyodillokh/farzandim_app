// ─────────────────────────────────────────────────────────────────────
// BackgroundOwner — fon ishlarining YAGONA egasi (UI isolate tomoni)
// ─────────────────────────────────────────────────────────────────────
//
// 1.0.20 qoidasi — bitta ishning bitta egasi:
//   • Android, foreground service (FGS) ishlayapti → heartbeat, cheklovlar
//     sinxroni, usage, joylashuv va qadamlarni FAQAT FGS isolate'i bajaradi.
//     UI isolate hech narsa boshlamaydi: WS/FCM triggerlarini
//     `sendDataToTask('parvoz:…')` bilan FGS'ga uzatadi.
//   • FGS ishlamayapti (yoki iOS) → UI isolate bitta BackgroundJobs'ga ega:
//     5 daqiqalik tik + ilova qaytishi (resume); internet qaytishini
//     BackgroundJobs o'zi kuzatadi. FGS keyinroq ishga tushsa — UI nusxasi
//     darhol to'xtatiladi (dublikat yo'q).
//   • Har tikda FGS tekshiriladi: OEM o'ldirgan bo'lsa qayta yoqiladi
//     (himoyalangan), yoqilmasa ishni UI o'z qo'liga oladi.
//
// Platforma (FGS, native RestrictionService) va BackgroundJobs tashqaridan
// beriladi — mantiq plaginlarsiz, testlarda soxtalari bilan tekshiriladi.
// Hech bir metod xato tashlamaydi: fon ishlari UI oqimini yiqitmasin.

import 'dart:async';

import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:flutter/foundation.dart';

/// Fon ishlari uchun bitta davriy tik (dizayn: 5 daqiqa, polling yo'q).
const kBackgroundTickInterval = Duration(minutes: 5);

/// Juftlangan bola — fon ishlari shu sessiya uchun.
@immutable
class BackgroundSession {
  const BackgroundSession({
    required this.childId,
    required this.parentUid,
    required this.childName,
  });

  final String childId;
  final String parentUid;
  final String childName;

  @override
  bool operator ==(Object other) =>
      other is BackgroundSession &&
      other.childId == childId &&
      other.parentUid == parentUid &&
      other.childName == childName;

  @override
  int get hashCode => Object.hash(childId, parentUid, childName);
}

/// UI isolate ishlatadigan BackgroundJobs (C1b) yuzasi — adapter orqali.
abstract interface class BackgroundJobsHandle {
  Future<void> start();
  Future<void> stop();
  Future<void> onTick();
  Future<void> onScreenOn();
  Future<void> onMessage(String type);
  Future<void> onConnectivityRestored();
}

typedef BackgroundJobsFactory =
    BackgroundJobsHandle Function(BackgroundSession session);

/// Android fon infratuzilmasi (iOS'da ishlatilmaydi).
abstract interface class BackgroundPlatform {
  /// Foreground service ishlayaptimi.
  Future<bool> isServiceRunning();

  /// FGS'ni ishga tushiradi — idempotent, xatoni o'zi yutadi.
  Future<void> startService();

  /// FGS isolate'iga xabar (`ParvozMessages`).
  void sendToService(String message);

  /// Native RestrictionService (usage ruxsati bo'lsa) — idempotent.
  Future<void> startEnforcement();
}

class BackgroundOwner {
  BackgroundOwner({
    required bool usesForegroundService,
    required BackgroundPlatform platform,
    required BackgroundJobsFactory createJobs,
    Future<void> Function()? syncRestrictionsInUi,
    Duration tickInterval = kBackgroundTickInterval,
  }) : _usesForegroundService = usesForegroundService,
       _platform = platform,
       _createJobs = createJobs,
       _syncRestrictionsInUi = syncRestrictionsInUi,
       _tickInterval = tickInterval;

  final bool _usesForegroundService;
  final BackgroundPlatform _platform;
  final BackgroundJobsFactory _createJobs;

  /// FGS'siz platformada (iOS) cheklovlar shu yo'l bilan sinxronlanadi
  /// (IosRestrictionsSyncService) — BackgroundJobs'ga emas.
  final Future<void> Function()? _syncRestrictionsInUi;
  final Duration _tickInterval;

  BackgroundSession? _session;
  BackgroundJobsHandle? _jobs;
  Timer? _ticker;
  bool _isDisposed = false;

  /// Egalik qarorlari ketma-ket (attach/detach/tik/resume aralashmasin).
  Future<void> _queue = Future<void>.value();

  BackgroundSession? get session => _session;

  /// UI isolate o'zi fon ishlarini bajaryaptimi (FGS yo'q payt yoki iOS).
  bool get ownsJobs => _jobs != null;

  /// Juftlangan bola uchun fon ishlarini boshlaydi: Android'da FGS va native
  /// bloklash darhol yoqiladi (keyingi sovuq startni kutmasdan), keyin kim
  /// egalik qilishi hal qilinadi. Bir xil sessiya bilan qayta chaqirish —
  /// faqat [ensureRunning] (dublikat ishlar yo'q).
  Future<void> attach(BackgroundSession session) => _serial(() async {
    if (_isDisposed) return;
    if (_session != session) {
      await _releaseJobs();
      _session = session;
      _ticker?.cancel();
      _ticker = Timer.periodic(_tickInterval, (_) => unawaited(tick()));
    }
    await _ensure(withEnforcement: true);
  });

  /// Uzish: tik to'xtaydi, UI isolate'dagi ishlar yopiladi.
  Future<void> detach() => _serial(() async {
    _session = null;
    _ticker?.cancel();
    _ticker = null;
    await _releaseJobs();
  });

  /// Ruxsat berilgach / ilova qaytganda: FGS + native bloklash (idempotent)
  /// va egalik qayta hal qilinadi.
  Future<void> ensureRunning() => _serial(() => _ensure(withEnforcement: true));

  /// 5 daqiqalik tik: o'ldirilgan FGS qayta yoqiladi; UI egasi bo'lsa —
  /// BackgroundJobs.onTick (ichida "vaqti keldimi" tekshiruvlari).
  @visibleForTesting
  Future<void> tick() => _serial(() async {
    if (_session == null) return;
    final isNewJobs = await _ensure(withEnforcement: false);
    // Yangi yaratilgan ishlar start()'da hammasini o'zi bajaradi.
    if (!isNewJobs) _fire('onTick', _jobs?.onTick);
  });

  /// Ilova fondan qaytdi: ruxsatlar Sozlamalarda berilgan bo'lishi mumkin —
  /// hammasi qayta tekshiriladi; UI egasi bo'lsa yetishmagan ishlar bajariladi.
  Future<void> onResume() => _serial(() async {
    if (_session == null) return;
    final isNewJobs = await _ensure(withEnforcement: true);
    if (!isNewJobs) _fire('onTick', _jobs?.onTick);
  });

  /// WS/FCM triggeri: FGS ishlayotgan bo'lsa — unga uzatiladi, aks holda
  /// UI isolate'dagi BackgroundJobs bajaradi (iOS — o'z sinxroni).
  Future<void> forward(String message) => _serial(() async {
    if (_session == null) return;
    if (!_usesForegroundService) {
      final syncInUi = _syncRestrictionsInUi;
      if (message == ParvozMessages.restrictionsSync && syncInUi != null) {
        _fire('restrictionsSync', syncInUi);
        return;
      }
      _deliverToJobs(message);
      return;
    }
    if (await _isServiceRunning()) {
      _send(message);
      return;
    }
    _deliverToJobs(message);
  });

  void dispose() {
    _isDisposed = true;
    _ticker?.cancel();
    _ticker = null;
    final jobs = _jobs;
    _jobs = null;
    _session = null;
    if (jobs != null) _fire('stop', jobs.stop);
  }

  // ── ichki ──────────────────────────────────────────────────────────

  /// `true` — UI isolate ishlarni shu chaqiruvda yangidan oldi (start()
  /// yuborildi).
  Future<bool> _ensure({required bool withEnforcement}) async {
    final session = _session;
    if (session == null || _isDisposed) return false;
    if (!_usesForegroundService) return _acquireJobs(session);
    if (!await _isServiceRunning()) {
      await _guard('FGS start', _platform.startService);
    }
    if (withEnforcement) {
      await _guard('RestrictionService start', _platform.startEnforcement);
    }
    if (await _isServiceRunning()) {
      await _releaseJobs();
      return false;
    }
    return _acquireJobs(session);
  }

  bool _acquireJobs(BackgroundSession session) {
    if (_jobs != null) return false;
    final BackgroundJobsHandle jobs;
    try {
      jobs = _createJobs(session);
    } catch (e) {
      debugPrint('[BackgroundOwner] BackgroundJobs yaratilmadi: $e');
      return false;
    }
    _jobs = jobs;
    // start() tarmoqni kutishi mumkin — navbatni bloklamaydi.
    _fire('start', jobs.start);
    return true;
  }

  Future<void> _releaseJobs() async {
    final jobs = _jobs;
    if (jobs == null) return;
    _jobs = null;
    await _guard('BackgroundJobs stop', jobs.stop);
  }

  Future<bool> _isServiceRunning() async {
    try {
      return await _platform.isServiceRunning();
    } catch (e) {
      debugPrint('[BackgroundOwner] isRunningService xato: $e');
      return false;
    }
  }

  void _deliverToJobs(String message) {
    final jobs = _jobs;
    if (jobs == null) return;
    _fire('onMessage', () => jobs.onMessage(message));
  }

  void _send(String message) {
    try {
      _platform.sendToService(message);
    } catch (e) {
      debugPrint('[BackgroundOwner] FGS\'ga xabar yuborilmadi: $e');
    }
  }

  Future<void> _serial(Future<void> Function() body) {
    final next = _queue.then((_) => body()).catchError((Object e) {
      debugPrint('[BackgroundOwner] xato: $e');
    });
    _queue = next;
    return next;
  }

  static Future<void> _guard(String what, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('[BackgroundOwner] $what xato: $e');
    }
  }

  /// Javobni kutmasdan (tarmoq ishlari navbatni ushlab turmasin).
  static void _fire(String what, Future<void> Function()? fn) {
    if (fn == null) return;
    unawaited(_guard(what, fn));
  }
}
