// Default avatar yo'li — jinsi + yosh guruhi to'g'ri tanlanishini pinlaydi.
//
// Chegaralar (eng muhim qaror):
//   yosh < 10        → 6-10
//   10 <= yosh < 14  → 10-14
//   yosh >= 14       → 14+  ("14 va undan katta")
// Yosh 0 (kiritilmagan) → eng yosh guruh (6-10).

import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter_test/flutter_test.dart';

Child _child({required int age, required Gender gender}) => Child(
  id: 'c1',
  name: 'Test',
  age: age,
  gender: gender,
  region: 'Toshkent',
  familyCode: '12345',
  createdAt: DateTime(2026),
);

String _path(int age, Gender gender) =>
    _child(age: age, gender: gender).defaultAvatarPath;

void main() {
  group('boy (male)', () {
    test('6-10 guruh: 0,6,9 → boy_6_10', () {
      for (final a in [0, 5, 6, 9]) {
        expect(
          _path(a, Gender.male),
          'assets/default_avatars/boy_6_10.png',
          reason: 'yosh $a',
        );
      }
    });

    test('10-14 guruh: 10,13 → boy_10_14 (10 chegara shu guruhda)', () {
      for (final a in [10, 11, 13]) {
        expect(_path(a, Gender.male), 'assets/default_avatars/boy_10_14.png');
      }
    });

    test('14+ guruh: 14,15,18 → boy_14 (14 chegara shu guruhda)', () {
      for (final a in [14, 15, 18]) {
        expect(_path(a, Gender.male), 'assets/default_avatars/boy_14.png');
      }
    });
  });

  group('girl (female)', () {
    test('6-10 guruh: 6,9 → girl_6_10', () {
      for (final a in [0, 6, 9]) {
        expect(_path(a, Gender.female), 'assets/default_avatars/girl_6_10.png');
      }
    });

    test('10-14 guruh: 10,13 → girl_10_14', () {
      for (final a in [10, 13]) {
        expect(
          _path(a, Gender.female),
          'assets/default_avatars/girl_10_14.png',
        );
      }
    });

    test('14+ guruh: 14,17 → girl_14', () {
      for (final a in [14, 17]) {
        expect(_path(a, Gender.female), 'assets/default_avatars/girl_14.png');
      }
    });
  });

  test('aynan 10 chegarasi: 9→6-10, 10→10-14', () {
    expect(_path(9, Gender.male), contains('boy_6_10'));
    expect(_path(10, Gender.male), contains('boy_10_14'));
  });

  test('aynan 14 chegarasi: 13→10-14, 14→14+', () {
    expect(_path(13, Gender.female), contains('girl_10_14'));
    expect(_path(14, Gender.female), contains('girl_14'));
  });
}
