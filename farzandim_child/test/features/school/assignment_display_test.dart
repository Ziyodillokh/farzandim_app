// Maktab topshiriqlari ko'rsatish qoidalari (sof funksiyalar): muddat holati
// (Toshkent kuni), ro'yxat tartibi, bosilganda ochiladigan joy va kitob
// qismidan butun kitobni topish.

import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/assignment_display.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'school_fixtures.dart';

SchoolAssignment _assignment(Map<String, Object?> changes) =>
    SchoolAssignment.tryFromJson({...schoolAssignmentJson, ...changes})!;

AudiobookModel _book(String id, String title) => AudiobookModel(
  id: id,
  title: title,
  author: 'Abdulla Qodiriy',
  description: '',
  coverUrl: '',
  audioUrl: '',
  durationSeconds: 600,
  duration: '10:00',
  category: 'Adabiyot',
  hashtags: const [],
  listenCount: 0,
  coverColor: const Color(0xFF000000),
);

void main() {
  // Toshkent kuni — 2026-10-20 (soat ahamiyatsiz).
  final today = DateTime(2026, 10, 20, 23, 30);

  group('muddat holati', () {
    AssignmentDueState stateFor(Map<String, Object?> changes) =>
        assignmentDueState(_assignment(changes), today);

    test('test bajarilgan — "bajarildi" (muddatdan qat\'i nazar)', () {
      expect(
        stateFor({'done': true, 'overdue': true}),
        AssignmentDueState.done,
      );
    });

    test('bugun, ertaga, keyinroq va sanasiz', () {
      final pending = {'done': false, 'overdue': false};
      expect(
        stateFor({...pending, 'dueDate': '2026-10-20'}),
        AssignmentDueState.today,
      );
      expect(
        stateFor({...pending, 'dueDate': '2026-10-21'}),
        AssignmentDueState.tomorrow,
      );
      expect(
        stateFor({...pending, 'dueDate': '2026-11-02'}),
        AssignmentDueState.upcoming,
      );
      expect(
        stateFor({...pending, 'dueDate': null}),
        AssignmentDueState.noDate,
      );
    });

    test('server "muddati o\'tgan" desa yoki sana o\'tib ketsa — o\'tgan', () {
      expect(
        stateFor({'done': false, 'overdue': true, 'dueDate': '2026-10-25'}),
        AssignmentDueState.overdue,
      );
      // Ilova kecha yuklangan ro'yxat bilan ochiq qolgan.
      expect(
        stateFor({'done': false, 'overdue': false, 'dueDate': '2026-10-19'}),
        AssignmentDueState.overdue,
      );
    });

    test('audiokitob hech qachon "bajarildi" bo\'lmaydi (server bilmaydi)', () {
      final book = _assignment({
        'kind': 'AUDIOBOOK',
        'materialId': 'audiobook:b-1',
        'subject': null,
        'done': null,
        'dueDate': '2026-10-21',
      });
      expect(book.isPending, isTrue);
      expect(assignmentDueState(book, today), AssignmentDueState.tomorrow);
    });
  });

  test('ro\'yxat: bajarilmaganlar birinchi, server tartibi saqlanadi', () {
    final done = _assignment({'id': 'done', 'done': true});
    final first = _assignment({'id': 'first', 'done': false});
    final book = _assignment({'id': 'book', 'kind': 'AUDIOBOOK', 'done': null});
    final items = [done, first, book];

    expect(assignmentsForDisplay(items).map((a) => a.id), [
      'first',
      'book',
      'done',
    ]);
    expect(pendingAssignmentCount(items), 2);
    expect(assignmentsForDisplay(const []), isEmpty);
  });

  group('bosilganda ochiladigan joy', () {
    test('test — shu fanning kunlik testi', () {
      final target = assignmentTargetOf(_assignment({'subject': 'PHYSICS'}));
      expect(
        target,
        isA<AssignmentOpensQuiz>().having(
          (t) => t.subject,
          'subject',
          Subject.physics,
        ),
      );
    });

    test('noma\'lum fan yoki material — hech narsa', () {
      expect(
        assignmentTargetOf(_assignment({'subject': 'ASTRONOMY'})),
        isA<AssignmentOpensNothing>(),
      );
      expect(
        assignmentTargetOf(_assignment({'kind': 'PODCAST'})),
        isA<AssignmentOpensNothing>(),
      );
    });

    test('audiokitob — id bilan; id o\'qilmasa — ro\'yxat', () {
      final book = _assignment({
        'kind': 'AUDIOBOOK',
        'materialId': 'audiobook:b-7',
        'subject': null,
      });
      expect(
        assignmentTargetOf(book),
        isA<AssignmentOpensAudiobook>().having(
          (t) => t.audiobookId,
          'audiobookId',
          'b-7',
        ),
      );
      final broken = _assignment({
        'kind': 'AUDIOBOOK',
        'materialId': 'audiobook:',
      });
      expect(
        assignmentTargetOf(broken),
        isA<AssignmentOpensAudiobook>().having(
          (t) => t.audiobookId,
          'audiobookId',
          isNull,
        ),
      );
    });

    test('video — videolar ro\'yxati', () {
      expect(
        assignmentTargetOf(_assignment({'kind': 'VIDEO', 'subject': null})),
        isA<AssignmentOpensVideos>(),
      );
    });
  });

  test('kitob qismidan butun kitob (barcha qismlari bilan) topiladi', () {
    final books = [
      _book('p2', 'Mehrobdan chayon 2'),
      _book('other', 'Shum bola'),
      _book('p1', 'Mehrobdan chayon 1'),
    ];

    final series = seriesContaining(books, 'p2');
    expect(series?.title, 'Mehrobdan chayon');
    expect(series?.parts.map((p) => p.id), ['p1', 'p2']);
    expect(seriesContaining(books, 'other')?.parts.single.id, 'other');
    expect(seriesContaining(books, 'missing'), isNull);
    expect(seriesContaining(const [], 'p1'), isNull);
  });
}
