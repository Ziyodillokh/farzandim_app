// Kelajak testlari uchun backend'ning HAQIQIY javoblari
// (`fixtures/README.md`): `GET /children/:childId/kelajak/summary`.

import 'dart:convert';
import 'dart:io';

import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';

const String kRichSupportFixture = 'parent_summary_rich_support';
const String kEmptyFixture = 'parent_summary_empty';
const String kAgeRequiredFixture = 'parent_summary_age_required';
const String kWatchFixture = 'parent_summary_watch';
const String kForbiddenFixture = 'error_403_forbidden';
const String kChildNotFoundFixture = 'error_404_child_not_found';

/// Fixture JSON'i (paket ildizidan o'qiladi).
Map<String, dynamic> kelajakFixtureJson(String name) =>
    jsonDecode(
          File('test/features/kelajak/fixtures/$name.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Fixture'dan model.
KelajakSummary kelajakFixture(String name) =>
    KelajakSummary.fromJson(kelajakFixtureJson(name));
