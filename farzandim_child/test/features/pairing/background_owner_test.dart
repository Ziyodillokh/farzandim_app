// Fon ishlarining yagona egasi: FGS ishlasa UI isolate hech narsa
// boshlamaydi va triggerlarni FGS'ga uzatadi; FGS yo'q (yoki iOS) bo'lsa UI
// bitta BackgroundJobs yuritadi; FGS keyin yoqilsa UI nusxasi to'xtaydi.

import 'package:farzandim_child/features/background/data/services/parvoz_messages.dart';
import 'package:farzandim_child/features/pairing/data/services/background_owner.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = BackgroundSession(
  childId: 'child-1',
  parentUid: 'parent-1',
  childName: 'Aziza',
);

class _FakePlatform implements BackgroundPlatform {
  _FakePlatform({this.isRunning = false, this.startSucceeds = true});

  bool isRunning;
  bool startSucceeds;
  int serviceStarts = 0;
  int enforcementStarts = 0;
  final sent = <String>[];

  @override
  Future<bool> isServiceRunning() async => isRunning;

  @override
  Future<void> startService() async {
    serviceStarts++;
    if (startSucceeds) isRunning = true;
  }

  @override
  void sendToService(String message) => sent.add(message);

  @override
  Future<void> startEnforcement() async => enforcementStarts++;
}

class _FakeJobs implements BackgroundJobsHandle {
  int starts = 0;
  int stops = 0;
  int ticks = 0;
  final messages = <String>[];

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> onTick() async => ticks++;

  @override
  Future<void> onScreenOn() async {}

  @override
  Future<void> onMessage(String type) async => messages.add(type);

  @override
  Future<void> onConnectivityRestored() async {}
}

/// `_fire` bilan yuborilgan ishlar tugashi uchun.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late List<_FakeJobs> created;
  late List<BackgroundSession> sessions;
  late BackgroundOwner owner;
  late _FakePlatform platform;

  BackgroundOwner build({
    required bool usesFgs,
    Future<void> Function()? iosSync,
  }) {
    return BackgroundOwner(
      usesForegroundService: usesFgs,
      platform: platform,
      createJobs: (session) {
        sessions.add(session);
        final jobs = _FakeJobs();
        created.add(jobs);
        return jobs;
      },
      syncRestrictionsInUi: iosSync,
      // Taymer testda o'zi ishlamasin — tik qo'lda chaqiriladi.
      tickInterval: const Duration(days: 1),
    );
  }

  setUp(() {
    created = [];
    sessions = [];
  });

  tearDown(() => owner.dispose());

  group('Android, FGS ishlayapti', () {
    setUp(() {
      platform = _FakePlatform(isRunning: true);
      owner = build(usesFgs: true);
    });

    test('UI isolate fon ishlarini boshlamaydi', () async {
      await owner.attach(_session);
      await owner.tick();
      await owner.onResume();
      await _settle();

      expect(created, isEmpty);
      expect(owner.ownsJobs, isFalse);
      // Ishlab turgan FGS qayta start qilinmaydi.
      expect(platform.serviceStarts, 0);
    });

    test('WS/FCM triggeri FGS isolate\'iga uzatiladi', () async {
      await owner.attach(_session);
      await owner.forward(ParvozMessages.restrictionsSync);
      await _settle();

      expect(platform.sent, [ParvozMessages.restrictionsSync]);
      expect(created, isEmpty);
    });

    test('juftlashdan keyin native bloklash darhol yoqiladi', () async {
      await owner.attach(_session);

      expect(platform.enforcementStarts, 1);
    });
  });

  group('Android, FGS ishlamayapti', () {
    setUp(() {
      platform = _FakePlatform(startSucceeds: false);
      owner = build(usesFgs: true);
    });

    test('FGS start urinib ko\'riladi, keyin UI bitta BackgroundJobs '
        'yuritadi', () async {
      await owner.attach(_session);
      await owner.attach(_session); // takroriy chaqiruv — dublikat yo'q
      await _settle();

      expect(platform.serviceStarts, 2);
      expect(created, hasLength(1));
      expect(created.single.starts, 1);
      expect(owner.ownsJobs, isTrue);
    });

    test('trigger UI BackgroundJobs\'ga boradi, FGS\'ga emas', () async {
      await owner.attach(_session);
      await owner.forward(ParvozMessages.restrictionsSync);
      await _settle();

      expect(platform.sent, isEmpty);
      expect(created.single.messages, [ParvozMessages.restrictionsSync]);
    });

    test('tik va resume UI ishlarini yuritadi', () async {
      await owner.attach(_session);
      await owner.tick();
      await owner.onResume();
      await _settle();

      expect(created.single.ticks, 2);
    });

    test('FGS keyin yoqilsa UI nusxasi to\'xtatiladi', () async {
      await owner.attach(_session);
      await _settle();
      expect(owner.ownsJobs, isTrue);

      // Masalan ruxsat Sozlamalarda berildi, ilova qaytdi.
      platform.startSucceeds = true;
      await owner.onResume();
      await owner.forward(ParvozMessages.restrictionsSync);
      await _settle();

      expect(owner.ownsJobs, isFalse);
      expect(created.single.stops, 1);
      expect(platform.sent, [ParvozMessages.restrictionsSync]);
      expect(created.single.messages, isEmpty);
    });

    test(
      'FGS o\'lsa keyingi tikda qayta yoqiladi, bo\'lmasa UI egallaydi',
      () async {
        platform
          ..startSucceeds = true
          ..isRunning = true;
        await owner.attach(_session);
        expect(owner.ownsJobs, isFalse);

        // OEM FGS'ni o'ldirdi va qayta yoqib bo'lmaydi.
        platform
          ..isRunning = false
          ..startSucceeds = false;
        await owner.tick();
        await _settle();

        expect(platform.serviceStarts, 1);
        expect(owner.ownsJobs, isTrue);
        // Yangi ishlar start()'da hammasini bajaradi — darhol tik yo'q.
        expect(created.single.starts, 1);
        expect(created.single.ticks, 0);

        await owner.tick();
        await _settle();
        expect(platform.serviceStarts, 2);
        expect(created.single.ticks, 1);
      },
    );

    test('uzishda UI ishlari to\'xtaydi va triggerlar e\'tiborsiz', () async {
      await owner.attach(_session);
      await owner.detach();
      await owner.forward(ParvozMessages.restrictionsSync);
      await owner.tick();
      await _settle();

      expect(created.single.stops, 1);
      expect(created.single.messages, isEmpty);
      expect(created.single.ticks, 0);
      expect(owner.session, isNull);
    });

    test('boshqa bolaga qayta juftlash eski ishlarni yopadi', () async {
      const other = BackgroundSession(
        childId: 'child-2',
        parentUid: 'parent-2',
        childName: 'Jasur',
      );
      await owner.attach(_session);
      await owner.attach(other);
      await _settle();

      expect(sessions, [_session, other]);
      expect(created.first.stops, 1);
      expect(created.last.starts, 1);
      expect(owner.session, other);
    });
  });

  group('iOS (FGS yo\'q)', () {
    var iosSyncs = 0;

    setUp(() {
      iosSyncs = 0;
      platform = _FakePlatform();
      owner = build(usesFgs: false, iosSync: () async => iosSyncs++);
    });

    test('UI bitta BackgroundJobs yuritadi, FGS/RestrictionService '
        'chaqirilmaydi', () async {
      await owner.attach(_session);
      await owner.onResume();
      await _settle();

      expect(created, hasLength(1));
      expect(created.single.ticks, 1);
      expect(platform.serviceStarts, 0);
      expect(platform.enforcementStarts, 0);
    });

    test('cheklovlar triggeri Family Controls sinxroniga boradi', () async {
      await owner.attach(_session);
      await owner.forward(ParvozMessages.restrictionsSync);
      await _settle();

      expect(iosSyncs, 1);
      expect(created.single.messages, isEmpty);
      expect(platform.sent, isEmpty);
    });
  });
}
