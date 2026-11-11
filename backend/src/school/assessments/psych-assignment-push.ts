// Mutaxassis tayinlagan test -> bolalarga push: kim oladi va push matni — sof mantiq (DB'siz).
// Push faqat testni o'z ilovasida KO'RADIGAN bolaga ketadi (`AssessmentsChildService` qoidasi bilan bir xil):
// arxivlanmagan, sinfi bor, maktab faol, "maktab / sinf noto'g'ri" so'rovi ochiq emas, bola ilovasi ulangan,
// tayinlash uning sinfiga yoki shaxsan unga. Parvoz IQ — faqat IQ yoshidagilarga (9–20, IQ moduli qoidasi).
// Push matni HAR DOIM neytral: test nomi, "psixolog" so'zi va maktab nomi yo'q (lock-screen).

import { Prisma, SchoolPsychAssignment } from '@prisma/client';
import type { PushPayload } from '../../common/fcm/fcm.service';
import { NotifLang, tr } from '../../common/i18n/notification-i18n';
import type { DayKey } from '../../common/time/tashkent';
import { resolveIqAge } from '../../modules/iq/domain/levels';
import { ChildRecipient, enrolledChildWhere, toRecipients } from '../common/school-child-push.service';

/** `child_push_dedupe.kind` — kalit: tayinlash id. */
export const PSYCH_ASSIGNMENT_DEDUPE_KIND = 'PSYCH_ASSIGNMENT';
export const PSYCH_ASSIGNMENT_PUSH_TYPE = 'PSYCH_ASSIGNMENT';

type AssignmentTarget = Pick<SchoolPsychAssignment, 'schoolId' | 'classIds' | 'studentIds'>;

/** Tayinlashni ko'radigan o'quvchilar sharti; `null` — maqsad bo'sh. */
export function assignmentRecipientsWhere(a: AssignmentTarget): Prisma.SchoolStudentWhereInput | null {
  if (a.classIds.length === 0 && a.studentIds.length === 0) return null;
  return {
    ...enrolledChildWhere(a.schoolId),
    OR: [{ classId: { in: [...a.classIds] } }, { id: { in: [...a.studentIds] } }],
  };
}

export interface PsychRecipientRow {
  childId: string | null;
  child: { childUserId: string | null; birthDate: Date | null; age: number | null } | null;
}

/** Ilovasi ulangan bolalar (takrorsiz); IQ tayinlashida — faqat IQ yoshidagilar ([day] bo'yicha). */
export function selectPsychRecipients(rows: readonly PsychRecipientRow[], opts: { iq: boolean; day: DayKey }): ChildRecipient[] {
  const eligible = opts.iq ? rows.filter((row) => row.child && resolveIqAge(row.child, opts.day).status === 'OK') : rows;
  return toRecipients(eligible);
}

/** Tayinlash hozir ochiqmi (bola uni ro'yxatda ko'radi). */
export const isOpenNow = (a: Pick<SchoolPsychAssignment, 'status' | 'opensAt' | 'closesAt'>, now: Date): boolean =>
  a.status === 'OPEN' && a.opensAt.getTime() <= now.getTime() && now.getTime() <= a.closesAt.getTime();

export function psychAssignmentPush(lang: NotifLang, a: { id: string; iq: boolean }): PushPayload {
  return {
    title: tr(lang, 'push.neutralTitle'),
    body: tr(lang, 'psychAssignment.body'),
    data: { type: PSYCH_ASSIGNMENT_PUSH_TYPE, assignmentId: a.id, kind: a.iq ? 'IQ' : 'TEST' },
  };
}
