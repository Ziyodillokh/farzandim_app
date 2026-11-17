// Modellar bardoshliligi (haqiqiy fixture'larning o'zgartirilgan nusxalari):
// noma'lum enum, yo'q ixtiyoriy maydon va buzilgan ro'yxat elementlari
// ilovani yiqitmaydi.

import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_overview.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_session.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kelajak_fixtures.dart';

void main() {
  group('bardoshlilik', () {
    test('noma\'lum enum qiymatlari — unknown', () {
      final json = fixture('overview_ok_with_profile');
      json['age']['status'] = 'TEEN';
      json['tests'][0]['today']['status'] = 'PAUSED';
      json['tests'][0]['type'] = 'astrology';
      final insights = json['profile']['insights'];
      insights['support']['level'] = 'urgent';
      insights['next'][0]['kind'] = 'party';
      insights['triedDirections'][0]['verdict'] = 'meh';

      final overview = KelajakOverview.fromJson(json);
      expect(overview.age.status, KelajakAgeStatus.unknown);
      expect(overview.tests.first.today.status, KelajakTodayStatus.unknown);
      expect(overview.tests.first.testType, KelajakTestType.unknown);
      final parsed = overview.profile!.insights;
      expect(parsed.support?.level, KelajakSupportLevel.unknown);
      expect(parsed.support?.needsAttention, isFalse);
      expect(parsed.next.first.kind, KelajakNextKind.unknown);
      expect(parsed.triedDirections.first.verdict, KelajakVerdict.unknown);

      final sessionJson = fixture('session_start_daily');
      sessionJson['status'] = 'PAUSED';
      sessionJson['questions'][0]['answerType'] = 'slider';
      final s = KelajakSession.fromJson(sessionJson);
      expect(s.status, KelajakSessionStatus.unknown);
      expect(s.isOpen, isFalse);
      expect(s.questions.first.answerType, KelajakAnswerType.unknown);
      expect(s.questions.first.isChoice, isTrue);
    });

    test('ixtiyoriy maydonlar yo\'q — zaxira qiymatlar', () {
      final json = fixture('session_start_voice');
      final question = json['questions'][0] as Map<String, dynamic>;
      question
        ..remove('required')
        ..remove('maxLength')
        ..remove('categoryName')
        ..remove('externalId');
      json
        ..remove('title')
        ..remove('day')
        ..remove('startedAt')
        ..remove('result');
      final s = KelajakSession.fromJson(json);
      expect(s.title, isNull);
      expect(s.day, isNull);
      final q = s.questions.first;
      expect(q.isRequired, isFalse);
      expect(q.textLimit, kKelajakTextMaxLength);
      expect(q.categoryName, isNull);
      expect(q.externalId, isNull);

      final scale = fixture('session_start_daily');
      (scale['questions'][0] as Map<String, dynamic>).remove('required');
      expect(KelajakSession.fromJson(scale).questions.first.isRequired, isTrue);

      final overview = fixture('overview_ok_fresh')
        ..remove('profile')
        ..remove('categories');
      final parsed = KelajakOverview.fromJson(overview);
      expect(parsed.profile, isNull);
      expect(parsed.categories, isEmpty);
    });

    test('buzilgan ro\'yxat elementlari va takrorlar tashlanadi', () {
      final json = fixture('session_daily_in_progress');
      final questions = json['questions'] as List<dynamic>;
      final answers = json['answers'] as List<dynamic>;
      questions
        ..add({'id': 'no-text'})
        ..add('not-a-map')
        ..add(Map<String, dynamic>.from(questions.first as Map));
      answers
        ..add({'questionId': 'unknown-question', 'value': 3})
        ..add({'value': 3});
      final s = KelajakSession.fromJson(json);
      expect(s.questions, hasLength(10));
      expect(s.answers, hasLength(3));

      final insights = KelajakInsights.fromJson({
        'strengths': [
          {'key': 'learning'},
          'x',
        ],
        'support': {'level': 'watch'},
        'next': null,
      });
      expect(insights.strengths, isEmpty);
      expect(insights.support, isNull);
      expect(insights.next, isEmpty);
      expect(KelajakInsights.fromJson(null), same(KelajakInsights.empty));
    });

    test('tarjima yo\'q bo\'lsa o\'zbekchasi', () {
      final q = session('session_start_daily').questions.first;
      expect(q.text.of('ru'), q.text.of('uz'));
    });

    test('majburiy maydonsiz javob — FormatException', () {
      expect(
        () => KelajakSession.fromJson({'type': 'daily'}),
        throwsFormatException,
      );
      expect(() => KelajakOverview.fromJson([]), throwsFormatException);
      expect(() => KelajakAnswerAck.fromJson({}), throwsFormatException);
      expect(() => KelajakProgress.fromJson('x'), throwsFormatException);
      expect(() => KelajakResultsPage.fromJson(null), throwsFormatException);
    });
  });
}
