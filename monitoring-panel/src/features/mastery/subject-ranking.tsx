'use client';

import { ArrowDownRight, CircleAlert, ListOrdered, Rocket, Trophy } from 'lucide-react';
import type { ReactNode } from 'react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Mastery, Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { Note } from './kit/layout';
import { type RankedSubject, rankSubjects, splitTaught, subjectHighlights } from './subject-rank';
import { SubjectRows } from './subject-rows';

type CalloutTone = 'good' | 'attention' | 'info';

const CALLOUT_TONE: Record<CalloutTone, string> = {
  good: 'bg-emerald-500/10 text-emerald-600 ring-emerald-500/25 dark:text-emerald-300',
  attention: 'bg-amber-500/10 text-amber-600 ring-amber-500/30 dark:text-amber-300',
  info: 'bg-sky-500/10 text-sky-600 ring-sky-500/25 dark:text-sky-300',
};

function Callout({ tone, icon, label, title, detail }: { tone: CalloutTone; icon: ReactNode; label: string; title: string; detail: string }) {
  return (
    <div className="flex items-start gap-3 rounded-xl bg-primary/[0.05] p-3 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
      <span aria-hidden className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset [&_svg]:size-4', CALLOUT_TONE[tone])}>
        {icon}
      </span>
      <div className="min-w-0">
        <p className="text-[0.66rem] font-semibold uppercase tracking-[0.1em] text-muted-foreground">{label}</p>
        <p className="mt-0.5 truncate text-[0.92rem] font-semibold">{title}</p>
        <p className="text-[0.74rem] tabular-nums text-muted-foreground">{detail}</p>
      </div>
    </div>
  );
}

function Callouts({ rows, region }: { rows: RankedSubject[]; region: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const h = subjectHighlights(rows);
  const name = (r: RankedSubject) => t(`enums.subject.${r.subject}`);
  const valueLine = (r: RankedSubject) =>
    region && r.national !== null ? `${fmt.value('mastery', r.value)} · ${t('mastery.subjects.metaNational', { value: fmt.value('mastery', r.national) })}` : fmt.value('mastery', r.value);
  const items = [
    h.strongest && <Callout key="s" tone="good" icon={<Trophy />} label={t('mastery.subjects.strongest')} title={name(h.strongest)} detail={valueLine(h.strongest)} />,
    h.weakest && <Callout key="w" tone="attention" icon={<CircleAlert />} label={t('mastery.subjects.weakest')} title={name(h.weakest)} detail={valueLine(h.weakest)} />,
    h.fastest && (
      <Callout key="f" tone="info" icon={<Rocket />} label={t('mastery.subjects.fastest')} title={name(h.fastest)} detail={t('mastery.subjects.deltaYear', { value: fmt.delta('mastery', h.fastest.delta) })} />
    ),
    region && h.lagging && (
      <Callout
        key="l"
        tone="attention"
        icon={<ArrowDownRight />}
        label={t('mastery.subjects.lagging')}
        title={name(h.lagging)}
        detail={t('mastery.subjects.deltaNational', { value: fmt.delta('mastery', h.lagging.vsNational) })}
      />
    ),
  ].filter(Boolean);
  if (items.length === 0) return null;
  return <div className={cn('grid gap-3 sm:grid-cols-2', items.length > 3 ? 'xl:grid-cols-4' : 'xl:grid-cols-3')}>{items}</div>;
}

/** Fanlar reytingi: eng kuchli / e'tibor talab fanlar, yillik o'zgarish, respublika bilan farq va tanlov ulushi. */
export function SubjectRankingSection({ scope, data }: { scope: Scope; data: Mastery | undefined }) {
  const { t } = useI18n();
  const region = scope.kind === 'REGION';
  const { taught, untaught } = splitTaught(data?.bySubject ?? []);
  const rows = rankSubjects(taught);
  return (
    <Section
      id="mastery-subjects"
      icon={<ListOrdered />}
      title={t('mastery.sections.subjects')}
      subtitle={t('mastery.sections.subjectsSub')}
      href="/interests"
      hrefLabel={t('mastery.subjects.toInterests')}
    >
      {!data ? (
        <Skeleton className="h-[560px] w-full rounded-xl" />
      ) : (
        <div className="space-y-5">
          {rows.length > 0 ? (
            <>
              <Callouts rows={rows} region={region} />
              <SubjectRows rows={rows} region={region} />
            </>
          ) : (
            <Note>{t('common.noData')}</Note>
          )}
          <Note>
            {t('mastery.subjects.successNote')} {t('mastery.subjects.interestNote')} {region ? t('mastery.subjects.markerNote') : ''}{' '}
            {untaught.length > 0 ? t('mastery.kit.notTaught', { list: untaught.map((s) => t(`enums.subject.${s}`)).join(', ') }) : ''}
          </Note>
        </div>
      )}
    </Section>
  );
}
