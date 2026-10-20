// Rivojlanish servisi (panel `developmentService`):
// - `studentProfile`, `classOverview` — `development.individual` (psixolog: butun maktab;
//   sinf rahbari: faqat o'z sinfi, javoblarsiz va xom ballarsiz, hissiy holat — faqat daraja);
// - `schoolOverview`, `termOptions` — `development.view`; direktor / admin uchun K=5 atomlari
//   va faqat e'lon qilingan (yakuniy) natijalar; psixolog — jonli, yashirishsiz;
// - `attentionList` — `assessments.manage` (faqat psixolog).

import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { tashkentDay } from '../../common/time/tashkent';
import { actorCan, allowedClassIds, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { maskSmallCount } from '../care/care-suppression';
import { compareClasses } from '../common/list-query';
import { forbidden, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { termOf } from '../assessments/psych/terms';
import { computeSchoolOverview, defaultSchoolTerm, emptySchoolOverview, MIN_GRADE } from './development-aggregate';
import { computeAttention } from './development-attention';
import { cellsOf, K, schoolDomainValues } from './development-cells';
import { DevelopmentContextService } from './development-context.service';
import { DevelopmentDataService } from './development-data.service';
import type { DevIndex } from './development-index';
import { buildClassOverview, buildProfile, classTerm } from './development-profile';
import type { AttentionRow, ClassDevOverview, SchoolDevOverview, StudentDevProfile } from './development.types';

const TERM_KEY = /^\d{4}-\d{2}:Q[1-4]$/;
const termQuerySchema = z.object({ termKey: z.string().max(16).optional() });

/** Psixolog (testlarni boshqaradi) — to'liq ma'lumot; qolganlar — himoyalangan ko'rinish. */
export const canSeeRaw = (actor: SchoolActor) => actorCan(actor, 'assessments.manage');
const isSchoolWide = (actor: SchoolActor) => allowedClassIds(actor) === null;

function validTerm(termKey: string, idx: DevIndex): string {
  if (!TERM_KEY.test(termKey) || !idx.terms.includes(termKey)) throw invalid('termKey: errors.form.invalidDate');
  return termKey;
}

@Injectable()
export class DevelopmentService {
  constructor(
    private readonly data: DevelopmentDataService,
    private readonly context: DevelopmentContextService,
  ) {}

  async studentProfile(actor: SchoolActor, studentId: string): Promise<StudentDevProfile> {
    assertCan(actor, 'development.individual');
    const roster = await this.data.roster(actor.schoolId);
    const student = roster.students.find((s) => s.id === studentId);
    if (!student) throw notFound(studentId);
    assertClassInScope(actor, student.classId);
    const full = canSeeRaw(actor);
    const today = tashkentDay();
    const [idx, answers, attendance30, classLearning] = await Promise.all([
      this.data.index(actor.schoolId, 'live'),
      full ? this.context.answers(actor.schoolId, student.id) : Promise.resolve(new Map<string, string>()),
      // Davomat konteksti — faqat sinf rahbariga (panel bilan bir xil).
      actor.role === 'HOMEROOM' ? this.context.attendance30(actor.schoolId, student, today) : Promise.resolve(null),
      student.classId ? this.context.classLearning(actor.schoolId, student.classId) : Promise.resolve(null),
    ]);
    const cls = roster.classes.find((c) => c.id === student.classId);
    return buildProfile({ idx, roster, student, cls, full, today, answers, context: { attendance30, classLearning } });
  }

  async classOverview(actor: SchoolActor, classId: string, query: unknown): Promise<ClassDevOverview> {
    assertCan(actor, 'development.individual');
    const { termKey } = parseOrThrow(termQuerySchema, query ?? {});
    const roster = await this.data.roster(actor.schoolId);
    const cls = roster.classes.find((c) => c.id === classId);
    if (!cls) throw notFound(classId);
    assertClassInScope(actor, cls.id);
    const full = canSeeRaw(actor);
    const idx = await this.data.index(actor.schoolId, 'live');
    const term = termKey === undefined ? classTerm(idx, roster, cls.id, termOf(tashkentDay()).key) : validTerm(termKey, idx);
    const flagged = full ? new Set(computeAttention(idx, roster).map((r) => r.studentId)) : new Set<string>();
    // Maktab o'rtachalari: psixolog — jonli; sinf rahbari — faqat e'lon qilingan natijalardan.
    const schoolIdx = full ? idx : await this.data.index(actor.schoolId, 'released');
    const schoolAverages = Object.fromEntries(
      schoolDomainValues(cellsOf(schoolIdx.snapshot.get(term))).flatMap((v) => (v.index !== null ? [[v.domain, v.index]] : [])),
    );
    return buildClassOverview({ idx, roster, cls, termKey: term, full, flagged, schoolAverages });
  }

  async schoolOverview(actor: SchoolActor, query: unknown): Promise<SchoolDevOverview> {
    assertCan(actor, 'development.view');
    if (!isSchoolWide(actor)) throw forbidden('development.school');
    const { termKey } = parseOrThrow(termQuerySchema, query ?? {});
    const full = canSeeRaw(actor);
    const today = tashkentDay();
    const [roster, idx] = await Promise.all([this.data.roster(actor.schoolId), this.data.index(actor.schoolId, full ? 'live' : 'released')]);
    const term = termKey === undefined ? defaultSchoolTerm(idx, roster, today) : validTerm(termKey, idx);
    if (!term) return emptySchoolOverview(termOf(today).key, !full);
    const attention = computeAttention(idx, roster).length;
    return computeSchoolOverview(idx, roster, term, { suppress: !full, today, attentionCount: full ? String(attention) : maskSmallCount(attention) });
  }

  async attentionList(actor: SchoolActor): Promise<AttentionRow[]> {
    assertCan(actor, 'assessments.manage');
    const [roster, idx] = await Promise.all([this.data.roster(actor.schoolId), this.data.index(actor.schoolId, 'live')]);
    return computeAttention(idx, roster);
  }

  /** Profil va sinf ko'rinishi uchun doiradagi sinflar (psixolog — 3-sinfdan yoki natijasi bor; sinf rahbari — o'z sinfi). */
  async classOptions(actor: SchoolActor): Promise<Array<{ id: string; name: string; grade: number }>> {
    assertCan(actor, 'development.individual');
    const allowed = allowedClassIds(actor);
    const [roster, tested] = await Promise.all([this.data.roster(actor.schoolId), allowed ? Promise.resolve(new Set<string>()) : this.data.classesWithResults(actor.schoolId)]);
    return roster.classes
      .filter((c) => (allowed ? allowed.includes(c.id) : c.grade >= MIN_GRADE || tested.has(c.id)))
      .sort(compareClasses)
      .map((c) => ({ id: c.id, name: c.name, grade: c.grade }));
  }

  /** Natija bor choraklar (yangidan eskiga); direktor / admin — faqat n ≥ K, e'lon qilingan natijalar. */
  async termOptions(actor: SchoolActor): Promise<Array<{ key: string; n: number }>> {
    assertCan(actor, 'development.view');
    const full = canSeeRaw(actor);
    const schoolWide = isSchoolWide(actor);
    const idx = await this.data.index(actor.schoolId, full || !schoolWide ? 'live' : 'released');
    const allowed = schoolWide ? null : new Set(actor.classIds);
    return idx.terms
      .map((key) => ({
        key,
        n: [...(idx.snapshot.get(key)?.values() ?? [])].filter((st) => !allowed || (st.classId !== null && allowed.has(st.classId))).length,
      }))
      .filter((x) => x.n > 0 && (full || !schoolWide || x.n >= K))
      .reverse();
  }
}
