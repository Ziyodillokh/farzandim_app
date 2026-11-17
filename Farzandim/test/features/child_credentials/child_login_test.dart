// ChildLogin: backend naqshi `^[a-z][a-z0-9._]{3,23}$`, kichik harfga
// o'tkazish va qaysi qoida buzilgani (foydalanuvchiga aniq xabar).

import 'dart:math';

import 'package:farzandim/features/child_credentials/data/child_login.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValid', () {
    test('backend naqshiga mos loginlar', () {
      for (final login in [
        'aziza.k24',
        'abcd',
        'a_b.c',
        'a123',
        'parvoz4821',
        'a...',
        'a___',
        'z' * 24,
      ]) {
        expect(ChildLogin.isValid(login), isTrue, reason: login);
      }
    });

    test('chegaralar: 4 belgi — ha, 3 belgi — yo`q; 24 — ha, 25 — yo`q', () {
      expect(ChildLogin.isValid('abcd'), isTrue);
      expect(ChildLogin.isValid('abc'), isFalse);
      expect(ChildLogin.isValid('a' * 24), isTrue);
      expect(ChildLogin.isValid('a' * 25), isFalse);
    });

    test('kichik harfga o`tkaziladi, chetdagi bo`shliq olinadi', () {
      expect(ChildLogin.isValid('Aziza.K24'), isTrue);
      expect(ChildLogin.isValid('  aziza.k24 '), isTrue);
      expect(ChildLogin.normalize('  Aziza.K24 '), 'aziza.k24');
    });

    test('rad etiladi: raqam yoki belgidan boshlanadi, begona belgi', () {
      for (final login in [
        '',
        '1abc',
        '.abc',
        '_abc',
        'ab cd',
        'ab-cd',
        'ab@cd',
        'abc!',
        // Kirill "а" lotin "a"ga o'xshaydi, lekin boshqa belgi.
        'аzizа',
        'ази',
        "o'ral",
      ]) {
        expect(ChildLogin.isValid(login), isFalse, reason: login);
      }
    });
  });

  group('validate — qaysi qoida buzilgan', () {
    test('to`g`ri login — null', () {
      expect(ChildLogin.validate('aziza.k24'), isNull);
      expect(ChildLogin.validate('ABCD'), isNull);
    });

    test('bo`sh yoki qisqa — tooShort', () {
      expect(ChildLogin.validate(''), ChildLoginIssue.tooShort);
      expect(ChildLogin.validate('   '), ChildLoginIssue.tooShort);
      expect(ChildLogin.validate('ab'), ChildLoginIssue.tooShort);
      expect(ChildLogin.validate('a1.'), ChildLoginIssue.tooShort);
    });

    test('uzun — tooLong', () {
      expect(ChildLogin.validate('a' * 25), ChildLoginIssue.tooLong);
    });

    test('lotin harfidan boshlanmasa — badStart', () {
      expect(ChildLogin.validate('1abc'), ChildLoginIssue.badStart);
      expect(ChildLogin.validate('_abc'), ChildLoginIssue.badStart);
      expect(ChildLogin.validate('азиза'), ChildLoginIssue.badStart);
    });

    test('ruxsat etilmagan belgi — badChars (uzunlikdan avval)', () {
      expect(ChildLogin.validate('ab cd'), ChildLoginIssue.badChars);
      expect(ChildLogin.validate('ab-cd'), ChildLoginIssue.badChars);
      expect(ChildLogin.validate('aziza_ь'), ChildLoginIssue.badChars);
      // Qisqa, lekin belgi noto'g'ri — avval belgi haqida aytiladi.
      expect(ChildLogin.validate('a-'), ChildLoginIssue.badChars);
    });

    test('har xato uchun tarjima kaliti bor', () {
      for (final issue in ChildLoginIssue.values) {
        expect(issue.messageKey, startsWith('childCredentials.login.'));
      }
    });
  });

  test('validate(null) bo`lsa — naqsh ham mos (tasodifiy matnlarda)', () {
    final random = Random(7);
    const alphabet = 'abcXYZ019._- @аь';
    for (var i = 0; i < 2000; i++) {
      final text = String.fromCharCodes([
        for (var j = 0; j < random.nextInt(30); j++)
          alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      expect(
        ChildLogin.validate(text) == null,
        ChildLogin.pattern.hasMatch(ChildLogin.normalize(text)),
        reason: '"$text"',
      );
    }
  });
}
