// Kelajak testlari uchun haqiqiy server javoblari (`fixtures/`, backend
// PR #12 dan olingan — README.md) va ulardan yasovchilar.

import 'dart:convert';
import 'dart:io';

import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';

const kFixturesDir = 'test/features/kelajak/fixtures';

/// Bobur (A): bugungi kunlik sessiya (`session_start_daily` va
/// `session_daily_in_progress` — bir xil sessiya).
const kDailySessionId = '334ea53c-90f1-4870-8e70-372a8b89cfc3';

/// Kunlik sessiyaning birinchi savoli (`interest_4`, 1..4).
const kDailyFirstQuestion = 'd878f32c-f38a-5710-9bc2-4f5c9e433bf3';

/// Kunlik sessiyaning ikkinchi savoli (`interest_4`).
const kDailySecondQuestion = 'ac70de69-34a2-57bd-b5fa-9a99b6b00c50';

/// "Bola ovozi" sessiyasi va birinchi ochiq savoli.
const kVoiceSessionId = '735f7b7d-7fc8-4cb4-b07a-34686844acb8';
const kVoiceFirstQuestion = '0ff51699-a296-5afe-baa0-dafbf052e635';

/// Fixture JSON'i (har chaqiruvda yangi nusxa — o'zgartirish xavfsiz).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('$kFixturesDir/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// Barcha fixture nomlari (kengaytmasiz), alifbo tartibida.
List<String> fixtureNames() {
  final names = [
    for (final entity in Directory(kFixturesDir).listSync())
      if (entity is File && entity.path.endsWith('.json'))
        entity.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();
  return names;
}

KelajakSession session(String name) => KelajakSession.fromJson(fixture(name));
