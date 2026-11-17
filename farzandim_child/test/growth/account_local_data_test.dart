// Akkauntga bog'liq mahalliy ma'lumotlar: kalit shakli, chiqishda tozalash va
// shaxsiy kalitlar (tugallanmagan mashq, xatcho'plar, oxirgi audiokitob,
// maktab kodi cheklovi) faqat faol akkauntniki; hech kim kirmagan bo'lsa —
// o'qilmaydi ham, yozilmaydi ham.

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:farzandim_child/growth/kirish/school_code_screens.dart';
import 'package:farzandim_child/growth/oqish/library/library_data.dart';
import 'package:farzandim_child/growth/oqish/practice/unfinished_practice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_kirish.dart';

ProviderContainer _container(FakeOwnerPairing pairing) {
  final container = ProviderContainer(
    overrides: [pairingStateProvider.overrideWith((ref) => pairing)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _switchTo(FakeOwnerPairing pairing, String childId) =>
    pairing.restoreFromRecovery(
      parentUid: 'parent-1',
      childId: childId,
      childName: 'Bola',
    );

const _practice = UnfinishedPractice(
  subject: Subject.math,
  answered: 4,
  total: 10,
  outcomes: [true, true, false, true],
  day: '2026-11-05',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('kalit: <asos>@<childId>', () {
    expect(
      accountKey('g5_article_bookmarks_v1', 'child-9'),
      'g5_article_bookmarks_v1@child-9',
    );
  });

  test(
    'chiqishda faqat shu bolaning kalitlari va murojaatlar navbati o\'chadi',
    () async {
      SharedPreferences.setMockInitialValues({
        'g5_unfinished_practice_v1@child-9': '{}',
        'g5_article_bookmarks_v1@child-9': <String>['a1'],
        'g5_school_code_lock_until_v1@child-9': '2026-11-05T10:00:00.000',
        'g5_unfinished_practice_v1@child-1': '{}',
        'g5_article_bookmarks_v1@child-90': <String>['a2'],
        'g5_text_size_v1': 'large',
        'childId': 'child-1',
      });
      FlutterSecureStorage.setMockInitialValues({
        'g5_voice_outbox_v1_child-9': '[]',
        'g5_voice_outbox_v1_child-1': '[]',
      });

      await clearAccountLocalData('child-9');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {
        'g5_unfinished_practice_v1@child-1',
        'g5_article_bookmarks_v1@child-90',
        'g5_text_size_v1',
        'childId',
      });
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'g5_voice_outbox_v1_child-9'), isNull);
      expect(await storage.read(key: 'g5_voice_outbox_v1_child-1'), '[]');
    },
  );

  test('faol akkaunt kaliti juftlash holatiga ergashadi', () async {
    final pairing = FakeOwnerPairing(paired: true);
    final container = _container(pairing);

    expect(container.read(currentChildIdProvider), 'child-1');
    expect(
      container.read(currentAccountKeyProvider('g5_x_v1')),
      'g5_x_v1@child-1',
    );

    await _switchTo(pairing, 'child-2');
    expect(container.read(currentChildIdProvider), 'child-2');
    expect(
      container.read(currentAccountKeyProvider('g5_x_v1')),
      'g5_x_v1@child-2',
    );

    final signedOut = _container(FakeOwnerPairing());
    expect(signedOut.read(currentChildIdProvider), isNull);
    expect(signedOut.read(currentAccountKeyProvider('g5_x_v1')), isNull);
  });

  test('hech kim kirmagan — hech narsa o\'qilmaydi va yozilmaydi', () async {
    SharedPreferences.setMockInitialValues({
      // Eski qurilma-umumiy kalitlar.
      'g5_unfinished_practice_v1':
          '{"subject":"math","answered":4,"total":10,"outcomes":[],"day":"2026-11-05"}',
      'g5_article_bookmarks_v1': <String>['a1'],
      'g5_last_audiobook_v1': 'b1',
    });
    final container = _container(FakeOwnerPairing());

    expect(await container.read(unfinishedPracticeProvider.future), isNull);
    expect(await container.read(articleBookmarksProvider.future), isEmpty);
    expect(await container.read(lastAudiobookProvider.future), isNull);

    await container.read(unfinishedPracticeProvider.notifier).save(_practice);
    await container.read(articleBookmarksProvider.notifier).toggle('a2');
    await container.read(lastAudiobookProvider.notifier).remember('b2');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {
      'g5_unfinished_practice_v1',
      'g5_article_bookmarks_v1',
      'g5_last_audiobook_v1',
    });
  });

  test(
    'tugallanmagan mashq akkauntga yoziladi; boshqa bolaga ko\'rinmaydi',
    () async {
      final pairing = FakeOwnerPairing(paired: true);
      final container = _container(pairing);
      await container.read(unfinishedPracticeProvider.future);

      await container.read(unfinishedPracticeProvider.notifier).save(_practice);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('g5_unfinished_practice_v1@child-1'),
        contains('"answered":4'),
      );

      await _switchTo(pairing, 'child-2');
      expect(await container.read(unfinishedPracticeProvider.future), isNull);
      // Ikkinchi bola mashqni yakunladi — birinchisiniki qoladi.
      await container.read(unfinishedPracticeProvider.notifier).clear();
      // Juftlash sozlamalaridan tashqari faqat shu akkauntning kaliti.
      expect(prefs.getKeys().where((k) => k.startsWith('g5_')).toSet(), {
        'g5_unfinished_practice_v1@child-1',
      });

      await _switchTo(pairing, 'child-1');
      expect(
        (await container.read(unfinishedPracticeProvider.future))?.answered,
        4,
      );
    },
  );

  test(
    'xatcho\'plar va oxirgi audiokitob akkauntga yoziladi; boshqa bolaga yo\'q',
    () async {
      final pairing = FakeOwnerPairing(paired: true);
      final container = _container(pairing);
      await container.read(articleBookmarksProvider.future);
      await container.read(lastAudiobookProvider.future);

      await container.read(articleBookmarksProvider.notifier).toggle('a1');
      await container.read(lastAudiobookProvider.notifier).remember('b1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('g5_article_bookmarks_v1@child-1'), ['a1']);
      expect(prefs.getString('g5_last_audiobook_v1@child-1'), 'b1');
      expect((await container.read(lastAudiobookProvider.future))?.id, 'b1');

      await _switchTo(pairing, 'child-2');
      expect(await container.read(articleBookmarksProvider.future), isEmpty);
      expect(await container.read(lastAudiobookProvider.future), isNull);
    },
  );

  test('maktab kodi cheklovi faqat shu bolaniki', () async {
    final until = DateTime.now().add(const Duration(minutes: 10));
    SharedPreferences.setMockInitialValues({
      accountKey(kSchoolCodeLockKey, 'child-1'): until.toIso8601String(),
      // Eski qurilma-umumiy kalit hisobga olinmaydi.
      kSchoolCodeLockKey: until.toIso8601String(),
    });

    expect(await codeLockUntil('child-1'), until);
    expect(await codeLockUntil('child-2'), isNull);
    expect(await codeLockUntil(null), isNull);
  });
}
