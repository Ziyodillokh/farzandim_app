// Default avatar yo'li — jinsi + yosh guruhi to'g'ri tanlanishini pinlaydi.
//
// Sxema:
//   O'G'IL → yagona boy.png (yoshdan qat'i nazar)
//   QIZ    → yoshga qarab:
//     yosh < 10        → girl_6_10
//     10 <= yosh < 14  → girl_10_14
//     yosh >= 14       → girl_14  ("14 va undan katta")

import 'package:farzandim/features/child_management/data/models/default_avatar.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('o`g`il (male) — yagona boy.png', () {
    test('har qanday yoshda → boy.png', () {
      for (final a in [0, 5, 6, 9, 10, 13, 14, 15, 18]) {
        expect(
          defaultAvatarAsset(Gender.male, a),
          'assets/default_avatars/boy.png',
          reason: 'yosh $a',
        );
      }
    });
  });

  group('qiz (female) — yoshga qarab', () {
    test('6-10 guruh: 0,6,9 → girl_6_10', () {
      for (final a in [0, 5, 6, 9]) {
        expect(
          defaultAvatarAsset(Gender.female, a),
          'assets/default_avatars/girl_6_10.png',
          reason: 'yosh $a',
        );
      }
    });

    test('10-14 guruh: 10,13 → girl_10_14 (10 chegara shu guruhda)', () {
      for (final a in [10, 11, 13]) {
        expect(
          defaultAvatarAsset(Gender.female, a),
          'assets/default_avatars/girl_10_14.png',
        );
      }
    });

    test('14+ guruh: 14,17 → girl_14 (14 chegara shu guruhda)', () {
      for (final a in [14, 15, 18]) {
        expect(
          defaultAvatarAsset(Gender.female, a),
          'assets/default_avatars/girl_14.png',
        );
      }
    });
  });

  test('qiz chegaralari: 9→6-10, 10→10-14, 13→10-14, 14→14+', () {
    expect(defaultAvatarAsset(Gender.female, 9), contains('girl_6_10'));
    expect(defaultAvatarAsset(Gender.female, 10), contains('girl_10_14'));
    expect(defaultAvatarAsset(Gender.female, 13), contains('girl_10_14'));
    expect(defaultAvatarAsset(Gender.female, 14), contains('girl_14'));
  });
}
