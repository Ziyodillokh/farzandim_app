import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UI katalogida mavjud bo\'lmagan funksiyalar medallari yo\'q', () {
    final ids = Achievements.visible.map((a) => a.id).toSet();
    expect(ids, isNot(contains('content_creator')));
    expect(ids, isNot(contains('helper')));
    expect(ids, containsAll(<String>['first_book', 'streak_10']));
  });

  test('byId yashirin yutuqlarni ham topadi (backend unlock qilsa)', () {
    expect(Achievements.byId('helper'), isNotNull);
  });
}
