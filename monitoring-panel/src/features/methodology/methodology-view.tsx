'use client';

import {
  ArrowDown,
  ArrowUp,
  BookOpenCheck,
  Brain,
  CalendarCheck2,
  Compass,
  ExternalLink,
  FlaskConical,
  HeartHandshake,
  Landmark,
  type LucideIcon,
  Minus,
  Ruler,
  Search,
  ShieldCheck,
  Smartphone,
} from 'lucide-react';
import { useMemo, useState, type ReactNode } from 'react';

import { Section } from '@/components/common/section';
import { Input } from '@/components/ui/input';
import type { MetricKey } from '@/data/contracts';
import { K_MIN } from '@/data/mock/model/engine';
import { METRIC_KEYS, METRICS, type MetricDomain } from '@/data/mock/model/metrics';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

type SourceKey = 'tests' | 'iq' | 'kelajak' | 'voice' | 'attendance' | 'devices' | 'official';

const SOURCES: ReadonlyArray<{ key: SourceKey; icon: LucideIcon; metrics: readonly MetricKey[] }> = [
  { key: 'tests', icon: BookOpenCheck, metrics: ['mastery', 'success', 'tests', 'active'] },
  { key: 'iq', icon: Brain, metrics: ['iqParticipation', 'iqMean', 'iqHigh', 'iqGrowthZone'] },
  { key: 'kelajak', icon: Compass, metrics: ['careerReadiness', 'support', 'safetyGap'] },
  { key: 'voice', icon: HeartHandshake, metrics: ['wellbeing', 'bullying', 'anxiety', 'sleep', 'careRequests', 'schoolQuality', 'teacherRelation'] },
  { key: 'attendance', icon: CalendarCheck2, metrics: ['attendance', 'late', 'chronic'] },
  { key: 'devices', icon: Smartphone, metrics: ['parents', 'screenTime', 'night', 'schoolMode', 'steps'] },
  { key: 'official', icon: Landmark, metrics: ['coverage'] },
];

const DOMAINS: readonly MetricDomain[] = ['coverage', 'mastery', 'iq', 'interests', 'wellbeing', 'attendance', 'digital'];
const RULES = ['period', 'weights', 'national', 'colors', 'filters'] as const;
const PRIVACY = ['k', 'aggregates', 'screening', 'iq', 'regions'] as const;

const LINKS = [
  { key: 'stat', href: 'https://stat.uz' },
  { key: 'regions', href: 'https://www.naturalearthdata.com/' },
  { key: 'districts', href: 'https://www.geoboundaries.org/' },
  { key: 'newDistricts', href: null },
  { key: 'fonts', href: 'https://fonts.google.com/' },
] as const;

export const METHODOLOGY_SECTIONS = ['sources', 'dictionary', 'rules', 'privacy', 'licenses', 'demo'] as const;

function useUnitText() {
  const { t } = useI18n();
  return (key: MetricKey): string => {
    switch (METRICS[key].unit) {
      case '%':
        return '%';
      case 'min':
        return t('common.units.min');
      case 'per1000':
        return t('common.units.per1000');
      case 'index':
        return `${t('common.units.index')} 0–100`;
      case 'score':
        return t('common.units.score');
      case 'perWeek':
        return t('common.units.perWeek');
      case 'steps':
        return t('common.units.steps');
    }
  };
}

function Chip({ children, className }: { children: ReactNode; className?: string }) {
  return <span className={cn('inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[0.68rem] font-semibold ring-1 ring-inset', className)}>{children}</span>;
}

function Sources() {
  const { t } = useI18n();
  return (
    <div className="grid gap-3 md:grid-cols-2 2xl:grid-cols-3">
      {SOURCES.map(({ key, icon: Icon, metrics }) => (
        <div key={key} className="rounded-2xl bg-primary/[0.04] p-4 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
          <div className="flex items-center gap-3">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
              <Icon className="h-[18px] w-[18px]" />
            </span>
            <h3 className="text-[0.9rem] font-semibold">{t(`methodology.sources.${key}.title`)}</h3>
          </div>
          <p className="mt-2.5 text-[0.8rem] leading-relaxed text-muted-foreground">{t(`methodology.sources.${key}.text`)}</p>
          <div className="mt-3 flex flex-wrap gap-1.5">
            {metrics.map((m) => (
              <Chip key={m} className="bg-primary/[0.06] text-foreground/85 ring-border/60 dark:bg-white/[0.04]">
                {t(`metrics.${m}.label`)}
              </Chip>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function Dictionary() {
  const { t } = useI18n();
  const unitText = useUnitText();
  const [query, setQuery] = useState('');
  const q = query.trim().toLowerCase();
  const groups = useMemo(
    () =>
      DOMAINS.map((domain) => ({
        domain,
        metrics: METRIC_KEYS.filter((k) => METRICS[k].domain === domain).filter((k) =>
          !q ? true : [t(`metrics.${k}.label`), t(`metrics.${k}.title`), t(`metrics.${k}.description`)].some((s) => s.toLowerCase().includes(q)),
        ),
      })).filter((g) => g.metrics.length > 0),
    [q, t],
  );
  const total = groups.reduce((s, g) => s + g.metrics.length, 0);
  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="relative w-full max-w-sm">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('methodology.dictionary.search')} aria-label={t('methodology.dictionary.search')} className="pl-9" />
        </div>
        <span className="text-xs text-muted-foreground">{t('methodology.dictionary.count', { n: total })}</span>
      </div>
      {total === 0 && <p className="py-8 text-center text-sm text-muted-foreground">{t('methodology.dictionary.empty')}</p>}
      <div className="space-y-6">
        {groups.map((g) => (
          <div key={g.domain}>
            <h3 className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t(`methodology.domains.${g.domain}`)}</h3>
            <dl className="divide-y divide-border/50 overflow-hidden rounded-2xl ring-1 ring-inset ring-border/60">
              {g.metrics.map((k) => {
                const better = METRICS[k].better;
                const DirIcon = better === 'up' ? ArrowUp : better === 'down' ? ArrowDown : Minus;
                return (
                  <div key={k} className="grid gap-2 px-4 py-3 md:grid-cols-[minmax(0,15rem)_minmax(0,1fr)_auto] md:items-start md:gap-5">
                    <dt className="text-[0.86rem] font-semibold">{t(`metrics.${k}.title`)}</dt>
                    <dd className="text-[0.8rem] leading-relaxed text-muted-foreground">{t(`metrics.${k}.description`)}</dd>
                    <dd className="flex flex-wrap gap-1.5 md:justify-end">
                      <Chip className="bg-muted/60 text-foreground/80 ring-border/60">
                        <Ruler className="h-3 w-3" />
                        {unitText(k)}
                      </Chip>
                      <Chip className="bg-primary/[0.07] text-primary ring-primary/20">
                        <DirIcon className="h-3 w-3" />
                        {t(`methodology.dictionary.${better}`)}
                      </Chip>
                    </dd>
                  </div>
                );
              })}
            </dl>
          </div>
        ))}
      </div>
    </div>
  );
}

function CardList<K extends string>({ keys, ns, params }: { keys: readonly K[]; ns: 'rules' | 'privacy'; params?: Record<string, string | number> }) {
  const { t } = useI18n();
  return (
    <div className="grid gap-3 md:grid-cols-2">
      {keys.map((k, i) => (
        <div key={k} className="flex gap-3 rounded-2xl bg-primary/[0.04] p-4 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary/12 font-display text-[0.72rem] font-semibold text-primary">{i + 1}</span>
          <div>
            <h3 className="text-[0.88rem] font-semibold">{t(`methodology.${ns}.${k}.title` as 'methodology.rules.period.title', params)}</h3>
            <p className="mt-1 text-[0.8rem] leading-relaxed text-muted-foreground">{t(`methodology.${ns}.${k}.text` as 'methodology.rules.period.text', params)}</p>
          </div>
        </div>
      ))}
    </div>
  );
}

function Licenses() {
  const { t } = useI18n();
  return (
    <ul className="space-y-2.5 text-[0.82rem]">
      {LINKS.map(({ key, href }) => (
        <li key={key} className="flex items-start gap-2.5">
          <span className="mt-[7px] h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
          <span className="text-muted-foreground">
            {t(`methodology.licenses.${key}`)}
            {href && (
              <a href={href} target="_blank" rel="noopener noreferrer" className="ml-1.5 inline-flex items-center gap-0.5 font-medium text-primary hover:underline">
                {new URL(href).hostname.replace('www.', '')}
                <ExternalLink className="h-3 w-3" />
              </a>
            )}
          </span>
        </li>
      ))}
    </ul>
  );
}

/** Metodologiya: manbalar, ko'rsatkichlar lug'ati, hisoblash qoidalari, maxfiylik va litsenziyalar. */
export function MethodologyView() {
  const { t } = useI18n();
  return (
    <div className="grid gap-6 xl:grid-cols-[220px_minmax(0,1fr)]">
      <nav aria-label={t('methodology.toc')} className="hidden xl:block">
        <div className="sticky top-24 rounded-2xl p-2 glass">
          <p className="px-3 pb-1 pt-2 text-[0.68rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('methodology.toc')}</p>
          {METHODOLOGY_SECTIONS.map((s) => (
            <a key={s} href={`#m-${s}`} className="block rounded-xl px-3 py-2 text-[0.82rem] text-muted-foreground transition-colors hover:bg-primary/[0.07] hover:text-foreground">
              {t(`methodology.${s}.title`)}
            </a>
          ))}
        </div>
      </nav>
      <div className="min-w-0 space-y-5">
        <Section id="m-sources" icon={<Landmark />} title={t('methodology.sources.title')} subtitle={t('methodology.sources.sub')}>
          <Sources />
        </Section>
        <Section id="m-dictionary" icon={<Ruler />} title={t('methodology.dictionary.title')} subtitle={t('methodology.dictionary.sub')}>
          <Dictionary />
        </Section>
        <Section id="m-rules" icon={<BookOpenCheck />} title={t('methodology.rules.title')}>
          <CardList keys={RULES} ns="rules" />
        </Section>
        <Section id="m-privacy" icon={<ShieldCheck />} title={t('methodology.privacy.title')}>
          <CardList keys={PRIVACY} ns="privacy" params={{ k: K_MIN }} />
        </Section>
        <Section id="m-licenses" icon={<ExternalLink />} title={t('methodology.licenses.title')}>
          <Licenses />
        </Section>
        <Section id="m-demo" icon={<FlaskConical />} title={t('methodology.demo.title')}>
          <p className="max-w-3xl text-[0.84rem] leading-relaxed text-muted-foreground">{t('methodology.demo.text')}</p>
        </Section>
      </div>
    </div>
  );
}
