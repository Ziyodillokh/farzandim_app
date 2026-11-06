import type { LinkDecisionResult, LinkDecisionStatus, LinkRequestKind } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { TKey } from '@/i18n';
import { errorKey } from '@/lib/errors';

/** Qaror = backend endpoint'i: `POST /school/link-requests/:id/(confirm|reject)`. */
export type LinkDecision = 'confirm' | 'reject';

export type DecisionSpec = {
  /** Tugma bosilganda chaqiriladigan endpoint. */
  decision: LinkDecision;
  /** Tugma va tasdiq oynasidagi tasdiqlash tugmasi matni. */
  label: TKey;
  dialog: { title: TKey; text: TKey };
  /** Muvaffaqiyat xabari (backend natijasi `kind` + `status` bo'yicha tanlanadi, `toastKeyFor`). */
  toast: TKey;
  /** Qaytarib bo'lmaydigan / ehtiyotkor amal: tugma va oyna «halokatli» uslubda. */
  destructive: boolean;
};

/**
 * YAGONA jadval: (so'rov turi, endpoint) → tugma matni, tasdiq oynasi, xabar. Tugmalar, oyna va xabarlar shundan olinadi — keep/unlink
 * tugmalarini teskari bog'lab qo'yish mumkin emas (K2 §5):
 *  - REVIEW:     `confirm` = ulanishni TASDIQLASH;  `reject` = o'quvchi o'rnini bo'shatish (rad etish).
 *  - CORRECTION: `confirm` = ulanishni SAQLASH;     `reject` = ulanishni UZISH.
 *  - GUARDIAN:   `confirm` = ota-onani VASIY qilish; `reject` = so'rovni rad etish (ota-ona o'rni bo'shaydi).
 */
export const LINK_ACTIONS: Readonly<Record<LinkRequestKind, Readonly<Record<LinkDecision, DecisionSpec>>>> = {
  REVIEW: {
    confirm: {
      decision: 'confirm',
      label: 'linkRequests.review.confirm',
      dialog: { title: 'linkRequests.review.confirmTitle', text: 'linkRequests.review.confirmText' },
      toast: 'linkRequests.toast.confirmed',
      destructive: false,
    },
    reject: {
      decision: 'reject',
      label: 'linkRequests.review.reject',
      dialog: { title: 'linkRequests.review.rejectTitle', text: 'linkRequests.review.rejectText' },
      toast: 'linkRequests.toast.rejected',
      destructive: true,
    },
  },
  CORRECTION: {
    confirm: {
      decision: 'confirm',
      label: 'linkRequests.correction.keep',
      dialog: { title: 'linkRequests.correction.keepTitle', text: 'linkRequests.correction.keepText' },
      toast: 'linkRequests.toast.kept',
      destructive: false,
    },
    reject: {
      decision: 'reject',
      label: 'linkRequests.correction.unlink',
      dialog: { title: 'linkRequests.correction.unlinkTitle', text: 'linkRequests.correction.unlinkText' },
      toast: 'linkRequests.toast.unlinked',
      destructive: true,
    },
  },
  GUARDIAN: {
    confirm: {
      decision: 'confirm',
      label: 'linkRequests.guardian.confirm',
      dialog: { title: 'linkRequests.guardian.confirmTitle', text: 'linkRequests.guardian.confirmText' },
      toast: 'linkRequests.toast.guardianConfirmed',
      destructive: false,
    },
    reject: {
      decision: 'reject',
      label: 'linkRequests.guardian.reject',
      dialog: { title: 'linkRequests.guardian.rejectTitle', text: 'linkRequests.guardian.rejectText' },
      toast: 'linkRequests.toast.guardianRejected',
      destructive: true,
    },
  },
};

/** Tugmalar tartibi: ehtiyotkor amal (rad/uzish) chapda, asosiy (tasdiq/saqlash) o'ngda. */
export const DECISION_ORDER: readonly LinkDecision[] = ['reject', 'confirm'];

const STATUS_DECISION: Readonly<Record<LinkDecisionStatus, LinkDecision>> = { CONFIRMED: 'confirm', REJECTED: 'reject' };

/** Endpoint chaqiruvi (`confirm` yoki `reject`): UI qarori → servis. Mock va http servislari uchun bir xil. */
export function runDecision(
  service: { confirm: (id: string) => Promise<LinkDecisionResult>; reject: (id: string) => Promise<LinkDecisionResult> },
  id: string,
  decision: LinkDecision,
): Promise<LinkDecisionResult> {
  return decision === 'confirm' ? service.confirm(id) : service.reject(id);
}

/** Muvaffaqiyat xabari: backend NATIJASI bo'yicha (so'rov turi + holat), bosilgan tugma bo'yicha emas. */
export function toastKeyFor(result: LinkDecisionResult): TKey {
  return LINK_ACTIONS[result.kind][STATUS_DECISION[result.status]].toast;
}

/**
 * Qaror xatosi matni. `409 REQUEST_STALE`, `STUDENT_LINKED_ELSEWHERE`, `ALREADY_ENROLLED` — `errors.detail.*`; `404` — so'rov yo'q
 * (boshqa xodim allaqachon hal qilgan yoki bola o'chirilgan): umumiy «topilmadi» emas, ro'yxat yangilanishi haqida.
 */
export function decisionErrorKey(error: unknown): TKey {
  if (error instanceof ServiceError && error.code === 'NOT_FOUND') return 'linkRequests.errors.gone';
  return errorKey(error);
}

/** Qaror xabari uzunroq (sabab + keyingi qadam): oddiy xabardan uzoqroq ko'rinadi. */
export const DECISION_ERROR_TOAST_MS = 9000;
