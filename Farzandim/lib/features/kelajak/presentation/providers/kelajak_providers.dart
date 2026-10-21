// ─────────────────────────────────────────────────────────────────────
// kelajak_providers — Kelajak xulosasi holati (ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard kartasi, Growth havolasi va Kelajak sahifasi bitta
// provayderni o'qiydi. Backend'da Kelajak yo'q yoki bola topilmasa
// (404 `code`siz) qiymat `null` — kartalar yashirinadi, sahifa
// "hozircha mavjud emas" deydi.

import 'package:farzandim/core/utils/polling.dart';
import 'package:farzandim/features/kelajak/data/kelajak_repository.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sahifa ↔ dashboard o'rtasida tez qaytilganda qayta yuklanmasin.
const Duration _kelajakCacheTtl = Duration(minutes: 2);

/// Bolaning xulosasi; Kelajak mavjud emas → `null` (karta yashiriladi).
final kelajakSummaryProvider = FutureProvider.autoDispose
    .family<KelajakSummary?, String>((ref, childId) async {
      keepAliveFor(ref, _kelajakCacheTtl);
      final repo = ref.watch(kelajakRepositoryProvider);
      try {
        return await repo.fetchSummary(childId);
      } on SchoolFailure catch (failure) {
        if (failure.isUnavailable) return null;
        rethrow;
      }
    });
