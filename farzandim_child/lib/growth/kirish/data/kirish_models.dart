// Kirish (A01–A12) ma'lumotlari: bolaning login/parol bilan kirishi, birinchi
// sozlash, akkauntni tiklash so'rovi va maktabga 6 xonali kod bilan ulanish
// (docs/KIRISH-AUTH-API.md, docs/KIRISH-SCHOOL-API.md).

import 'dart:convert';

import 'package:farzandim_child/features/school/domain/school_json.dart';

/// Login formati (server bilan bir xil): kichik lotin harfi bilan boshlanadi.
final kLoginPattern = RegExp(r'^[a-z][a-z0-9._]{3,23}$');

/// Bola paroli (server siyosati bilan bir xil): 8–64 belgi va UTF-8 da ko'pi
/// bilan 72 bayt (bcrypt ortig'ini kesib tashlaydi), kamida bitta harf
/// (istalgan alifbo) va bitta raqam.
const kPasswordMin = 8;
const kPasswordMax = 64;
const kPasswordMaxBytes = 72;

/// Maktab kodi — 6 ta raqam (boshida nol bo'lishi mumkin).
const kSchoolCodeLength = 6;

/// «Uzun» parol uchun kuch belgisi chegarasi.
const _strongLength = 12;

/// Harf — istalgan alifbo (server `\p{L}`); raqam — faqat 0–9 (server `\d`).
final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\d');
final _lower = RegExp(r'\p{Ll}', unicode: true);
final _upper = RegExp(r'\p{Lu}', unicode: true);
final _symbol = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// Parol siyosati buzilishi — server `WEAK_PASSWORD.reason` bilan bir xil.
enum PasswordIssue {
  tooShort,
  tooLong,
  needsLetter,
  needsDigit,
  sameAsLogin,

  /// Keng tarqalgan parol (faqat server tekshiradi).
  tooCommon,

  /// Yangi parol joriy / vaqtinchalik parolning o'zi (faqat server tekshiradi).
  sameAsCurrent;

  /// Server `reason` qiymati; noma'lumi — `null`.
  static PasswordIssue? fromWire(Object? reason) => switch (reason) {
    'TOO_SHORT' => tooShort,
    'TOO_LONG' => tooLong,
    'NEEDS_LETTER' => needsLetter,
    'NEEDS_DIGIT' => needsDigit,
    'SAME_AS_LOGIN' => sameAsLogin,
    'TOO_COMMON' => tooCommon,
    'SAME_AS_CURRENT' => sameAsCurrent,
    _ => null,
  };
}

/// Ilovada tekshirsa bo'ladigan birinchi muammo (server tartibida); `null` —
/// qoidaga mos. Uzunlik — Unicode belgilar soni (server kabi).
PasswordIssue? passwordIssue(String password, {String? login}) {
  final length = password.runes.length;
  if (length < kPasswordMin) return PasswordIssue.tooShort;
  if (length > kPasswordMax ||
      utf8.encode(password).length > kPasswordMaxBytes) {
    return PasswordIssue.tooLong;
  }
  if (!_letter.hasMatch(password)) return PasswordIssue.needsLetter;
  if (!_digit.hasMatch(password)) return PasswordIssue.needsDigit;
  if (login != null && password.toLowerCase() == login.toLowerCase()) {
    return PasswordIssue.sameAsLogin;
  }
  return null;
}

bool isStrongEnough(String password, {String? login}) =>
    passwordIssue(password, login: login) == null;

/// Parol kuchi (A09 belgisi uchun): 0 — juda kuchsiz … 3 — kuchli.
int passwordStrength(String password) {
  if (password.isEmpty) return 0;
  final length = password.runes.length;
  var score = 0;
  if (length >= kPasswordMin) score++;
  if (_letter.hasMatch(password) && _digit.hasMatch(password)) score++;
  if (length >= _strongLength ||
      _symbol.hasMatch(password) ||
      (_lower.hasMatch(password) && _upper.hasMatch(password))) {
    score++;
  }
  return score;
}

/// Bu qurilma bola uchun: asosiy (ota-ona nazorati shu yerda) yoki qo'shimcha.
enum DeviceRole { main, secondary }

/// Muvaffaqiyatli kirish — tokenlar va bola.
class ChildSession {
  const ChildSession({
    required this.accessToken,
    required this.refreshToken,
    required this.childId,
    required this.childName,
    required this.role,
    this.sessionId,
    this.parentId,
    this.userId,
  });

  static ChildSession? tryFromJson(Object? json) {
    if (json is! Map || json['status'] != 'OK') return null;
    final access = jsonNonEmpty(json['accessToken']);
    final refresh = jsonNonEmpty(json['refreshToken']);
    final child = json['child'];
    final childId = child is Map ? jsonNonEmpty(child['id']) : null;
    if (access == null || refresh == null || childId == null) return null;
    return ChildSession(
      accessToken: access,
      refreshToken: refresh,
      childId: childId,
      childName: child is Map ? jsonText(child['name']) : '',
      sessionId: jsonNonEmpty(json['sessionId']),
      parentId: child is Map ? jsonNonEmpty(child['parentId']) : null,
      userId: json['user'] is Map
          ? jsonNonEmpty((json['user'] as Map)['id'])
          : null,
      role: json['deviceRole'] == 'MAIN'
          ? DeviceRole.main
          : DeviceRole.secondary,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String childId;
  final String childName;
  final String? sessionId;
  final DeviceRole role;

  /// Bolaning ota-onasi (server `child.parentId`; eski javoblarda yo'q).
  final String? parentId;

  /// Bolaning foydalanuvchi id'si (`user.id`) — yozishmalarda yo'nalish.
  final String? userId;
}

/// Kirish natijasi: tayyor sessiya yoki birinchi sozlash (A09) kerak.
sealed class LoginResult {
  const LoginResult();

  static LoginResult? tryFromJson(Object? json) {
    if (json is! Map) return null;
    if (json['status'] == 'SETUP_REQUIRED') {
      final token = jsonNonEmpty(json['setupToken']);
      final child = json['child'];
      if (token == null) return null;
      return LoginNeedsSetup(
        setupToken: token,
        childName: child is Map ? jsonText(child['name']) : '',
      );
    }
    final session = ChildSession.tryFromJson(json);
    return session == null ? null : LoginOk(session);
  }
}

final class LoginOk extends LoginResult {
  const LoginOk(this.session);

  final ChildSession session;
}

final class LoginNeedsSetup extends LoginResult {
  const LoginNeedsSetup({required this.setupToken, required this.childName});

  final String setupToken;
  final String childName;
}

/// Kirish xatolari.
enum KirishError {
  /// Login yoki parol noto'g'ri (boshqa akkaunt haqida hech narsa aytilmaydi).
  invalidCredentials,

  /// Juda ko'p urinish — [KirishException.retryAfter] dan keyin.
  locked,

  /// So'rovlar chegarasi (IP / kunlik limit) — blok emas, keyinroq urinish.
  rateLimited,

  /// Vaqtinchalik parol to'g'ri, lekin muddati (14 kun) o'tgan.
  tempExpired,

  /// Maktab kodi ishlamadi (xato, muddati o'tgan yoki band).
  codeInvalid,

  /// Tiklash so'rovi topilmadi (`404 NOT_FOUND`): chipta yaroqsiz yoki
  /// so'rov o'chirilgan (30 kundan keyin) — endi faol emas.
  notFound,

  /// Bola allaqachon boshqa o'quvchiga ulangan.
  alreadyEnrolled,

  /// Yangi parol siyosatga mos emas (`400 WEAK_PASSWORD`); sababi —
  /// [KirishException.passwordIssue].
  weakPassword,

  /// Ma'lumot noto'g'ri (boshqa 400 / 422).
  validation,

  /// Sozlash havolasi eskirgan — qaytadan kirish kerak.
  setupExpired,

  /// Akkauntga login berilmagan (oila kodi bilan ulangan) — parol yo'q.
  noCredential,

  network,
  unknown,
}

class KirishException implements Exception {
  const KirishException(this.error, {this.retryAfter, this.passwordIssue});

  final KirishError error;
  final Duration? retryAfter;

  /// [KirishError.weakPassword] sababi (server noma'lum sabab bersa — `null`).
  final PasswordIssue? passwordIssue;

  @override
  String toString() => 'KirishException($error)';
}

/// Tiklash kanali (A03).
enum RecoveryChannel { parent, school }

/// Tiklash so'rovi chiptasi — holatni so'rash uchun (qurilmada saqlanadi).
class RecoveryTicket {
  const RecoveryTicket({
    required this.requestId,
    required this.pollToken,
    required this.channel,
    required this.createdAt,
  });

  static RecoveryTicket? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = jsonNonEmpty(json['requestId']);
    final token = jsonNonEmpty(json['pollToken']);
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (id == null || token == null) return null;
    return RecoveryTicket(
      requestId: id,
      pollToken: token,
      channel: json['channel'] == 'SCHOOL'
          ? RecoveryChannel.school
          : RecoveryChannel.parent,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  final String requestId;
  final String pollToken;
  final RecoveryChannel channel;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'requestId': requestId,
    'pollToken': pollToken,
    'channel': channel == RecoveryChannel.school ? 'SCHOOL' : 'PARENT',
    'createdAt': createdAt.toIso8601String(),
  };

  /// Bir xil so'rov (holat provayderi kaliti sifatida ishlatiladi).
  @override
  bool operator ==(Object other) =>
      other is RecoveryTicket &&
      other.requestId == requestId &&
      other.pollToken == pollToken;

  @override
  int get hashCode => Object.hash(requestId, pollToken);
}

enum RecoveryState { received, restored, rejected }

/// Tiklash holati (A04).
class RecoveryStatus {
  const RecoveryStatus({
    required this.state,
    required this.createdAt,
    this.channel,
    this.restoredAt,
    this.signedOutAt,
  });

  static RecoveryStatus? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final createdAt = jsonInstant(json['createdAt']);
    if (createdAt == null) return null;
    return RecoveryStatus(
      state: switch (json['status']) {
        'RESTORED' => RecoveryState.restored,
        'REJECTED' => RecoveryState.rejected,
        _ => RecoveryState.received,
      },
      createdAt: createdAt,
      channel: switch (json['channel']) {
        'SCHOOL' => RecoveryChannel.school,
        'PARENT' => RecoveryChannel.parent,
        _ => null,
      },
      restoredAt: jsonInstant(json['restoredAt']),
      signedOutAt: jsonInstant(json['signedOutAt']),
    );
  }

  final RecoveryState state;
  final DateTime createdAt;

  /// Kim tiklaydi — server maktab o'rniga ota-onaga o'tkazgan bo'lishi mumkin
  /// (bola maktabga bog'lanmagan bo'lsa); chiptadagidan ustun.
  final RecoveryChannel? channel;
  final DateTime? restoredAt;
  final DateTime? signedOutAt;
}

/// O'quvchi sloti holati (A07).
enum StudentLinkState { none, underReview, confirmed, correction }

/// Ota-ona sloti holati (A07).
enum ParentLinkState { none, pending, underReview, confirmed, expired }

/// `GET /child/school/link-status`.
class LinkStatus {
  const LinkStatus({
    required this.student,
    required this.parent,
    this.schoolName,
    this.className,
    this.expiresAt,
  });

  static const none = LinkStatus(
    student: StudentLinkState.none,
    parent: ParentLinkState.none,
  );

  static LinkStatus fromJson(Object? json) {
    if (json is! Map) return none;
    final student = json['student'];
    final parent = json['parent'];
    final state = switch (student is Map ? student['status'] : null) {
      'UNDER_REVIEW' => StudentLinkState.underReview,
      'CONFIRMED' => StudentLinkState.confirmed,
      'CORRECTION' => StudentLinkState.correction,
      _ => StudentLinkState.none,
    };
    final confirmed = state == StudentLinkState.confirmed;
    return LinkStatus(
      student: state,
      parent: switch (parent is Map ? parent['status'] : null) {
        'PENDING' => ParentLinkState.pending,
        // Ota-ona kod kiritdi, telefoni maktabda yo'q — xodim tekshiradi.
        'UNDER_REVIEW' => ParentLinkState.underReview,
        'CONFIRMED' => ParentLinkState.confirmed,
        'EXPIRED' => ParentLinkState.expired,
        _ => ParentLinkState.none,
      },
      // Maktab va sinf nomi faqat tasdiqlangach ko'rsatiladi.
      schoolName: confirmed && student is Map
          ? jsonNonEmpty(student['schoolName'])
          : null,
      className: confirmed && student is Map
          ? jsonNonEmpty(student['className'])
          : null,
      expiresAt: jsonInstant(json['expiresAt']),
    );
  }

  final StudentLinkState student;
  final ParentLinkState parent;
  final String? schoolName;
  final String? className;
  final DateTime? expiresAt;
}

/// Ta'lim tili (A06). Qoraqalpoq — ta'lim tili sifatida tanlanadi (ilova
/// interfeysi hali o'zbek/rus/ingliz).
enum EducationLanguage { uz, ru, kaa }
