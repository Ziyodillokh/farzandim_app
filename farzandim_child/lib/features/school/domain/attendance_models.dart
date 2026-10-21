// Maktab davomati: bugungi holat (`GET /child/school/today`) va kiosk QR
// orqali kirish natijasi (`POST /child/school/check-in`). Vaqtlar —
// Toshkent devor soati (`"HH:MM"`), server shunday yuboradi.

import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Davomat holati.
enum AttendanceStatus implements WireEnum {
  present('PRESENT'),
  late('LATE'),
  absent('ABSENT'),
  leftEarly('LEFT_EARLY'),
  excused('EXCUSED'),
  unknown('');

  const AttendanceStatus(this.wire);

  @override
  final String wire;

  static AttendanceStatus fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Davomat qayd etilgan manba.
enum AttendanceSource implements WireEnum {
  qr('QR'),
  kiosk('KIOSK'),
  manual('MANUAL'),
  system('SYSTEM'),
  unknown('');

  const AttendanceSource(this.wire);

  @override
  final String wire;

  static AttendanceSource fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// Sinf smenasi (dars vaqti).
class SchoolShift {
  const SchoolShift({
    required this.name,
    required this.start,
    required this.end,
  });

  /// Boshlanish yoki tugash vaqti noto'g'ri bo'lsa `null`.
  static SchoolShift? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final start = jsonClock(json['start']);
    final end = jsonClock(json['end']);
    if (start == null || end == null) return null;
    return SchoolShift(name: jsonText(json['name']), start: start, end: end);
  }

  final String name;

  /// `"HH:MM"`.
  final String start;

  /// `"HH:MM"`.
  final String end;
}

/// Bugungi davomat yozuvi.
class AttendanceRecord {
  const AttendanceRecord({
    required this.status,
    required this.source,
    this.inAt,
    this.outAt,
  });

  static AttendanceRecord? tryFromJson(Object? json) {
    if (json is! Map) return null;
    return AttendanceRecord(
      status: AttendanceStatus.fromWire(json['status']),
      source: AttendanceSource.fromWire(json['source']),
      inAt: jsonClock(json['inAt']),
      outAt: jsonClock(json['outAt']),
    );
  }

  final AttendanceStatus status;
  final AttendanceSource source;

  /// Kelgan vaqt (`"HH:MM"`) — `null`: hali kelmagan.
  final String? inAt;

  /// Ketgan vaqt (`"HH:MM"`) — `null`: hali ketmagan.
  final String? outAt;
}

/// Bugungi maktab holati. Server `today: null` qaytarsa bola maktabga
/// bog'lanmagan — barcha maktab UI'si shu bo'yicha yashiriladi.
class SchoolToday {
  const SchoolToday({
    required this.schoolName,
    this.date,
    this.className,
    this.shift,
    this.isSchoolDay = true,
    this.record,
  });

  static SchoolToday? tryFromJson(Object? json) {
    if (json is! Map) return null;
    return SchoolToday(
      schoolName: jsonText(json['schoolName']),
      date: jsonDay(json['date']),
      className: jsonNonEmpty(json['className']),
      shift: SchoolShift.tryFromJson(json['shift']),
      isSchoolDay: json['schoolDay'] != false,
      record: AttendanceRecord.tryFromJson(json['record']),
    );
  }

  final String schoolName;

  /// Bugungi sana (Toshkent, vaqtsiz).
  final DateTime? date;

  /// Sinf nomi ("5-A") — sinfga biriktirilmagan bo'lsa `null`.
  final String? className;
  final SchoolShift? shift;

  /// O'quv kuni (dam olish yoki bayram emas).
  final bool isSchoolDay;

  /// Bugungi yozuv — `null`: hali qayd etilmagan.
  final AttendanceRecord? record;

  /// "QR orqali kirish" ko'rsatiladi: o'quv kuni va bola hali chiqmagan.
  bool get canScan => isSchoolDay && record?.outAt == null;
}

/// Kiosk QR natijasi.
enum CheckInAction implements WireEnum {
  /// `IN` — bugun birinchi skanerlash: keldi (yoki kechikib keldi).
  arrived('IN'),

  /// `OUT` — dars tugagach chiqib ketdi.
  departed('OUT'),

  /// `NONE` — allaqachon belgilangan (takroriy skanerlash).
  none('NONE'),
  unknown('');

  const CheckInAction(this.wire);

  @override
  final String wire;

  static CheckInAction fromWire(Object? value) =>
      enumFromWire(values, value, unknown);
}

/// `POST /child/school/check-in` javobi.
class CheckInResult {
  const CheckInResult({required this.action, this.today});

  static CheckInResult? tryFromJson(Object? json) {
    if (json is! Map) return null;
    return CheckInResult(
      action: CheckInAction.fromWire(json['action']),
      today: SchoolToday.tryFromJson(json['today']),
    );
  }

  final CheckInAction action;

  /// Skanerlashdan keyingi bugungi holat.
  final SchoolToday? today;
}
