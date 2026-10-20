'use client';

import type { DevDomain, DomainValue } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { DOMAINS, domainKey } from '../lib/domains';

/**
 * Rivojlanish radari — kutubxonasiz SVG. Uch qatlam: o'quvchi (to'ldirilgan), sinf o'rtachasi
 * (uzuq), yosh me'yori 50-persentil halqasi. Qiymati yo'q o'q — nuqtasiz, yorlig'i "—".
 */
const W = 500;
const H = 320;
const CX = W / 2;
const CY = H / 2 + 4;
const R = 108;
const RINGS = [25, 75, 100];
const NORM = 50;
const STUDENT = 'hsl(var(--primary))';
const CLASS = 'hsl(var(--info))';

type Pt = { x: number; y: number };

function angleOf(i: number, n: number): number {
  return -Math.PI / 2 + (2 * Math.PI * i) / n;
}

function point(i: number, n: number, value: number, radius = R): Pt {
  const a = angleOf(i, n);
  const r = (Math.max(0, Math.min(100, value)) / 100) * radius;
  return { x: CX + r * Math.cos(a), y: CY + r * Math.sin(a) };
}

const LINE = 15;
const WRAP_AT = 12;

/** Uzun yorliq (masalan "Ijtimoiy ko'nikmalar") ikki qatorga bo'linadi — chetga sig'adi. */
function labelLines(label: string): string[] {
  const words = label.split(' ');
  if (label.length <= WRAP_AT || words.length < 2) return [label];
  const mid = Math.ceil(words.length / 2);
  return [words.slice(0, mid).join(' '), words.slice(mid).join(' ')];
}

const toPath = (pts: Pt[]) => pts.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');

/** Mavjud nuqtalar: ≥ 3 — ko'pburchak, 2 — chiziq, 1 — faqat nuqta. */
function Shape({ pts, color, fill, dashed }: { pts: Pt[]; color: string; fill?: string; dashed?: boolean }) {
  if (pts.length >= 3) return <polygon points={toPath(pts)} fill={fill ?? 'none'} stroke={color} strokeWidth={2} strokeDasharray={dashed ? '5 4' : undefined} strokeLinejoin="round" />;
  if (pts.length === 2) return <polyline points={toPath(pts)} fill="none" stroke={color} strokeWidth={2} strokeDasharray={dashed ? '5 4' : undefined} />;
  return null;
}

export function DomainRadar({ latest, classAverage }: { latest: DomainValue[]; classAverage: Partial<Record<DevDomain, number>> }) {
  const { t } = useI18n();
  const n = DOMAINS.length;
  const value = (d: DevDomain) => latest.find((v) => v.domain === d)?.index ?? null;
  const studentPts = DOMAINS.flatMap((d, i) => {
    const v = value(d);
    return v === null ? [] : [{ ...point(i, n, v), d, v }];
  });
  const classPts = DOMAINS.flatMap((d, i) => {
    const v = classAverage[d];
    return typeof v === 'number' ? [point(i, n, v)] : [];
  });
  const ring = (level: number) => toPath(DOMAINS.map((_, i) => point(i, n, level)));

  return (
    <div className="animate-fade-in">
      <svg viewBox={`-20 -12 ${W + 40} ${H + 40}`} role="img" aria-label={t('development.profile.radarTitle')} className="mx-auto h-auto w-full max-w-[480px]">
        {RINGS.map((level) => (
          <polygon key={level} points={ring(level)} fill="none" stroke="hsl(var(--border))" strokeWidth={1} />
        ))}
        <polygon points={ring(NORM)} fill="hsl(var(--muted-foreground) / 0.05)" stroke="hsl(var(--muted-foreground) / 0.55)" strokeWidth={1.25} strokeDasharray="3 3" />
        {DOMAINS.map((d, i) => {
          const end = point(i, n, 100);
          return <line key={d} x1={CX} y1={CY} x2={end.x} y2={end.y} stroke="hsl(var(--border))" strokeWidth={1} />;
        })}
        <Shape pts={classPts} color={CLASS} fill="hsl(var(--info) / 0.06)" dashed />
        <Shape pts={studentPts} color={STUDENT} fill="hsl(var(--primary) / 0.16)" />
        {studentPts.map((p) => (
          <circle key={p.d} cx={p.x} cy={p.y} r={4.5} fill={STUDENT} stroke="hsl(var(--card))" strokeWidth={2}>
            <title>{`${t(domainKey(p.d))}: ${p.v}`}</title>
          </circle>
        ))}
        {DOMAINS.map((d, i) => {
          const a = angleOf(i, n);
          const lx = CX + (R + 22) * Math.cos(a);
          const ly = CY + (R + 22) * Math.sin(a);
          const anchor = Math.abs(Math.cos(a)) < 0.2 ? 'middle' : Math.cos(a) > 0 ? 'start' : 'end';
          const v = value(d);
          const lines = labelLines(t(domainKey(d)));
          const extra = (lines.length - 1) * LINE;
          const dy = Math.sin(a) < -0.5 ? -8 - extra : Math.sin(a) > 0.5 ? 6 : -extra / 2;
          return (
            <text key={d} x={lx} y={ly + dy} textAnchor={anchor} fontSize={13} fill={v === null ? 'hsl(var(--muted-foreground))' : 'hsl(var(--foreground))'}>
              {lines.map((line, li) => (
                <tspan key={li} x={lx} dy={li === 0 ? 0 : LINE} fontWeight={500}>
                  {line}
                </tspan>
              ))}
              <tspan x={lx} dy={LINE} fontSize={12.5} fontWeight={700} fill={v === null ? 'hsl(var(--muted-foreground))' : STUDENT}>
                {v === null ? '—' : v}
              </tspan>
            </text>
          );
        })}
      </svg>
      <ul className="mt-2 flex flex-wrap justify-center gap-x-5 gap-y-1.5 text-xs text-muted-foreground">
        <li className="flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-sm" style={{ background: STUDENT }} />
          {t('development.profile.student')}
        </li>
        <li className="flex items-center gap-1.5">
          <svg width="18" height="8" aria-hidden><line x1="1" y1="4" x2="17" y2="4" stroke={CLASS} strokeWidth="2" strokeDasharray="4 3" /></svg>
          {t('development.profile.classAvg')}
        </li>
        <li className="flex items-center gap-1.5">
          <svg width="18" height="8" aria-hidden><line x1="1" y1="4" x2="17" y2="4" stroke="hsl(var(--muted-foreground))" strokeWidth="1.5" strokeDasharray="3 3" /></svg>
          {t('development.profile.norm')}
        </li>
      </ul>
    </div>
  );
}
