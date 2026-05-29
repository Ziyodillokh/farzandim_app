// ─────────────────────────────────────────────────────────────────────
// MockQuestions — 10 ta mock savol (turli sohalar)
// ─────────────────────────────────────────────────────────────────────

import 'package:farzandim_child/features/contests/data/models/question_model.dart';

class MockQuestions {
  MockQuestions._();

  static const List<QuestionModel> all = [
    QuestionModel(
      id: 'q1',
      text: 'Quyosh tizimida nechta sayyora bor?',
      options: ['7', '8', '9', '10'],
      correctIndex: 1,
      explanation:
          'Pluto sayyora emas deb tan olingach 8 ta sayyora qoldi.',
    ),
    QuestionModel(
      id: 'q2',
      text: "O'zbekistonning poytaxti qaysi shahar?",
      options: ['Samarqand', 'Buxoro', 'Toshkent', 'Andijon'],
      correctIndex: 2,
      explanation: 'Toshkent 1930 yildan beri poytaxt.',
    ),
    QuestionModel(
      id: 'q3',
      text: 'Eng katta sayyora qaysi?',
      options: ['Saturn', 'Yer', 'Yupiter', 'Mars'],
      correctIndex: 2,
      explanation: 'Yupiter — eng katta gaz sayyorasi.',
    ),
    QuestionModel(
      id: 'q4',
      text: '5 + 7 × 2 = ?',
      options: ['24', '19', '14', '12'],
      correctIndex: 1,
      explanation: "Avval ko'paytirish: 7×2=14, keyin 5+14=19.",
    ),
    QuestionModel(
      id: 'q5',
      text: "Kompyuterning 'miya' qismi qaysi?",
      options: ['RAM', 'Protsessor', 'Disk', 'Klaviatura'],
      correctIndex: 1,
      explanation: 'Protsessor (CPU) hisoblashlarni bajaradi.',
    ),
    QuestionModel(
      id: 'q6',
      text: 'Suvning kimyoviy formulasi?',
      options: ['CO2', 'O2', 'H2O', 'N2'],
      correctIndex: 2,
    ),
    QuestionModel(
      id: 'q7',
      text: "Alisher Navoiy qachon tug'ilgan?",
      options: ['1441', '1500', '1380', '1550'],
      correctIndex: 0,
      explanation: "Navoiy 1441 yilda Hirot shahrida tug'ilgan.",
    ),
    QuestionModel(
      id: 'q8',
      text: "Ingliz tilida 'apple' nima ma'noni anglatadi?",
      options: ['Banan', 'Olma', 'Anor', 'Uzum'],
      correctIndex: 1,
    ),
    QuestionModel(
      id: 'q9',
      text:
          'Eng tez sport mashinasi qaysi mamlakatlarda ishlab chiqariladi?',
      options: [
        'Germaniya',
        'Italiya',
        'Yaponiya',
        'Italiya, Germaniya, AQSh'
      ],
      correctIndex: 3,
      explanation:
          'Bugatti, Lamborghini, Ferrari, Koenigsegg, SSC va boshqalar.',
    ),
    QuestionModel(
      id: 'q10',
      text: 'Bir yilda nechta oy bor?',
      options: ['10', '11', '12', '13'],
      correctIndex: 2,
    ),
  ];
}
