// Kutubxonadagi audiokitob "saqlash" holati — lokal saqlanadi va tiklanadi.

import 'package:farzandim_child/features/audiobooks/presentation/providers/saved_audiobooks_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggle qo\'shadi, qayta bosilsa olib tashlaydi', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(savedAudiobookIdsProvider.notifier);

    expect(await notifier.toggle('a1'), isTrue);
    expect(container.read(savedAudiobookIdsProvider), {'a1'});

    expect(await notifier.toggle('a1'), isFalse);
    expect(container.read(savedAudiobookIdsProvider), isEmpty);
  });

  test('saqlanganlar qayta ochilganda tiklanadi', () async {
    final first = ProviderContainer();
    await first.read(savedAudiobookIdsProvider.notifier).toggle('a7');
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(savedAudiobookIdsProvider);
    // Lokal tiklash asinxron — keyingi toggle uni kutadi.
    await second.read(savedAudiobookIdsProvider.notifier).toggle('a8');

    expect(second.read(savedAudiobookIdsProvider), {'a7', 'a8'});
  });
}
