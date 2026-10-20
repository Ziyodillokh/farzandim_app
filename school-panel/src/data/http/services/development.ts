import type { developmentService } from '@/data/mock/services/development';
import { http } from '../client';

type Development = typeof developmentService;
type Result<K extends keyof Development> = Awaited<ReturnType<Development[K]>>;
const BASE = '/school/development';
const id = (v: string) => encodeURIComponent(v);

/**
 * Rivojlanish (backend). Ko'rinish serverda: psixolog — to'liq; sinf rahbari — o'z sinfi,
 * xom ballsiz; direktor / admin — faqat K=5 agregatlar va faqat yakuniy natijalardan.
 */
export const developmentHttp: Development = {
  studentProfile: (studentId) => http<Result<'studentProfile'>>('GET', `${BASE}/students/${id(studentId)}/profile`),
  classOverview: (classId, termKey) => http<Result<'classOverview'>>('GET', `${BASE}/classes/${id(classId)}/overview`, { query: { termKey } }),
  schoolOverview: (q = {}) => http<Result<'schoolOverview'>>('GET', `${BASE}/school/overview`, { query: q }),
  attentionList: () => http<Result<'attentionList'>>('GET', `${BASE}/attention`),
  classOptions: () => http<Result<'classOptions'>>('GET', `${BASE}/class-options`),
  termOptions: () => http<Result<'termOptions'>>('GET', `${BASE}/term-options`),
};
