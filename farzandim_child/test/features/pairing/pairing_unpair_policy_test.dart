// Uzish siyosati (1.0.20): lokal token holati "noma'lum" (Keystore nosozligi,
// bo'sh o'qish) juftlashni va bloklashni O'CHIRMAYDI. Faqat server
// tasdiqlagan bekor qilish (startda "aniq yo'q" yoki SessionEvents) Android'da
// to'liq tozalaydi: UI fon ishlari, FGS, RestrictionService, cheklov holati
// va egasining tokenlari.

import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/auth/data/repositories/anon_auth_repository.dart';
import 'package:farzandim_child/features/background/data/services/background_service.dart';
import 'package:farzandim_child/features/background/presentation/providers/background_service_provider.dart';
import 'package:farzandim_child/features/pairing/data/repositories/pairing_repository.dart';
import 'package:farzandim_child/features/pairing/data/services/background_owner.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/background_owner_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTokens implements TokenStorage {
  _FakeTokens({required this.isDefinitelyMissing});

  /// Server tasdiqlagan bekor qilish (TokenStorage semantikasi).
  final bool isDefinitelyMissing;
  int clears = 0;

  @override
  String get keyPrefix => '';

  @override
  Future<bool> isSessionDefinitelyMissing() async => isDefinitelyMissing;

  @override
  Future<void> clear() async => clears++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AnonAuthRepository {
  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePairingRepo implements PairingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBackgroundService implements BackgroundService {
  int stops = 0;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async => stops++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// FGS ishlab turibdi (Android'ning odatiy holati).
class _RunningFgs implements BackgroundPlatform {
  int enforcementStarts = 0;

  @override
  Future<bool> isServiceRunning() async => true;

  @override
  Future<void> startService() async {}

  @override
  void sendToService(String message) {}

  @override
  Future<void> startEnforcement() async => enforcementStarts++;
}

class _NoJobs implements BackgroundJobsHandle {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _paired = <String, Object>{
  'parentUid': 'parent-1',
  'childId': 'child-1',
  'childName': 'Aziza',
  'currentUserId': 'user-1',
};

const _enforcement = <String, Object>{
  'restriction.blocked_packages': '*',
  'restriction.plan_cache': '{}',
  'restriction.school_until': '13:00',
  'restriction.block_unknown_sources': true,
  'school_zone.inside': true,
  'game.pending': '[]',
  // Tarjima — bloklash bilan bog'liq emas, saqlanadi.
  'restriction.i18n.blocked': 'Bloklangan',
};

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTokens tokens;
  late _FakeBackgroundService fgs;
  late _RunningFgs platform;
  late BackgroundOwner owner;

  ProviderContainer build({required bool isDefinitelyMissing}) {
    tokens = _FakeTokens(isDefinitelyMissing: isDefinitelyMissing);
    fgs = _FakeBackgroundService();
    platform = _RunningFgs();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        authRepositoryProvider.overrideWithValue(_FakeAuth()),
        pairingRepositoryProvider.overrideWithValue(_FakePairingRepo()),
        backgroundServiceProvider.overrideWithValue(fgs),
        // Qadamlar sensori/Health Connect testda yo'q.
        stepCounterServiceProvider.overrideWithValue(null),
        backgroundOwnerProvider.overrideWith((ref) {
          owner = BackgroundOwner(
            usesForegroundService: true,
            platform: platform,
            createJobs: (_) => _NoJobs(),
            tickInterval: const Duration(days: 1),
          );
          ref.onDispose(owner.dispose);
          return owner;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(pairingStateProvider);
    return container;
  }

  Future<SharedPreferences> prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({..._paired, ..._enforcement});
  });

  test('token holati noma\'lum — juftlash va bloklash saqlanadi, fon '
      'xizmatlari darhol ishga tushadi', () async {
    final container = build(isDefinitelyMissing: false);
    await _until(() => container.read(pairingStateProvider).isPaired);
    await _until(() => platform.enforcementStarts == 1);

    final p = await prefs();
    expect(p.getString('childId'), 'child-1');
    expect(p.getString('restriction.blocked_packages'), '*');
    expect(p.getString('restriction.school_until'), '13:00');
    expect(tokens.clears, 0);
    expect(fgs.stops, 0);
    expect(owner.session?.childId, 'child-1');
    // FGS ishlayapti — UI isolate fon ishlarini o'zi boshlamaydi.
    expect(owner.ownsJobs, isFalse);
  });

  test(
    'server tasdiqlagan bekor qilish (startda) — to\'liq tozalanadi',
    () async {
      final container = build(isDefinitelyMissing: true);
      await _until(() => container.read(pairingStateProvider).isSessionEnded);

      final state = container.read(pairingStateProvider);
      expect(state.isPaired, isFalse);
      final p = await prefs();
      expect(p.getString('childId'), isNull);
      expect(p.getString('restriction.blocked_packages'), isNull);
      expect(p.getString('restriction.plan_cache'), isNull);
      expect(p.getString('restriction.school_until'), isNull);
      expect(p.getBool('restriction.block_unknown_sources'), isNull);
      expect(p.getBool('school_zone.inside'), isNull);
      expect(p.getString('game.pending'), isNull);
      expect(p.getString('restriction.i18n.blocked'), 'Bloklangan');
      expect(fgs.stops, 1);
      expect(tokens.clears, 1);
    },
  );

  test('server signali (SessionEvents) — uzish va tozalash', () async {
    final container = build(isDefinitelyMissing: false);
    await _until(() => container.read(pairingStateProvider).isPaired);

    SessionEvents.notifyRevoked(reason: 'RECOVERED');
    await _until(() => container.read(pairingStateProvider).isSessionEnded);

    final p = await prefs();
    expect(p.getString('childId'), isNull);
    expect(p.getString('restriction.blocked_packages'), isNull);
    expect(owner.session, isNull);
    expect(fgs.stops, 1);
    expect(tokens.clears, 1);
  });

  test('mehmon akkaunt sessiyasi egasining juftlashiga tegmaydi', () async {
    final container = build(isDefinitelyMissing: false);
    await _until(() => container.read(pairingStateProvider).isPaired);

    SessionEvents.notifyRevoked(scope: 'acct_child-9_');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(pairingStateProvider).isPaired, isTrue);
    expect(tokens.clears, 0);
    expect((await prefs()).getString('restriction.blocked_packages'), '*');
  });
}
