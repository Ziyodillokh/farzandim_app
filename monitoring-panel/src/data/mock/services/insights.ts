/**
 * Avtomatik xulosalar: ko'rsatkichlardan qoidalar asosida "Diqqat",
 * "Kuzatish" va "Ijobiy" signallari. Matn i18n'da (`insights.<kind>`),
 * parametrlar — raqam va kalitlar (hudud id, fan kaliti).
 */
import type { AreaStat, Filters, Insight, Scope } from '@/data/contracts';
import { getAreaMetric } from './overview';
import { getInterests, getMastery } from './learning';
import { metricStat, round, scopeArea } from './core';

const regionHref = (scope: Scope, id: string) => (scope.kind === 'NATIONAL' ? `/regions/view?id=${id}` : '/dashboard');

function extreme(areas: AreaStat[], dir: 'max' | 'min'): AreaStat | null {
  const valid = areas.filter((a) => a.value !== null);
  if (!valid.length) return null;
  return valid.reduce((best, a) => ((dir === 'max' ? (a.value as number) > (best.value as number) : (a.value as number) < (best.value as number)) ? a : best));
}

export function getInsights(scope: Scope, f: Filters): Insight[] {
  const out: Insight[] = [];
  const push = (i: Omit<Insight, 'id'>) => out.push({ ...i, id: `${i.kind}-${out.length}` });

  // O'zlashtirish: yetakchi, eng past va eng katta o'sish.
  const mastery = getAreaMetric('mastery', scope, f);
  const nat = mastery.scopeValue.value;
  const top = extreme(mastery.areas, 'max');
  const low = extreme(mastery.areas, 'min');
  if (top && nat !== null) {
    push({ severity: 'positive', kind: 'masteryLeader', params: { areaId: top.id, areaName: top.name, value: top.value as number, diff: round((top.value as number) - nat) ?? 0 }, metric: 'mastery', areaId: top.id, href: regionHref(scope, top.id) });
  }
  if (low && nat !== null && (low.value as number) < nat - 2) {
    push({ severity: 'attention', kind: 'masteryLow', params: { areaId: low.id, areaName: low.name, value: low.value as number, diff: round(nat - (low.value as number)) ?? 0 }, metric: 'mastery', areaId: low.id, href: regionHref(scope, low.id) });
  }
  const grower = mastery.areas.filter((a) => a.delta !== null).sort((a, b) => (b.delta as number) - (a.delta as number))[0];
  if (grower && (grower.delta as number) > 0.5) {
    push({ severity: 'positive', kind: 'masteryGrowth', params: { areaId: grower.id, areaName: grower.name, delta: grower.delta as number }, metric: 'mastery', areaId: grower.id, href: regionHref(scope, grower.id) });
  }

  // Fanlar: eng zaif fan va qiziqish–natija nomutanosibligi.
  const m = getMastery(scope, f);
  const subjects = m.bySubject.filter((s) => s.value !== null);
  const weakest = subjects.slice().sort((a, b) => (a.value as number) - (b.value as number))[0];
  if (weakest && m.overall.value !== null) {
    push({ severity: 'watch', kind: 'weakSubject', params: { subject: weakest.subject, value: weakest.value as number, gap: round(m.overall.value - (weakest.value as number)) ?? 0 }, metric: 'mastery', areaId: null, href: '/mastery' });
  }
  const interests = getInterests(scope, f);
  const gap = interests.subjects
    .flatMap((s) => (s.mastery !== null && s.share !== null ? [{ key: s.key, share: s.share, mastery: s.mastery, score: s.share - s.mastery }] : []))
    .sort((a, b) => b.score - a.score)[0];
  if (gap && gap.share > 35 && gap.mastery < (m.overall.value ?? 100)) {
    push({ severity: 'watch', kind: 'interestGap', params: { subject: gap.key, share: gap.share, mastery: gap.mastery }, metric: null, areaId: null, href: '/interests' });
  }

  // Farovonlik: bulling o'choqlari va umumiy o'zgarish.
  const bullying = getAreaMetric('bullying', scope, f);
  const bNat = bullying.scopeValue.value;
  const hot = extreme(bullying.areas, 'max');
  if (hot && bNat !== null && (hot.value as number) >= bNat * 1.2) {
    push({ severity: 'attention', kind: 'bullyingHotspot', params: { areaId: hot.id, areaName: hot.name, value: hot.value as number, ratio: round((hot.value as number) / bNat, 1) ?? 1 }, metric: 'bullying', areaId: hot.id, href: '/wellbeing' });
  }
  const wb = metricStat('wellbeing', scopeArea(scope), f, 0);
  if (wb.delta !== null && Math.abs(wb.delta) >= 1) {
    push({ severity: wb.delta > 0 ? 'positive' : 'watch', kind: wb.delta > 0 ? 'wellbeingUp' : 'wellbeingDown', params: { value: wb.value ?? 0, delta: Math.abs(wb.delta) }, metric: 'wellbeing', areaId: null, href: '/wellbeing' });
  }

  // Davomat.
  const att = getAreaMetric('attendance', scope, f);
  const attTop = extreme(att.areas, 'max');
  if (attTop) {
    push({ severity: 'positive', kind: 'attendanceLeader', params: { areaId: attTop.id, areaName: attTop.name, value: attTop.value as number }, metric: 'attendance', areaId: attTop.id, href: '/attendance' });
  }
  const chronic = getAreaMetric('chronic', scope, f);
  const chrTop = extreme(chronic.areas, 'max');
  if (chrTop && chronic.scopeValue.value !== null && (chrTop.value as number) > chronic.scopeValue.value * 1.15) {
    push({ severity: 'watch', kind: 'chronicHigh', params: { areaId: chrTop.id, areaName: chrTop.name, value: chrTop.value as number }, metric: 'chronic', areaId: chrTop.id, href: '/attendance' });
  }

  // Raqamli odatlar va uyqu (10–11-sinflar).
  const older = { ...f, grades: 'G10_11' as const };
  const night = metricStat('night', scopeArea(scope), older);
  const sleep = metricStat('sleep', scopeArea(scope), older);
  if (night.value !== null && sleep.value !== null) {
    push({ severity: 'watch', kind: 'nightOlder', params: { night: night.value, sleep: sleep.value }, metric: 'night', areaId: null, href: '/digital' });
  }

  // IQ qamrovi past bo'linma.
  const iqp = getAreaMetric('iqParticipation', scope, f);
  const iqLow = extreme(iqp.areas, 'min');
  if (iqLow && iqp.scopeValue.value !== null && (iqLow.value as number) < iqp.scopeValue.value - 4) {
    push({ severity: 'watch', kind: 'iqParticipationLow', params: { areaId: iqLow.id, areaName: iqLow.name, value: iqLow.value as number }, metric: 'iqParticipation', areaId: iqLow.id, href: '/iq' });
  }

  // Qamrov o'sishi.
  const cov = metricStat('coverage', scopeArea(scope), f);
  if (cov.delta !== null && cov.delta > 1) {
    push({ severity: 'positive', kind: 'coverageGrowth', params: { value: cov.value ?? 0, delta: cov.delta }, metric: 'coverage', areaId: null, href: '/dashboard' });
  }

  const order = { attention: 0, watch: 1, positive: 2 } as const;
  return out.sort((a, b) => order[a.severity] - order[b.severity]);
}
