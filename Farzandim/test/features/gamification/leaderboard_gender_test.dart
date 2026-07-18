// LeaderboardEntry backend javobidan gender'ni to'g'ri o'qishini pinlaydi.
// Bu — DON reytingida jinsi+yoshga mos avatar chiqishining asosi.

import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

LeaderboardEntry _parse(Map<String, dynamic> j) =>
    LeaderboardEntry.fromJson({'rank': 1, 'childId': 'c', 'don': 10, ...j});

void main() {
  test('gender "male" → Gender.male', () {
    expect(_parse({'gender': 'male'}).gender, Gender.male);
  });

  test('gender "female" → Gender.female', () {
    expect(_parse({'gender': 'female'}).gender, Gender.female);
  });

  test('gender null yoki yo`q (eski backend) → null', () {
    expect(_parse({'gender': null}).gender, isNull);
    expect(_parse({}).gender, isNull);
  });

  test('gender kutilmagan qiymat → null (crash yo`q)', () {
    expect(_parse({'gender': 'other'}).gender, isNull);
  });

  test('age ham o`qiladi (avatar guruhi uchun)', () {
    final e = _parse({'gender': 'female', 'age': 12});
    expect(e.gender, Gender.female);
    expect(e.age, 12);
  });
}
