// Bola ovozi (H01–H10) testlari va skrinshotlari uchun soxta manbalar:
// anonim so'rov, mas'ul psixolog, murojaatlar va yozishma, qurilma navbati.

import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_outbox.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'g5_overrides.dart';

class FakeVoiceRepository implements VoiceRepository {
  FakeVoiceRepository({
    this.survey = VoiceSurveyState.none,
    this.contact = VoiceContact.unknown,
    List<VoiceRequestSummary> requests = const [],
    Map<String, VoiceRequest> details = const {},
    this.offline = false,
  }) : requests = [...requests],
       details = {...details};

  VoiceSurveyState survey;
  VoiceContact contact;
  final List<VoiceRequestSummary> requests;
  final Map<String, VoiceRequest> details;

  /// `true` — yuborish so'rovlari tarmoq xatosi bilan tugaydi.
  bool offline;

  final submittedSurveys = <({String id, Map<String, int> answers})>[];
  final created = <({String message, bool urgent, String clientRequestId})>[];
  final sentMessages = <({String requestId, String text})>[];

  @override
  Future<VoiceSurveyState> loadSurvey() async => survey;

  @override
  Future<void> submitSurvey(String surveyId, Map<String, int> answers) async {
    if (offline) throw const SchoolException(SchoolErrorCode.network);
    submittedSurveys.add((id: surveyId, answers: answers));
    survey = const VoiceSurveyState(answered: true);
  }

  @override
  Future<VoiceContact> loadContact() async => contact;

  @override
  Future<List<VoiceRequestSummary>> loadRequests() async => requests;

  @override
  Future<VoiceRequest> loadRequest(String id) async =>
      details[id] ?? (throw const SchoolException(SchoolErrorCode.unavailable));

  @override
  Future<VoiceRequest> createRequest({
    required String message,
    required bool urgent,
    required String clientRequestId,
  }) async {
    if (offline) throw const SchoolException(SchoolErrorCode.network);
    created.add((
      message: message,
      urgent: urgent,
      clientRequestId: clientRequestId,
    ));
    final request = VoiceRequest(
      id: 'srv-${created.length}',
      urgent: urgent,
      stage: VoiceStage.received,
      createdAt: kG5Now,
      messages: [
        VoiceMessage(
          id: 'm-${created.length}',
          fromChild: true,
          text: message,
          createdAt: kG5Now,
        ),
      ],
      handlerName: contact.psychologistName,
    );
    details[request.id] = request;
    requests.add(
      VoiceRequestSummary(
        id: request.id,
        urgent: urgent,
        stage: VoiceStage.received,
        createdAt: kG5Now,
      ),
    );
    return request;
  }

  @override
  Future<VoiceMessage> sendMessage({
    required String requestId,
    required String text,
    required String clientMessageId,
  }) async {
    if (offline) throw const SchoolException(SchoolErrorCode.network);
    sentMessages.add((requestId: requestId, text: text));
    final message = VoiceMessage(
      id: clientMessageId,
      fromChild: true,
      text: text,
      createdAt: kG5Now,
    );
    final current = details[requestId];
    if (current != null) details[requestId] = current.withMessage(message);
    return message;
  }
}

class MemoryOutboxStore implements VoiceOutboxStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

List<Override> voiceOverrides(
  FakeVoiceRepository voice, {
  MemoryOutboxStore? store,
}) => [
  voiceRepositoryProvider.overrideWithValue(voice),
  voiceOutboxStoreProvider.overrideWithValue(store ?? MemoryOutboxStore()),
];

const kVoiceContact = VoiceContact(
  psychologistName: 'Dilnoza opa',
  deputyName: 'Kamola opa',
  hours: VoiceHours(days: [1, 2, 3, 4, 5], start: '09:00', end: '17:00'),
  openNow: true,
);

VoiceSurveyState kVoiceSurvey() => VoiceSurveyState(
  answered: false,
  survey: VoiceSurvey(
    id: 's-nov',
    title: 'Noyabr',
    estimatedMinutes: 2,
    activatedAt: DateTime(2026, 11, 1, 9),
    questions: const [
      VoiceQuestion(
        id: 'q1',
        text: 'Maktabda oʻzingni xotirjam his qilasanmi?',
      ),
      VoiceQuestion(
        id: 'q2',
        text: 'Sinfdoshlaring bilan munosabating yaxshimi?',
      ),
      VoiceQuestion(
        id: 'q3',
        text: 'Qiynalganingda gaplasha oladigan katta bormi?',
      ),
    ],
  ),
);

final kVoiceRequests = [
  VoiceRequestSummary(
    id: 'r3',
    urgent: false,
    stage: VoiceStage.received,
    createdAt: DateTime(2026, 11, 3, 10, 5),
  ),
  VoiceRequestSummary(
    id: 'r2',
    urgent: false,
    stage: VoiceStage.opened,
    createdAt: DateTime(2026, 11, 1, 15, 40),
  ),
  VoiceRequestSummary(
    id: 'r1',
    urgent: false,
    stage: VoiceStage.replied,
    createdAt: DateTime(2026, 10, 28, 9, 12),
    unread: 1,
  ),
];

final kVoiceDetails = {
  'r2': VoiceRequest(
    id: 'r2',
    urgent: false,
    stage: VoiceStage.opened,
    createdAt: DateTime(2026, 11, 1, 15, 40),
    openedAt: DateTime(2026, 11, 2, 9, 30),
    handlerName: 'Dilnoza opa',
    messages: [
      VoiceMessage(
        id: 'm1',
        fromChild: true,
        text: 'Tanaffusda yolgʻiz qolyapman.',
        createdAt: DateTime(2026, 11, 1, 15, 40),
      ),
    ],
  ),
  'r1': VoiceRequest(
    id: 'r1',
    urgent: false,
    stage: VoiceStage.replied,
    createdAt: DateTime(2026, 10, 28, 9, 12),
    openedAt: DateTime(2026, 10, 28, 10, 1),
    repliedAt: DateTime(2026, 10, 28, 10, 24),
    handlerName: 'Dilnoza opa',
    messages: [
      VoiceMessage(
        id: 'm1',
        fromChild: true,
        text: 'Darslarga ulgurolmayapman, xavotirdaman.',
        createdAt: DateTime(2026, 10, 28, 9, 12),
      ),
      VoiceMessage(
        id: 'm2',
        fromChild: false,
        authorName: 'Dilnoza opa',
        text:
            'Salom! Seni tinglashga tayyorman. Ertaga 3-darsdan keyin 204-xonada gaplashamizmi?',
        createdAt: DateTime(2026, 10, 28, 10, 24),
      ),
    ],
  ),
};

const kPersonalSummary = PsychAssignmentSummary(
  assignmentId: 'p1',
  testId: 't-wb',
  kind: PsychKind.emotional,
  title: 'Kayfiyat va doʻstlar',
  description: '',
  itemCount: 3,
  isPersonal: true,
  assignedByName: 'Dilnoza opa',
  estimatedMinutes: 3,
);

const kPersonalTest = PsychTest(
  assignmentId: 'p1',
  testId: 't-wb',
  kind: PsychKind.emotional,
  title: 'Kayfiyat va doʻstlar',
  description: '',
  instructions: '',
  items: [
    PsychLikertItem(id: 'i1', text: 'Ertalab maktabga borishni xohlaysanmi?'),
    PsychSingleItem(
      id: 'i2',
      text: 'Tanaffusda koʻpincha nima qilasan?',
      options: [
        PsychOption(key: 'a', text: 'Doʻstlarim bilan oʻynayman'),
        PsychOption(key: 'b', text: 'Yolgʻiz oʻtiraman'),
        PsychOption(key: 'c', text: 'Kitob oʻqiyman'),
      ],
    ),
    PsychLikertItem(id: 'i3', text: 'Uyda dam ola olasanmi?'),
  ],
);
