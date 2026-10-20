import type { CareAggregate, CareQuestion, CareRequest, CareSurvey } from '@/data/contracts';
import type { careService } from '@/data/mock/services/care';
import type { CareAggregateQuery, CareQuestionInput, CareSurveyInput } from '@/data/schemas/care';
import { http } from '../client';

type Care = typeof careService;
type Result<K extends keyof Care> = Awaited<ReturnType<Care[K]>>;
const BASE = '/school/care';
const id = (v: string) => encodeURIComponent(v);

export const careHttp: Care = {
  surveyOptions: () => http<Result<'surveyOptions'>>('GET', `${BASE}/surveys/options`),
  surveySummaries: () => http<Result<'surveySummaries'>>('GET', `${BASE}/surveys/summaries`),
  aggregate: (query: CareAggregateQuery) => http<CareAggregate>('GET', `${BASE}/aggregate`, { query }),
  listRequests: (filter = {}) => http<Result<'listRequests'>>('GET', `${BASE}/requests`, { query: filter }),
  getRequest: (requestId) => http<Result<'getRequest'>>('GET', `${BASE}/requests/${id(requestId)}`),
  updateRequestStatus: (requestId, status) => http<CareRequest>('PUT', `${BASE}/requests/${id(requestId)}/status`, { body: { status } }),
  addRequestNote: (requestId, text) => http<CareRequest>('POST', `${BASE}/requests/${id(requestId)}/notes`, { body: { text } }),
  scheduleMeeting: (requestId, meetingAt) => http<CareRequest>('PUT', `${BASE}/requests/${id(requestId)}/meeting`, { body: { meetingAt } }),
  activateProtocol: (requestId) => http<CareRequest>('POST', `${BASE}/requests/${id(requestId)}/protocol`),
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
