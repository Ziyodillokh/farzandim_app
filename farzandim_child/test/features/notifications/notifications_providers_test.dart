// Bildirishnomalar: tarmoq xatosi ro'yxat/nishonni bo'shatmaydi, ilova
// fonda bo'lsa so'rov yo'q (qaytganda darhol yangilanadi), WS hodisasi
// darhol yangilaydi.

import 'package:farzandim_child/app/app_lifecycle_provider.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/realtime/realtime_socket.dart';
import 'package:farzandim_child/core/realtime/socket_client.dart';
import 'package:farzandim_child/features/notifications/data/models/app_notification.dart';
import 'package:farzandim_child/features/notifications/data/repositories/backend_notification_repository.dart';
import 'package:farzandim_child/features/notifications/data/services/notifications_poller.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(String id, {bool isRead = false}) => AppNotification(
  id: id,
  type: NotificationType.studyNudge,
  title: 'Sarlavha $id',
  body: 'Matn',
  createdAt: DateTime(2026, 11, 14, 9),
  isRead: isRead,
);

/// Navbatdagi javoblar: ro'yxat yoki `null` (tarmoq xatosi).
class _FakeRepo implements BackendNotificationRepository {
  _FakeRepo(this.responses);

  final List<List<AppNotification>?> responses;
  int calls = 0;

  @override
  Future<({List<AppNotification> items, int unreadCount})?> getNotifications({
    required String childId,
    bool? isRead,
    int limit = 100,
  }) async {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls++;
    final items = responses[index];
    if (items == null) return null;
    return (items: items, unreadCount: items.where((n) => !n.isRead).length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PairedNotifier extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  _PairedNotifier()
    : super(
        const AppPairingState(
          status: PairingStatus.paired,
          parentUid: 'parent-1',
          childId: 'child-1',
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoTokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Socket hech qachon ulanmaydi — hodisalar qo'lda yuboriladi.
class _SilentSocket implements RealtimeSocket {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _foreground = StateProvider<bool>((_) => true);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationsPoller', () {
    test(
      'xato oxirgi ro\'yxatni saqlaydi (bo\'sh ro\'yxat chiqmaydi)',
      () async {
        final responses = <List<AppNotification>?>[
          [_n('a'), _n('b', isRead: true)],
          null,
        ];
        var call = 0;
        final poller = NotificationsPoller(
          fetch: () async => responses[call++],
        );
        addTearDown(poller.dispose);
        final events = <Object>[];
        poller.stream.listen(events.add, onError: events.add);

        poller.setActive(true);
        await _settle();
        await poller.refresh();
        await _settle();

        expect(call, 2);
        expect(events, hasLength(1));
        expect((events.single as List).length, 2);
      },
    );

    test(
      'birinchi yuklash yiqilsa xato chiqadi (cheksiz yuklanish yo\'q)',
      () async {
        final poller = NotificationsPoller(fetch: () async => null);
        addTearDown(poller.dispose);
        final errors = <Object>[];
        poller.stream.listen((_) {}, onError: errors.add);

        poller.setActive(true);
        await _settle();

        expect(errors.single, isA<NotificationsUnavailable>());
      },
    );

    test('fonda so\'rov yo\'q, qaytganda darhol yangilanadi', () async {
      var calls = 0;
      final poller = NotificationsPoller(
        fetch: () async {
          calls++;
          return <AppNotification>[];
        },
      );
      addTearDown(poller.dispose);
      poller.stream.listen((_) {});

      poller.setActive(true);
      await _settle();
      poller.setActive(false);
      await poller.refresh(); // WS hodisasi fonda — e'tiborsiz
      await _settle();
      expect(calls, 1);

      poller.setActive(true);
      await _settle();
      expect(calls, 2);
    });

    test('zaxira so\'rov faqat ilova ekranda ishlaydi', () async {
      var calls = 0;
      final poller = NotificationsPoller(
        fetch: () async {
          calls++;
          return <AppNotification>[];
        },
        interval: const Duration(milliseconds: 20),
      );
      addTearDown(poller.dispose);
      poller.stream.listen((_) {});

      poller.setActive(true);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(calls, greaterThanOrEqualTo(3));

      poller.setActive(false);
      final atPause = calls;
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(calls, atPause);
    });
  });

  group('notificationsProvider', () {
    late _FakeRepo repo;
    late SocketClient socket;
    late ProviderContainer container;

    setUp(() {
      socket = SocketClient(
        tokenStorage: _NoTokens(),
        socketFactory: (_, _) => _SilentSocket(),
        url: 'wss://example.test',
      );
    });

    ProviderContainer build(List<List<AppNotification>?> responses) {
      repo = _FakeRepo(responses);
      final c = ProviderContainer(
        overrides: [
          pairingStateProvider.overrideWith((ref) => _PairedNotifier()),
          backendNotificationRepositoryProvider.overrideWithValue(repo),
          socketClientProvider.overrideWithValue(socket),
          isAppInForegroundProvider.overrideWith(
            (ref) => ref.watch(_foreground),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('tarmoq xatosi ro\'yxat va nishonni bo\'shatmaydi', () async {
      container = build([
        [_n('a'), _n('b'), _n('c', isRead: true)],
        null,
      ]);
      final sub = container.listen(unreadNotificationsCountProvider, (_, _) {});
      addTearDown(sub.close);
      await _settle();
      expect(sub.read().valueOrNull, 2);

      // Ilova fonga o'tib qaytdi — qayta yuklash tarmoq xatosi bilan tugadi.
      container.read(_foreground.notifier).state = false;
      await _settle();
      container.read(_foreground.notifier).state = true;
      await _settle();

      expect(repo.calls, 2);
      expect(sub.read().valueOrNull, 2);
      expect(container.read(notificationsProvider).valueOrNull, hasLength(3));
    });

    test('ilova fonda bo\'lsa so\'rov yuborilmaydi', () async {
      container = build([
        [_n('a')],
      ]);
      container.read(_foreground.notifier).state = false;
      final sub = container.listen(notificationsProvider, (_, _) {});
      addTearDown(sub.close);
      await _settle();

      expect(repo.calls, 0);

      container.read(_foreground.notifier).state = true;
      await _settle();
      expect(repo.calls, 1);
      expect(sub.read().valueOrNull, hasLength(1));
    });

    test('ekranlar yopilsa provider ham yopiladi', () async {
      container = build([
        [_n('a')],
      ]);
      final sub = container.listen(notificationsProvider, (_, _) {});
      await _settle();
      expect(repo.calls, 1);

      sub.close();
      await _settle();
      expect(container.exists(notificationsProvider), isFalse);
    });
  });
}
