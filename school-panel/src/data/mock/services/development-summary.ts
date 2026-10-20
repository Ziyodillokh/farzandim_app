import type { DevDomain, DevelopmentSummary, IsoDate } from '@/data/contracts';
import { CARE_MIN_GROUP as K } from '@/lib/k-anon';
import { termOf } from '@/lib/psych/terms';
import { addDays, toIsoDate, weekStart } from '../calendar';
import type { Actor } from '../context';
import { allResults } from '../psych/results';
import type { Tables } from '../tables';
import { computeSchoolOverview, defaultSchoolTerm, DEV_DOMAINS, devIndex, type DevIndex, schoolDomainValues } from './development-aggregate';
import { computeAttention } from './development-attention';

/**
 * Bosh sahifa kartasi uchun rolga mos rivojlanish xulosasi (dashboard servisi chaqiradi —
 * ruxsat tekshiruvi o'sha yerda; bu yerda faqat rolga mos ko'rinish).
 * - DIRECTOR/ADMIN → AGGREGATE (qatnashish + soha indekslari, k-anonim yashirilgan);
 * - HOMEROOM → CLASS (o'z sinfi o'rtachalari);
 * - PSYCHOLOGIST → faol tayinlashlar, shu hafta yakunlanganlar, e'tibor ro'yxati soni;
 * - boshqalar → null.
 */
type DomainIndex = { domain: DevDomain; index: number | null };

const localDate = (stamp: string): IsoDate => toIsoDate(new Date(Date.parse(stamp)));

function emptyDomains(): DomainIndex[] {
  return DEV_DOMAINS.map((domain) => ({ domain, index: null }));
}

function schoolDomains(t: Tables, idx: DevIndex, today: IsoDate): { termKey: string | null; domains: DomainIndex[] } {
  const termKey = defaultSchoolTerm(t, idx, today);
  if (!termKey) return { termKey: null, domains: emptyDomains() };
  return { termKey, domains: schoolDomainValues(t, idx, termKey, today).map(({ domain, index }) => ({ domain, index })) };
}

function aggregateSummary(t: Tables, idx: DevIndex, today: IsoDate): DevelopmentSummary {
  const { termKey, domains } = schoolDomains(t, idx, today);
  if (!termKey) return { mode: 'AGGREGATE', termKey: termOf(today).key, participation: 0, domains };
  const overview = computeSchoolOverview(t, idx, termKey, { suppress: true, today, attentionCount: null });
  return {
    mode: 'AGGREGATE',
    termKey,
    participation: overview.participation.rate,
    domains: overview.domainAverages.map(({ domain, index }) => ({ domain, index })),
  };
}

function classSummary(t: Tables, idx: DevIndex, actor: Actor): DevelopmentSummary | null {
  const classId = actor.classIds[0];
  const cls = t.classes.find((c) => c.id === classId);
  if (!cls) return null;
  const roster = t.students.filter((s) => !s.archived && s.classId === cls.id);
  const ids = new Set(roster.map((s) => s.id));
  const term = idx.terms.filter((key) => [...(idx.snapshot.get(key)?.keys() ?? [])].some((id) => ids.has(id))).at(-1);
  const snap = term ? idx.snapshot.get(term) : undefined;
  const assessed = roster.filter((s) => snap?.has(s.id)).length;
  const domains = DEV_DOMAINS.map((domain) => {
    const xs = roster.map((s) => snap?.get(s.id)?.domains[domain]?.index).filter((x): x is number => typeof x === 'number');
    return { domain, index: xs.length >= K ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null };
  });
  return { mode: 'CLASS', classId: cls.id, className: cls.name, assessed, total: roster.length, domains };
}

function psychologistSummary(t: Tables, idx: DevIndex, today: IsoDate): DevelopmentSummary {
  const activeAssignments = (t.psychAssignments ?? []).filter(
    (a) => a.status === 'OPEN' && localDate(a.opensAt) <= today && today <= localDate(a.closesAt),
  ).length;
  const start = weekStart(today);
  const end = addDays(start, 7);
  const completedThisWeek = allResults(t).filter((r) => {
    const day = localDate(r.takenAt);
    return day >= start && day < end && day <= today;
  }).length;
  return {
    mode: 'PSYCHOLOGIST',
    activeAssignments,
    completedThisWeek,
    attention: computeAttention(t, idx).length,
    domains: schoolDomains(t, idx, today).domains,
  };
}

export function developmentSummary(tables: Tables, actor: Actor, today: IsoDate): DevelopmentSummary | null {
  switch (actor.role) {
    case 'DIRECTOR':
    case 'ADMIN':
      return aggregateSummary(tables, devIndex(tables), today);
    case 'HOMEROOM':
      return classSummary(tables, devIndex(tables), actor);
    case 'PSYCHOLOGIST':
      return psychologistSummary(tables, devIndex(tables), today);
    default:
      return null;
  }
}
