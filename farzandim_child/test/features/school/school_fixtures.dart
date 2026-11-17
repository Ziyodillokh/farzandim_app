// Server javoblari namunalari — backend `/child/school/*` shakli
// (attendance-child, care-child, assessments child-view, school-learning).

const todayJson = <String, Object?>{
  'date': '2026-10-20',
  'schoolName': 'Parvoz maktabi',
  'className': '5-A',
  'shift': {'name': '1-smena', 'start': '08:00', 'end': '13:25'},
  'schoolDay': true,
  'record': {'status': 'LATE', 'inAt': '08:12', 'outAt': null, 'source': 'QR'},
};

const careSurveyJson = <String, Object?>{
  'enrolled': true,
  'answered': false,
  'survey': {
    'id': 'survey-1',
    'title': 'Haftalik so‘rovnoma',
    'questions': [
      {'id': 'q1', 'text': 'Maktabda o‘zingizni xavfsiz his qilasizmi?'},
      {'id': 'q2', 'text': 'Do‘stlaringiz bilan munosabat qanday?'},
    ],
  },
};

const careRequestJson = <String, Object?>{
  'id': 'req-1',
  'topic': 'PEERS',
  'urgency': 'NORMAL',
  'status': 'SCHEDULED',
  'createdAt': '2026-10-19T06:30:00.000Z',
  'meetingAt': '2026-10-21T09:00:00.000Z',
};

const psychSummaryJson = <String, Object?>{
  'assignmentId': 'assign-1',
  'testId': 'test-1',
  'kind': 'ATTENTION',
  'title': 'Diqqat testi',
  'description': 'Qisqa mashq',
  'itemCount': 3,
  'timeLimitMin': 10,
  'closesAt': '2026-10-25T13:00:00.000Z',
};

const psychTestJson = <String, Object?>{
  'assignmentId': 'assign-1',
  'closesAt': '2026-10-25T13:00:00.000Z',
  'testId': 'test-1',
  'kind': 'ATTENTION',
  'title': 'Diqqat testi',
  'description': 'Qisqa mashq',
  'instructions': 'Savollarni diqqat bilan o‘qing',
  'timeLimitMin': 10,
  'likert': {'min': 1, 'max': 5},
  'items': [
    {
      'id': 's1',
      'type': 'SINGLE',
      'text': 'Qaysi raqam ko‘rsatildi?',
      'options': [
        {'key': 'a', 'text': '7'},
        {'key': 'b', 'text': '9'},
      ],
      'stimulus': {'text': '7', 'showSec': 3},
    },
    {'id': 'l1', 'type': 'LIKERT', 'text': 'Darsda diqqatim tez tarqaladi'},
    {
      'id': 'm1',
      'type': 'MULTI',
      'text': 'Qaysilari meva?',
      'options': [
        {'key': 'x', 'text': 'Olma'},
        {'key': 'y', 'text': 'Sabzi'},
        {'key': 'z', 'text': 'Nok'},
      ],
    },
  ],
};

const schoolAssignmentJson = <String, Object?>{
  'id': 'sa-1',
  'kind': 'TEST',
  'materialId': 'test:MATH',
  'title': 'Kunlik test: Matematika',
  'subject': 'MATH',
  'dueDate': '2026-10-22',
  'note': 'Juma kunigacha',
  'overdue': false,
  'done': true,
};
