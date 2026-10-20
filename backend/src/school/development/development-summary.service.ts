// Bosh sahifa kartasi uchun rolga mos rivojlanish xulosasi (panel
// `development-summary.ts`; dashboard `development.view` bo'lsa chaqiradi):
// - DIRECTOR / ADMIN → AGGREGATE: qamrov + soha indekslari (K=5, faqat e'lon qilingan natijalar);
// - HOMEROOM → CLASS: o'z sinfi o'rtachalari (n ≥ K);
// - PSYCHOLOGIST → faol tayinlashlar, shu hafta yakunlanganlar, e'tibor ro'yxati soni;
// - boshqalar → null.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekday, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { SchoolActor } from '../auth/school-actor';
import { termOf } from '../assessments/psych/terms';
import type { IsoDate } from '../assessments/psych/types';
import { defaultSchoolTerm, participation } from './development-aggregate';
import { computeAttention } from './development-attention';
import { cellsOf, K, schoolDomainValues } from './development-cells';
import { DevelopmentDataService } from './development-data.service';
import { DEV_DOMAINS, DevIndex } from './development-index';
import type { DevelopmentSummary, DomainIndexValue, Roster } from './development.types';

const emptyDomains = (): DomainIndexValue[] => DEV_DOMAINS.map((domain) => ({ domain, index: null }));

function schoolDomains(idx: DevIndex, roster: Roster, today: IsoDate): { termKey: string | null; domains: DomainIndexValue[] } {
  const termKey = defaultSchoolTerm(idx, roster, today);
  if (!termKey) return { termKey: null, domains: emptyDomains() };
  return { termKey, domains: schoolDomainValues(cellsOf(idx.snapshot.get(termKey))).map(({ domain, index }) => ({ domain, index })) };
}

@Injectable()
export class DevelopmentSummaryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly data: DevelopmentDataService,
  ) {}

  async developmentSummary(actor: SchoolActor): Promise<DevelopmentSummary | null> {
    const today = tashkentDay();
    switch (actor.role) {
      case 'DIRECTOR':
      case 'ADMIN':
        return this.aggregate(actor, today);
      case 'HOMEROOM':
        return this.classSummary(actor);
      case 'PSYCHOLOGIST':
        return this.psychologist(actor, today);
      default:
        return null;
    }
  }

  /** Direktor / admin: faqat e'lon qilingan (yakuniy) natijalar, K=5. */
  private async aggregate(actor: SchoolActor, today: IsoDate): Promise<DevelopmentSummary> {
    const [roster, idx] = await Promise.all([this.data.roster(actor.schoolId), this.data.index(actor.schoolId, 'released')]);
    const termKey = defaultSchoolTerm(idx, roster, today);
    if (!termKey) return { mode: 'AGGREGATE', termKey: termOf(today).key, participation: 0, domains: emptyDomains() };
    const cells = cellsOf(idx.snapshot.get(termKey));
    return {
      mode: 'AGGREGATE',
      termKey,
      participation: participation(cells, roster, termKey, today).rate,
      domains: schoolDomainValues(cells, K).map(({ domain, index }) => ({ domain, index })),
    };
  }

  /** Sinf rahbari: o'z sinfining so'nggi baholangan choragi bo'yicha o'rtachalar (n ≥ K). */
  private async classSummary(actor: SchoolActor): Promise<DevelopmentSummary | null> {
    const roster = await this.data.roster(actor.schoolId);
    const cls = roster.classes.find((c) => c.id === actor.classIds[0]);
    if (!cls) return null;
    const idx = await this.data.index(actor.schoolId, 'live');
    const members = roster.students.filter((s) => !s.archived && s.classId === cls.id);
    const ids = new Set(members.map((s) => s.id));
    const term = idx.terms.filter((key) => [...(idx.snapshot.get(key)?.keys() ?? [])].some((id) => ids.has(id))).at(-1);
    const snap = term ? idx.snapshot.get(term) : undefined;
    const domains = DEV_DOMAINS.map((domain) => {
      const xs = members.map((s) => snap?.get(s.id)?.domains[domain]?.index).filter((x): x is number => typeof x === 'number');
      return { domain, index: xs.length >= K ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null };
    });
    return { mode: 'CLASS', classId: cls.id, className: cls.name, assessed: members.filter((s) => snap?.has(s.id)).length, total: members.length, domains };
  }

  /** Psixolog: jonli ma'lumot. */
  private async psychologist(actor: SchoolActor, today: IsoDate): Promise<DevelopmentSummary> {
    const monday = addDays(today, 1 - isoWeekday(today));
    const [roster, idx, assignments, completedThisWeek] = await Promise.all([
      this.data.roster(actor.schoolId),
      this.data.index(actor.schoolId, 'live'),
      this.prisma.schoolPsychAssignment.findMany({ where: { schoolId: actor.schoolId, status: 'OPEN' }, select: { opensAt: true, closesAt: true } }),
      this.prisma.schoolPsychResult.count({
        where: { schoolId: actor.schoolId, takenAt: { gte: tashkentDayStart(monday), lt: tashkentDayStart(addDays(today, 1)) } },
      }),
    ]);
    const activeAssignments = assignments.filter((a) => tashkentDay(a.opensAt) <= today && today <= tashkentDay(a.closesAt)).length;
    return {
      mode: 'PSYCHOLOGIST',
      activeAssignments,
      completedThisWeek,
      attention: computeAttention(idx, roster).length,
      domains: schoolDomains(idx, roster, today).domains,
    };
  }
}
