// Bola "qo'shimcha vaqt" so'rovi — ota-onaga yetkazish dedup mantiqi.
//
// MUAMMO (2026-08-28): so'rov ota-onaga umuman yetib bormasdi, chunki
// ota-ona ilovasida uni ko'rsatadigan YAGONA kanal FCM push edi.
// Endi uchta kanal bor: push, `unlock_request:created` WS va serverdan
// PENDING ro'yxatini tortish. Uchalasi ham BITTA so'rovni yetkazishi
// mumkin — shuning uchun dedup mantiqi kritik: aks holda ota-ona bitta
// so'rovni ro'yxatda ikki-uch marta ko'radi.
//
// Bu test aynan shu dedup'ni pinlaydi. Nozik joyi: push orqali kelgan
// nusxaning `id`si FCM `messageId` bo'ladi, serverdan kelganiniki esa
// `unlock-<so'rov id>` — ya'ni `id`lar HAR DOIM farq qiladi va faqat
// `id` bo'yicha solishtirish YETARLI EMAS. Ikkalasini bog'laydigan
// yagona narsa — `data['unlockRequestId']`.

import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push orqali kelgan nusxa — `id` = FCM messageId.
AppNotification _fromPush(String requestId, {String messageId = 'fcm-1'}) {
  return AppNotification(
    id: messageId,
    type: NotificationType.unlockRequest,
    childId: 'child-1',
    childName: 'Sevinch',
    title: 'Sevinch',
    message: "YouTube uchun 30 daqiqa qo'shimcha vaqt so'rayapti.",
    timestamp: DateTime(2026, 8, 28, 10),
    data: <String, dynamic>{
      'type': 'unlock_request',
      'unlockRequestId': requestId,
      'requestedMinutes': 30,
    },
  );
}

/// Serverdan (REST yoki WS) kelgan nusxa — `id` = 'unlock-<so'rov id>'.
AppNotification _fromServer(String requestId) {
  return AppNotification(
    id: 'unlock-$requestId',
    type: NotificationType.unlockRequest,
    childId: 'child-1',
    childName: 'Sevinch',
    title: 'Sevinch',
    message: "com.google.youtube uchun 30 daqiqa qo'shimcha vaqt so'rayapti.",
    timestamp: DateTime(2026, 8, 28, 10),
    data: <String, dynamic>{
      'type': 'unlock_request',
      'unlockRequestId': requestId,
      'requestedMinutes': 30,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('addFromServer — dedup', () {
    test("push kelgan so'rov serverdan QAYTA qo'shilmaydi", () {
      // Arrange — push allaqachon kelgan.
      final notifier = NotificationsNotifier()
        ..addFromFcm(_fromPush('req-1'));
      expect(notifier.state, hasLength(1));

      // Act — o'sha so'rov endi serverdan ham keldi (boshqa `id` bilan).
      notifier.addFromServer([_fromServer('req-1')]);

      // Assert — ro'yxatda bittaligicha qoladi.
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.id, 'fcm-1');
    });

    test("takroriy sync bir xil so'rovni ikkilantirmaydi", () {
      final notifier = NotificationsNotifier()
        ..addFromServer([_fromServer('req-1')])
        // resume → sync yana ishladi, so'rov hali PENDING.
        ..addFromServer([_fromServer('req-1')]);

      expect(notifier.state, hasLength(1));
    });

    test("HAR XIL so'rovlar ikkalasi ham qo'shiladi", () {
      final notifier = NotificationsNotifier()
        ..addFromServer([_fromServer('req-1'), _fromServer('req-2')]);

      expect(notifier.state, hasLength(2));
    });

    test('WS va REST bir vaqtda kelsa ham bitta yozuv qoladi', () {
      // WS darhol keladi, sync esa bir necha soniyadan keyin — ikkalasi
      // ham `addFromServer` chaqiradi va `id` lari AYNI (unlock-req-9).
      final notifier = NotificationsNotifier()
        ..addFromServer([_fromServer('req-9')])
        ..addFromServer([_fromServer('req-9')]);

      expect(notifier.state, hasLength(1));
    });

    test("bo'sh ro'yxat holatni o'zgartirmaydi", () {
      final notifier = NotificationsNotifier()
        ..addFromFcm(_fromPush('req-1'))
        ..addFromServer(const []);

      expect(notifier.state, hasLength(1));
    });

    test("serverdan kelgan so'rov push'dan OLDIN bo'lsa ham dedup ishlaydi",
        () {
      // Teskari tartib — HAQIQIY stsenariy: ota-ona ilovani ochdi, sync
      // so'rovni tortdi, keyin navbatda turgan push yetib keldi.
      final notifier = NotificationsNotifier()
        ..addFromServer([_fromServer('req-1')]);
      expect(notifier.state, hasLength(1));

      notifier.addFromFcm(_fromPush('req-1'));

      // `addFromFcm` ham `unlockRequestId` bo'yicha tekshiradi, shuning
      // uchun ikkinchi nusxa qo'shilmaydi.
      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.id, 'unlock-req-1');
    });

    test("boshqa turdagi push'lar dedup'dan ta'sirlanmaydi", () {
      // `unlockRequestId` yo'q xabarlar (SOS, geo-zona va h.k.) avvalgidek
      // faqat `id` bo'yicha tekshiriladi — regressiya bo'lmasin.
      final a = AppNotification(
        id: 'sos-1',
        type: NotificationType.sos,
        childId: 'child-1',
        childName: 'Sevinch',
        title: 'SOS!',
        message: 'Yordam kerak',
        timestamp: DateTime(2026, 8, 28, 11),
      );
      final notifier = NotificationsNotifier()
        ..addFromFcm(a)
        ..addFromFcm(a);
      expect(notifier.state, hasLength(1));
    });
  });
}
