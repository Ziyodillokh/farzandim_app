// Davomat ko'rinishi qoidalari: holat belgisi, yo'l-yo'riq va QR tugmasi
// (`canScan`, kirish / chiqish matni).

import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/presentation/attendance_display.dart';
import 'package:flutter_test/flutter_test.dart';

import 'school_fixtures.dart';

SchoolToday _today(Map<String, Object?> changes) =>
    SchoolToday.tryFromJson({...todayJson, ...changes})!;

Map<String, Object?> _record(
  String status, {
  String? inAt,
  String? outAt,
  String source = 'MANUAL',
}) => {'status': status, 'inAt': inAt, 'outAt': outAt, 'source': source};

void main() {
  group('holat belgisi', () {
    test('o\'quv kuni, yozuv yo\'q — belgilanmagan', () {
      final today = _today({'record': null});
      expect(attendanceChipOf(today), AttendanceChipKind.notMarked);
    });

    test('dam olish kuni, yozuv yo\'q — dam olish', () {
      final today = _today({'record': null, 'schoolDay': false});
      expect(attendanceChipOf(today), AttendanceChipKind.dayOff);
    });

    test('server holatlari bir-biriga mos', () {
      const expected = {
        'PRESENT': AttendanceChipKind.present,
        'LATE': AttendanceChipKind.late,
        'ABSENT': AttendanceChipKind.absent,
        'LEFT_EARLY': AttendanceChipKind.leftEarly,
        'EXCUSED': AttendanceChipKind.excused,
        'SOMETHING_NEW': AttendanceChipKind.marked,
      };
      expected.forEach((status, kind) {
        final today = _today({'record': _record(status, inAt: '08:00')});
        expect(attendanceChipOf(today), kind, reason: status);
      });
    });

    test('har bir belgining tarjima kaliti bor', () {
      for (final kind in AttendanceChipKind.values) {
        expect(kind.labelKey, 'school.status.${kind.name}');
      }
    });
  });

  group('yo\'l-yo\'riq', () {
    String hint(Map<String, Object?> changes) =>
        attendanceHintKey(_today(changes));

    test('hali kelmagan — kirishda skanerlash', () {
      expect(hint({'record': null}), 'school.today.hints.notMarked');
    });

    test('kelgan, hali ketmagan — chiqishda ham skanerlash', () {
      expect(
        hint({'record': _record('LATE', inAt: '08:12')}),
        'school.today.hints.inSchool',
      );
    });

    test('ketgan — kun yakunlandi', () {
      expect(
        hint({'record': _record('PRESENT', inAt: '07:55', outAt: '13:30')}),
        'school.today.hints.checkedOut',
      );
    });

    test('dam olish kuni', () {
      expect(
        hint({'record': null, 'schoolDay': false}),
        'school.today.hints.dayOff',
      );
    });

    test('sinf biriktirilmagan', () {
      expect(
        hint({'className': null, 'shift': null, 'schoolDay': false}),
        'school.today.hints.noClass',
      );
    });

    test('xodim belgilagan (kirish vaqtisiz)', () {
      expect(
        hint({'record': _record('EXCUSED')}),
        'school.today.hints.staffMarked',
      );
      expect(
        hint({'record': _record('ABSENT', source: 'KIOSK')}),
        'school.today.hints.staffMarked',
      );
    });

    test('tizim avtomatik "kelmadi" qo\'ygan — QR bilan kirish mumkin', () {
      final record = _record('ABSENT', source: 'SYSTEM');
      expect(hint({'record': record}), 'school.today.hints.notMarked');
      expect(isStaffDecision(_today({'record': record}).record), isFalse);
    });
  });

  group('QR tugmasi', () {
    test('hali kelmagan — kirish, ko\'rinadi', () {
      final today = _today({'record': null});
      expect(today.canScan, isTrue);
      expect(scanLabelKey(today), 'school.today.scanIn');
    });

    test('kelgan — chiqish', () {
      final today = _today({'record': _record('PRESENT', inAt: '07:58')});
      expect(today.canScan, isTrue);
      expect(scanLabelKey(today), 'school.today.scanOut');
    });

    test('ketgan yoki dam olish kuni — ko\'rinmaydi', () {
      final out = _today({
        'record': _record('PRESENT', inAt: '07:58', outAt: '13:30'),
      });
      final dayOff = _today({'record': null, 'schoolDay': false});
      expect(out.canScan, isFalse);
      expect(dayOff.canScan, isFalse);
    });

    test('xodim "kelmadi" belgilagan — kirish taklif qilinadi', () {
      final today = _today({'record': _record('ABSENT')});
      expect(today.canScan, isTrue);
      expect(scanLabelKey(today), 'school.today.scanIn');
    });
  });
}
