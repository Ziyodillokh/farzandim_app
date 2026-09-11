import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contestSubjectKey', () {
    test('admin sehrgaridagi aniq nomlar', () {
      expect(contestSubjectKey('Matematika'), 'matematika');
      expect(contestSubjectKey('Ona tili'), 'ona_tili');
      expect(contestSubjectKey('Ingliz tili'), 'ingliz');
      expect(contestSubjectKey('Fizika'), 'fizika');
      expect(contestSubjectKey('Kimyo'), 'kimyo');
      expect(contestSubjectKey('Biologiya'), 'biologiya');
      expect(contestSubjectKey('Geografiya'), 'geografiya');
      expect(contestSubjectKey('Tarix'), 'tarix');
      expect(contestSubjectKey('IT / Mantiq'), 'it');
    });

    test('registr, bo\'sh joy, qo\'shimcha va apostrof farqlari', () {
      expect(contestSubjectKey('  matematika 8-sinf '), 'matematika');
      expect(contestSubjectKey('GEOGRAFIYA'), 'geografiya');
      expect(contestSubjectKey('Oʻzbek tili'), 'ona_tili');
      expect(contestSubjectKey('O’zbek tili'), 'ona_tili');
      expect(contestSubjectKey('Informatika'), 'it');
      expect(contestSubjectKey('IT'), 'it');
    });

    test('"IT" prefiksi boshqa fanlarni tutib olmaydi', () {
      expect(contestSubjectKey('Italyan tili'), 'italyan tili');
    });

    test('noma\'lum fan — o\'z holicha, default rang/ikon', () {
      expect(contestSubjectKey('Astronomiya'), 'astronomiya');
      expect(contestSubjectColor('Astronomiya'), AppColors.catLavenderDark);
      expect(contestSubjectIcon('Astronomiya'), AppIcons.trophy);
      expect(contestSubjectKey(''), '');
    });
  });

  group('contestSubjectColor / Icon', () {
    test('yangi fanlar o\'z ikonkasini oladi', () {
      expect(contestSubjectIcon('Geografiya'), Icons.public_outlined);
      expect(contestSubjectIcon('Biologiya'), Icons.eco_outlined);
      expect(contestSubjectIcon('Tarix'), Icons.history_edu_outlined);
      expect(contestSubjectColor('Geografiya'), AppColors.catBlue);
    });

    test('sehrgar yozuvlari endi default emas (regressiya)', () {
      expect(contestSubjectIcon('Ingliz tili'), Icons.language_outlined);
      expect(contestSubjectIcon('IT / Mantiq'), Icons.code_outlined);
      expect(contestSubjectIcon('Ona tili'), Icons.menu_book_outlined);
    });
  });
}
