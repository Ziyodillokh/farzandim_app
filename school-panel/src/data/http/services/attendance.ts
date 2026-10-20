import type { AttendanceRecord, EarlyExitRequest, EntryToken } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { attendanceService, ClassOption, FeedItem, KioskStats } from '@/data/mock/services/attendance';
import type { CorrectionInput, EarlyExitInput } from '@/data/schemas/attendance';
import { http } from '../client';

type Attendance = typeof attendanceService;
type Result<K extends keyof Attendance> = Awaited<ReturnType<Attendance[K]>>;

const BASE = '/school/attendance';
const id = (v: string) => encodeURIComponent(v);

/** Kiosk QR oynasi (backend `KIOSK_SLOT_MS`). */
const TOKEN_WINDOW_MS = 30_000;
/** Token olinmasa — qayta urinish oralig'i. */
const TOKEN_RETRY_MS = 5_000;

type KioskTokenResponse = { token: string; issuedAt: string; expiresAt: string; rotatesInSeconds: number };

/**
 * `currentToken` panelda sinxron (kiosk ekrani har 250 ms chaqiradi): server
 * tokeni keshlanadi va almashish vaqti kelganda fonda yangilanadi. Muddat
 * brauzer soatiga `rotatesInSeconds` orqali o'tkaziladi (soatlar farqiga
 * chidamli); server oldingi oynani ham qabul qiladi — almashishda uzilish yo'q.
 */
function createKioskTokenCache(): () => EntryToken {
  let current: EntryToken | null = null;
  let refreshAt = 0;
  let loading = false;

  const refresh = () => {
    if (loading) return;
    loading = true;
    http<KioskTokenResponse>('GET', `${BASE}/kiosk/token`)
      .then((res) => {
        const expiresAt = Date.now() + res.rotatesInSeconds * 1000;
        current = {
          code: res.token,
          issuedAt: new Date(expiresAt - TOKEN_WINDOW_MS).toISOString(),
          expiresAt: new Date(expiresAt).toISOString(),
        };
        refreshAt = expiresAt;
      })
      .catch(() => {
        refreshAt = Date.now() + TOKEN_RETRY_MS;
      })
      .finally(() => {
        loading = false;
      });
  };

  return () => {
    const now = Date.now();
    if (now >= refreshAt) refresh();
    return current ?? { code: '', issuedAt: new Date(now).toISOString(), expiresAt: new Date(now).toISOString() };
  };
}

export const attendanceHttp: Attendance = {
  board: (date) => http<Result<'board'>>('GET', `${BASE}/board`, { query: { date } }),
  classDay: (classId, date) => http<Result<'classDay'>>('GET', `${BASE}/classes/${id(classId)}`, { query: { date } }),
  feed: (options = {}) => http<FeedItem[]>('GET', `${BASE}/feed`, { query: options }),
  classOptions: () => http<ClassOption[]>('GET', `${BASE}/class-options`),
  mark: (studentId, status, reason = '') =>
    http<AttendanceRecord>('POST', `${BASE}/mark`, { body: { studentId, status, reason } }),
  correct: (input: CorrectionInput) => http<AttendanceRecord>('POST', `${BASE}/corrections`, { body: input }),
  corrections: () => http<Result<'corrections'>>('GET', `${BASE}/corrections`),

  currentToken: createKioskTokenCache(),
  // Kod faqat serverda tekshiriladi (bola ilovasi `POST /child/school/check-in`) — demo uchun edi.
  verifyToken: () => {
    throw new ServiceError('UNKNOWN', 'demo-only');
  },
  checkIn: (codeOrId) => http<Result<'checkIn'>>('POST', `${BASE}/kiosk/check-in`, { body: { code: codeOrId } }),
  kioskSearch: (query) => http<Result<'kioskSearch'>>('GET', `${BASE}/kiosk/search`, { query: { q: query } }),
  kioskStats: () => http<KioskStats>('GET', `${BASE}/kiosk/stats`),

  earlyExits: (status) => http<Result<'earlyExits'>>('GET', `${BASE}/early-exits`, { query: { status } }),
  createEarlyExit: (input: EarlyExitInput) => http<EarlyExitRequest>('POST', `${BASE}/early-exits`, { body: input }),
  decideEarlyExit: (exitId, approve) =>
    http<EarlyExitRequest>('POST', `${BASE}/early-exits/${id(exitId)}/decision`, { body: { approve } }),

  notifications: (limit = 100) => http<Result<'notifications'>>('GET', `${BASE}/notifications`, { query: { limit } }),
  monthReport: (month, classId) => http<Result<'monthReport'>>('GET', `${BASE}/month-report`, { query: { month, classId } }),
  trend: (daysBack = 14) => http<Result<'trend'>>('GET', `${BASE}/trend`, { query: { daysBack } }),
  studentMonth: (studentId, month) =>
    http<Result<'studentMonth'>>('GET', `${BASE}/students/${id(studentId)}/month`, { query: { month } }),
};
