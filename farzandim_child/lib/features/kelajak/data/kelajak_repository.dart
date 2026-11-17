// Parvoz Kelajak ma'lumot manbai interfeysi — server (`/api/kelajak`,
// CHILD token; docs/KELAJAK-REJA.md §4). Savollar bolaning yosh guruhidan
// faqat serverda tanlanadi; har tur uchun kuniga bitta sessiya.

import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';

export 'package:farzandim_child/features/kelajak/domain/kelajak_error.dart';

/// Natijalar sahifasi hajmi (server standarti 30, ko'pi 100).
const kKelajakResultsPageSize = 20;

abstract interface class KelajakRepository {
  /// Yosh holati, bugungi testlar, kategoriyalar va profil.
  Future<KelajakOverview> loadOverview();

  /// Bugungi sessiya: yangi, davom etayotgan yoki yakunlangan (idempotent —
  /// qayta chaqirilsa shu sessiya javoblari bilan qaytadi).
  Future<KelajakSession> startSession(String type);

  Future<KelajakSession> loadSession(String sessionId);

  /// Javobni saqlash yoki o'zgartirish: shkalaga [value], ochiq savolga
  /// [text] (`""` — javobni o'chiradi). Aynan bittasi beriladi.
  Future<KelajakAnswerAck> saveAnswer({
    required String sessionId,
    required String questionId,
    int? value,
    String? text,
  });

  /// Yakunlash (idempotent) — natija bilan.
  Future<KelajakSession> completeSession(String sessionId);

  Future<KelajakProgress> loadProgress();

  /// Yakunlangan sessiyalar — yangisi birinchi; [before] — oldingi
  /// sahifaning `nextBefore` kursori.
  Future<KelajakResultsPage> loadResults({
    String? before,
    int limit = kKelajakResultsPageSize,
  });
}
