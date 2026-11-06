import type { CareAggregate, CareQuestion, CareRequest, CareSurvey } from '@/data/contracts';
import type { careService } from '@/data/mock/services/care';
import type { CareAggregateQuery, CareQuestionInput, CareSettingsInput, CareSurveyInput } from '@/data/schemas/care';
import { http } from '../client';
import { toCareMessage, toCareRequestDetail, toCareRequestList, toCareSettingsBody, toCareSettingsView } from './care-adapters';

type Care = typeof careService;
type Result<K extends keyof Care> = Awaited<ReturnType<Care[K]>>;
const BASE = '/school/care';
const id = (v: string) => encodeURIComponent(v);

export const careHttp: Care = {
  surveyOptions: () => http<Result<'surveyOptions'>>('GET', `${BASE}/surveys/options`),
  surveySummaries: () => http<Result<'surveySummaries'>>('GET', `${BASE}/surveys/summaries`),
  aggregate: (query: CareAggregateQuery) => http<CareAggregate>('GET', `${BASE}/aggregate`, { query }),
  listRequests: async (filter = {}) => toCareRequestList(await http<unknown>('GET', `${BASE}/requests`, { query: filter })),
  /** Birinchi ochilishda backend `openedAt`ni qo'yadi va bola xabarlarini o'qilgan qiladi. */
  getRequest: async (requestId) => toCareRequestDetail(await http<unknown>('GET', `${BASE}/requests/${id(requestId)}`)),
  /** Bolaga javob (yozishma). Ichki eslatma — alohida `/notes`. */
  replyToRequest: async (requestId, text) => toCareMessage(await http<unknown>('POST', `${BASE}/requests/${id(requestId)}/messages`, { body: { text } })),
  updateRequestStatus: (requestId, status) => http<CareRequest>('PUT', `${BASE}/requests/${id(requestId)}/status`, { body: { status } }),
  addRequestNote: (requestId, text) => http<CareRequest>('POST', `${BASE}/requests/${id(requestId)}/notes`, { body: { text } }),
  scheduleMeeting: (requestId, meetingAt) => http<CareRequest>('PUT', `${BASE}/requests/${id(requestId)}/meeting`, { body: { meetingAt } }),
  activateProtocol: (requestId) => http<CareRequest>('POST', `${BASE}/requests/${id(requestId)}/protocol`),
  getSettings: async () => toCareSettingsView(await http<unknown>('GET', `${BASE}/settings`)),
  /** PUT javobi kontraktda aniqlanmagan — saqlagach GET bilan o'qiladi (javob shakliga tayanmaymiz). */
  updateSettings: async (input: CareSettingsInput) => {
    await http<unknown>('PUT', `${BASE}/settings`, { body: toCareSettingsBody(input) });
    return careHttp.getSettings();
  },
  listSurveys: () => http<Result<'listSurveys'>>('GET', `${BASE}/surveys`),
  createSurvey: (input: CareSurveyInput) => http<CareSurvey>('POST', `${BASE}/surveys`, { body: input }),
  updateSurvey: (surveyId, input: CareSurveyInput) => http<CareSurvey>('PUT', `${BASE}/surveys/${id(surveyId)}`, { body: input }),
  deleteSurvey: (surveyId) => http<void>('DELETE', `${BASE}/surveys/${id(surveyId)}`),
  activateSurvey: (surveyId) => http<CareSurvey>('POST', `${BASE}/surveys/${id(surveyId)}/activate`),
  closeSurvey: (surveyId) => http<CareSurvey>('POST', `${BASE}/surveys/${id(surveyId)}/close`),
  listQuestions: () => http<Result<'listQuestions'>>('GET', `${BASE}/questions`),
  createQuestion: (input: CareQuestionInput) => http<CareQuestion>('POST', `${BASE}/questions`, { body: input }),
  updateQuestion: (questionId, input: CareQuestionInput) => http<CareQuestion>('PUT', `${BASE}/questions/${id(questionId)}`, { body: input }),
  deleteQuestion: (questionId) => http<void>('DELETE', `${BASE}/questions/${id(questionId)}`),
};
