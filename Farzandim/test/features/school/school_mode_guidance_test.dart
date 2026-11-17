// School Mode eslatmasi (push `SCHOOL_MODE_REMIND`): o'quvchi holatiga
// qarab moslash, ulash yoki ruxsat yo'l-yo'rig'i tanlanadi.

import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/presentation/school_mode_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

LinkedStudent _student({String? childId, String linkedBy = 'NONE'}) =>
    LinkedStudent.fromJson({
      'id': 'st-1',
      'fullName': 'Karimov Aziz',
      'className': '7-A',
      'childId': childId,
      'linkedBy': linkedBy,
    });

Child _child({DateTime? pairedAt, bool isConnected = false}) => Child(
  id: 'kid-1',
  name: 'Aziz',
  age: 12,
  gender: Gender.male,
  region: '',
  familyCode: '12345',
  createdAt: DateTime(2026),
  pairedAt: pairedAt,
  isConnected: isConnected,
);

void main() {
  test('o`quvchi ro`yxatda yo`q → Missing', () {
    expect(
      SchoolModeGuidance.of(student: null, child: null),
      isA<SchoolModeMissing>(),
    );
  });

  test('farzandga moslanmagan (NONE yoki OTHER) → moslash varag`i', () {
    for (final linkedBy in ['NONE', 'OTHER']) {
      final student = _student(linkedBy: linkedBy);
      final guidance = SchoolModeGuidance.of(student: student, child: null);
      expect(guidance, isA<SchoolModeMatch>(), reason: linkedBy);
      expect((guidance as SchoolModeMatch).student, student);
    }
  });

  test('farzand ilovada topilmadi → ulash (varaq o`zi kuzatadi)', () {
    final guidance = SchoolModeGuidance.of(
      student: _student(childId: 'kid-1', linkedBy: 'ME'),
      child: null,
    );
    expect(guidance, isA<SchoolModeConnect>());
    final connect = guidance as SchoolModeConnect;
    expect(connect.childId, 'kid-1');
    expect(connect.child, isNull);
  });

  test('bola ilovasi ulanmagan (pairedAt yo`q yoki isConnected=false)', () {
    final student = _student(childId: 'kid-1', linkedBy: 'ME');
    for (final child in [
      _child(),
      _child(isConnected: true),
      _child(pairedAt: DateTime(2026, 9)),
    ]) {
      final guidance = SchoolModeGuidance.of(student: student, child: child);
      expect(guidance, isA<SchoolModeConnect>());
      expect((guidance as SchoolModeConnect).child, child);
    }
  });

  test('ulangan → ruxsat bola telefonida yoqiladi', () {
    final child = _child(pairedAt: DateTime(2026, 9), isConnected: true);
    final guidance = SchoolModeGuidance.of(
      student: _student(childId: 'kid-1', linkedBy: 'ME'),
      child: child,
    );
    expect(guidance, isA<SchoolModePermission>());
    expect((guidance as SchoolModePermission).child, child);
  });
}
