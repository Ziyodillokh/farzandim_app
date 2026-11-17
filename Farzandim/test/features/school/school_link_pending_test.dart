// Ota-ona 6 xonali kodni kiritdi, telefoni maktabga ma'lum emas — vasiylik
// xodim tasdig'ini kutadi (K2 `PENDING_REVIEW`, o'quvchi ma'lumotisiz).

import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("PENDING_REVIEW bog'lanish — tasdiq kutilmoqda, o'quvchisiz", () {
    final link = SchoolLink.fromJson(const {
      'guardianId': 'g1',
      'fullName': 'Karimova Dilnoza',
      'relation': 'OTHER',
      'status': 'PENDING_REVIEW',
      'school': {'id': 's1', 'name': '45-maktab'},
      'students': <Object>[],
    });
    expect(link.pendingReview, isTrue);
    expect(link.students, isEmpty);

    final linked = SchoolLink.fromJson(const {
      'guardianId': 'g2',
      'fullName': 'Karimov Aziz',
      'relation': 'FATHER',
      'status': 'LINKED',
      'school': {'id': 's1', 'name': '45-maktab'},
      'students': <Object>[],
    });
    expect(linked.pendingReview, isFalse);
  });
}
