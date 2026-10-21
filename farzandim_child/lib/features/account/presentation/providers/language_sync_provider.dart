// Ilova tilini bola hisobiga yozib borish (`LanguageSyncService`):
// ulangandan keyin va til almashganda. `main.dart` ChildApp build'da
// `languageSyncProvider`ni watch qiladi va joriy tilni `appLanguageProvider`ga
// yozadi. Yozilmagan til bosh sahifa yangilanganda qayta yuboriladi
// (`retryLanguageSync`).

import 'dart:async';

import 'package:farzandim_child/core/network/dio_client.dart';
import 'package:farzandim_child/features/account/data/language_sync_service.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ilovaning amaldagi tili (`context.locale`). `null` — hali aniqlanmagan
/// (birinchi kadrgacha): serverga hech narsa yuborilmaydi.
final appLanguageProvider = StateProvider<String?>((ref) => null);

final languageSyncServiceProvider = Provider<LanguageSyncService>(
  (ref) => LanguageSyncService(ref.watch(dioClientProvider)),
);

/// Til yoziladigan hisob (`null` — ulanmagan). Qayta ulanganda hisob
/// o'zgaradi va til qayta yoziladi — [languageAccountOf].
final languageSyncAccountProvider = Provider<String?>(
  (ref) => ref.watch(pairingStateProvider.select(languageAccountOf)),
);

/// Til hisobi — bolaning server foydalanuvchisi (`currentUserId`). Har
/// ulanishda server yangi bola foydalanuvchisini yaratadi (tili standart
/// "uz"), `childId` esa o'sha bo'lib qoladi. Foydalanuvchi id'si saqlanmagan
/// eski ulanishda — `childId`.
String? languageAccountOf(AppPairingState state) {
  if (!state.isPaired) return null;
  final userId = state.currentUserId?.trim() ?? '';
  return userId.isNotEmpty ? userId : state.childId;
}

/// Serverdagi til yozilgan sayin oshadi: til bo'yicha matn beradigan maktab
/// ro'yxatlari (psixologik testlar, "Bola ovozi") shu bilan qayta yuklanadi —
/// til almashganda eski tildagi matn qolib ketmaydi.
final syncedLanguageRevisionProvider = StateProvider<int>((ref) => 0);

/// Til yoki ulanish o'zgarganda tilni serverga yozadi (side-effect).
final languageSyncProvider = Provider<void>((ref) {
  final language = ref.watch(appLanguageProvider);
  final account = ref.watch(languageSyncAccountProvider);
  if (language == null || account == null) return;
  final revision = ref.read(syncedLanguageRevisionProvider.notifier);
  unawaited(
    ref
        .read(languageSyncServiceProvider)
        .sync(account: account, language: language)
        .then((result) {
          if (result == LanguageSyncResult.written && revision.mounted) {
            revision.state++;
          }
        }),
  );
});

/// Avval yozilmagan (oflayn, server xatosi) tilni qayta yuboradi; allaqachon
/// yozilgan bo'lsa so'rov ketmaydi. Bosh sahifa yangilanishida chaqiriladi.
void retryLanguageSync(WidgetRef ref) => ref.invalidate(languageSyncProvider);
