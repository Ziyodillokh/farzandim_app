'use client';

import { AlertTriangle, ArrowUpRight, ChevronDown, Eye, Sparkles } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import type { Insight, InsightSeverity } from '@/data/contracts';
import { SUBJECT_KEYS } from '@/data/reference/domains';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

const STYLE: Record<InsightSeverity, { icon: typeof AlertTriangle; ring: string; chip: string }> = {
  attention: { icon: AlertTriangle, ring: 'ring-amber-500/30 bg-amber-500/[0.06]', chip: 'bg-amber-500/15 text-amber-700 dark:text-amber-300' },
  watch: { icon: Eye, ring: 'ring-sky-500/25 bg-sky-500/[0.05]', chip: 'bg-sky-500/15 text-sky-700 dark:text-sky-300' },
  positive: { icon: Sparkles, ring: 'ring-emerald-500/25 bg-emerald-500/[0.05]', chip: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300' },
};

/** Parametrlarni matnga: hudud id → nom, fan kaliti → nom, raqamlar → mahalliy format. */
export function useInsightText() {
  const { t } = useI18n();
  const areaName = useAreaName();
  const fmt = useMetricFormat();
  return (i: Insight) => {
    const params: Record<string, string> = {};
    for (const [k, v] of Object.entries(i.params)) {
      if (k === 'areaName') continue;
      if (k === 'areaId') params.area = areaName(String(v), { fallback: String(i.params.areaName ?? v) });
      else if (k === 'subject' && (SUBJECT_KEYS as readonly string[]).includes(String(v))) params.subject = t(`enums.subject.${v as 'MATH'}`);
      else if (typeof v === 'number') params[k] = fmt.num(v, 1);
      else params[k] = String(v);
    }
    return t(`insights.${i.kind}` as 'insights.masteryLeader', params);
  };
}

export function InsightList({
  insights,
  limit,
  collapsedCount,
  compact = false,
  className,
}: {
  insights: Insight[];
  /** Qat'iy chegara (masalan, taqdimotda). */
  limit?: number;
  /** Boshida shuncha ko'rinadi, qolgani "Yana" bilan ochiladi. */
  collapsedCount?: number;
  compact?: boolean;
  className?: string;
}) {
  const { t } = useI18n();
  const text = useInsightText();
  const [expanded, setExpanded] = useState(false);
  const capped = limit ? insights.slice(0, limit) : insights;
  const list = collapsedCount && !expanded ? capped.slice(0, collapsedCount) : capped;
  const hidden = capped.length - list.length;
  if (!list.length) return <p className="text-sm text-muted-foreground">{t('insights.empty')}</p>;
  return (
    <>
    <ul className={cn('space-y-2', className)}>
      {list.map((i) => {
        const s = STYLE[i.severity];
        const Icon = s.icon;
        return (
          <li key={i.id}>
            <Link href={i.href} className={cn('group flex h-full items-start gap-3 rounded-xl p-3 ring-1 ring-inset transition-colors hover:brightness-110', s.ring)}>
              <span className={cn('mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg', s.chip)}>
                <Icon className="h-3.5 w-3.5" />
              </span>
              <span className="min-w-0 flex-1">
                {!compact && <span className={cn('mb-1 inline-block rounded-full px-2 py-0.5 text-[0.62rem] font-bold uppercase tracking-[0.1em]', s.chip)}>{t(`enums.severity.${i.severity}`)}</span>}
                <span className="block text-[0.82rem] leading-snug">{text(i)}</span>
              </span>
              <ArrowUpRight className="mt-1 h-3.5 w-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
            </Link>
          </li>
        );
      })}
    </ul>
    {hidden > 0 && (
      <button
        type="button"
        onClick={() => setExpanded(true)}
        className="mt-2 inline-flex h-8 items-center gap-1 rounded-lg px-2.5 text-[0.78rem] font-semibold text-primary hover:bg-primary/[0.08]"
      >
        {t('common.more')} ({hidden})
        <ChevronDown className="h-3.5 w-3.5" />
      </button>
    )}
    </>
  );
}
