'use client';

import { CartesianGrid, Line, LineChart, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import type { DevDomain, StudentDevProfile } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { DOMAIN_STYLE, DOMAINS, domainKey, formatTerm, shortTerm } from '../lib/domains';
import { DevTooltip, DomainLegend } from './chart-parts';

type Datum = { termKey: string; label: string } & Partial<Record<DevDomain, number>>;

/** O'quvchi indekslari choraklar bo'yicha (0..100), 50 — yosh me'yori. */
export function ScoreTimeline({ timeline }: { timeline: StudentDevProfile['timeline'] }) {
  const { t } = useI18n();
  const data: Datum[] = timeline.map((p) => ({ termKey: p.termKey, label: shortTerm(p.termKey), ...p.values }));
  const present = DOMAINS.filter((d) => data.some((x) => typeof x[d] === 'number'));
  return (
    <>
      <div className="h-56 animate-fade-in">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 8, right: 16, bottom: 0, left: -18 }}>
            <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
            <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} padding={{ left: 12, right: 12 }} />
            <YAxis domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
            <ReferenceLine y={50} stroke="hsl(var(--muted-foreground) / 0.6)" strokeDasharray="4 4" />
            <Tooltip
              cursor={{ stroke: 'hsl(var(--primary) / 0.3)' }}
              content={({ active, payload }) => {
                const d = payload?.[0]?.payload as Datum | undefined;
                if (!active || !d) return null;
                const rows = present.filter((dm) => typeof d[dm] === 'number').map((dm) => ({ key: dm, label: t(domainKey(dm)), value: d[dm] ?? '—', swatch: DOMAIN_STYLE[dm].color, dash: Boolean(DOMAIN_STYLE[dm].dash) }));
                return <DevTooltip title={formatTerm(d.termKey, t)} rows={rows} />;
              }}
            />
            {present.map((d) => (
              <Line
                key={d}
                type="monotone"
                dataKey={d}
                name={t(domainKey(d))}
                stroke={DOMAIN_STYLE[d].color}
                strokeDasharray={DOMAIN_STYLE[d].dash}
                strokeWidth={2}
                dot={{ r: 4, fill: 'hsl(var(--card))', stroke: DOMAIN_STYLE[d].color, strokeWidth: 2 }}
                activeDot={{ r: 5 }}
                connectNulls
                isAnimationActive={false}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
      <DomainLegend domains={present} />
    </>
  );
}
