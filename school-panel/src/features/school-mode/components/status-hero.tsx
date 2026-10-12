'use client';

import { CalendarOff, Coffee, MoonStar, PowerOff, ShieldCheck, Siren, Sunrise, type LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';

import type { Tone } from '@/components/common/stat-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { SchoolModeOverview, ShiftNow } from '@/data/mock/services/school-mode';
import { useClockNow } from '@/features/engine/use-clock';
import { useI18n } from '@/i18n';
import { clamp, cn, hhmmToMinutes } from '@/lib/utils';
import { TONE_ORB } from '../lib';

type HeroKind = 'EMERGENCY' | 'DISABLED' | 'LESSON' | 'BREAK' | 'BEFORE' | 'AFTER' | 'DAY_OFF';
type Hero = { kind: HeroKind; shift: ShiftNow | null };

/** Bosh holat: favqulodda → o'chirilgan → dars/tanaffus → boshlanmagan → tugagan → dam olish. */
function heroOf(o: SchoolModeOverview): Hero {
  if (o.emergency.active && o.emergency.scope === 'SCHOOL') return { kind: 'EMERGENCY', shift: null };
  if (!o.policyEnabled) return { kind: 'DISABLED', shift: null };
  const active = o.shifts.find((s) => s.phase.kind === 'LESSON' || s.phase.kind === 'BREAK');
  if (active) return { kind: active.phase.kind === 'LESSON' ? 'LESSON' : 'BREAK', shift: active };
  const upcoming = o.shifts.filter((s) => s.phase.kind === 'BEFORE').sort((a, b) => a.start.localeCompare(b.start))[0];
  if (upcoming) return { kind: 'BEFORE', shift: upcoming };
  const finished = o.shifts.find((s) => s.phase.kind === 'AFTER');
  return { kind: finished ? 'AFTER' : 'DAY_OFF', shift: finished ?? null };
}

const ICONS: Record<HeroKind, LucideIcon> = {
  EMERGENCY: Siren,
  DISABLED: PowerOff,
  LESSON: ShieldCheck,
  BREAK: Coffee,
  BEFORE: Sunrise,
  AFTER: MoonStar,
  DAY_OFF: CalendarOff,
};

const TONES: Record<HeroKind, Tone> = {
  EMERGENCY: 'destructive',
  DISABLED: 'muted',
  LESSON: 'primary',
  BREAK: 'info',
  BEFORE: 'primary',
  AFTER: 'muted',
  DAY_OFF: 'muted',
};

/** Shisha ustidagi yumshoq rangli nurlar (blursiz radial gradient). */
const GLOWS: Record<Tone, string> = {
  primary:
    'bg-[radial-gradient(60%_140%_at_0%_0%,hsl(var(--primary)/0.18),transparent_62%),radial-gradient(45%_120%_at_100%_100%,hsl(192_90%_50%/0.12),transparent_70%)]',
  info: 'bg-[radial-gradient(60%_140%_at_0%_0%,hsl(var(--info)/0.2),transparent_62%),radial-gradient(45%_120%_at_100%_100%,hsl(var(--primary)/0.1),transparent_70%)]',
  destructive:
    'bg-[radial-gradient(60%_140%_at_0%_0%,hsl(var(--destructive)/0.2),transparent_62%),radial-gradient(45%_120%_at_100%_100%,hsl(var(--destructive)/0.08),transparent_70%)]',
  muted: 'bg-[radial-gradient(60%_140%_at_0%_0%,hsl(var(--primary)/0.07),transparent_62%)]',
  success: '',
  warning: '',
};

const CHIP: Record<Tone, string> = {
  primary: 'bg-primary/10 text-primary ring-primary/20',
  info: 'bg-info/10 text-info ring-info/25',
  destructive: 'bg-destructive/10 text-destructive ring-destructive/25',
  muted: 'bg-muted text-muted-foreground ring-border/60',
  success: 'bg-success/10 text-success ring-success/25',
  warning: 'bg-warning/15 text-warning ring-warning/25',
};

const WATERMARK: Record<Tone, string> = {
  primary: 'text-primary',
  info: 'text-info',
  destructive: 'text-destructive',
  muted: 'text-foreground',
  success: 'text-success',
  warning: 'text-warning',
};

const BAR: Record<Tone, string> = {
  primary: 'from-primary to-sky-400',
  info: 'from-info to-cyan-300',
  destructive: 'from-destructive to-destructive',
  muted: 'from-muted-foreground/60 to-muted-foreground/40',
  success: 'from-success to-success',
  warning: 'from-warning to-warning',
};

function useHeroText(o: SchoolModeOverview, hero: Hero): { headline: string; sub: string; chip: string | null } {
  const { t, tc, formatDate } = useI18n();
  const phase = hero.shift?.phase;
  const shiftName = hero.shift?.name ?? '';
  const endsAt = phase && 'endsAt' in phase ? phase.endsAt : '';
  switch (hero.kind) {
    case 'EMERGENCY':
      return {
        headline: t('schoolMode.hero.emergencySchool'),
        sub: t('schoolMode.hero.emergencyMeta', { name: o.emergency.byName ?? '—', time: o.emergency.at ? formatDate(o.emergency.at, 'HH:mm') : '—', reason: o.emergency.reason }),
        chip: null,
      };
    case 'LESSON':
      return {
        headline: t('schoolMode.hero.lesson', { shift: shiftName, no: phase && 'periodNo' in phase ? phase.periodNo : 0 }),
        sub: t('schoolMode.hero.nextBell', { time: endsAt }),
        chip: tc('schoolMode.hero.restricted', hero.shift?.restrictedClasses ?? 0),
      };
    case 'BREAK':
      return {
        headline: t('schoolMode.hero.break', { shift: shiftName }),
        sub: t('schoolMode.hero.nextBell', { time: endsAt }),
        chip: (hero.shift?.restrictedClasses ?? 0) > 0 ? t('schoolMode.hero.breakStrict') : t('schoolMode.hero.breakRelaxed'),
      };
    case 'BEFORE':
      return { headline: t('schoolMode.hero.before', { time: hero.shift?.start ?? '' }), sub: t('schoolMode.hero.beforeHint'), chip: null };
    case 'AFTER':
      return { headline: t('schoolMode.hero.after'), sub: t('schoolMode.hero.afterHint'), chip: null };
    case 'DISABLED':
      return { headline: t('schoolMode.hero.disabled'), sub: t('schoolMode.hero.disabledHint'), chip: null };
    default:
      return {
        headline: o.holiday ? t('schoolMode.hero.holiday', { name: o.holiday.name }) : t('schoolMode.hero.dayOff'),
        sub: t('schoolMode.hero.dayOffHint'),
        chip: null,
      };
  }
}

/** Joriy dars/tanaffus qancha o'tgani — ingichka chiziq va "N daq qoldi". */
function PeriodProgress({ shift, tone, nowMinute }: { shift: ShiftNow; tone: Tone; nowMinute: number }) {
  const { t } = useI18n();
  const p = shift.phase;
  if (p.kind !== 'LESSON' && p.kind !== 'BREAK') return null;
  const start = hhmmToMinutes(p.startsAt);
  const end = hhmmToMinutes(p.endsAt);
  const progress = clamp(((nowMinute - start) / Math.max(1, end - start)) * 100, 0, 100);
  const left = Math.max(0, Math.ceil(end - nowMinute));
  return (
    <div className="flex min-w-[220px] flex-1 items-center gap-3">
      <span className="text-xs font-semibold tabular-nums text-muted-foreground">{p.startsAt}</span>
      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-muted dark:bg-white/[0.06]" role="progressbar" aria-valuenow={Math.round(progress)} aria-valuemin={0} aria-valuemax={100}>
        <div className={cn('h-full rounded-full bg-gradient-to-r transition-[width] duration-700', BAR[tone])} style={{ width: `${progress}%` }} />
      </div>
      <span className="text-xs font-semibold tabular-nums text-muted-foreground">{p.endsAt}</span>
      <span className="whitespace-nowrap text-xs font-medium text-foreground">{t('schoolMode.hero.remaining', { count: left })}</span>
    </div>
  );
}

function OtherShifts({ shifts, featuredId }: { shifts: ShiftNow[]; featuredId: string | null }) {
  const { t } = useI18n();
  const others = shifts.filter((s) => s.id !== featuredId);
  if (others.length === 0) return null;
  return (
    <div className="flex flex-wrap gap-2">
      {others.map((s) => {
        const p = s.phase;
        const state = t(`schoolMode.schedule.phase.${p.kind}`, {
          no: 'periodNo' in p ? p.periodNo : '',
          time: 'endsAt' in p ? p.endsAt : 'startsAt' in p ? p.startsAt : '',
        });
        return (
          <span key={s.id} className="rounded-full bg-white/60 px-3 py-1 text-xs font-medium text-muted-foreground ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]">
            {t('schoolMode.hero.otherShift', { shift: s.name, state })}
          </span>
        );
      })}
    </div>
  );
}

/** Jonli holat banneri — premium shisha karta. `actions` — favqulodda tugmalar. */
export function StatusHero({ overview, loading, actions }: { overview: SchoolModeOverview | undefined; loading: boolean; actions?: ReactNode }) {
  if (loading || !overview) return <Skeleton className="mb-6 h-48 w-full rounded-2xl" />;
  return <HeroBody overview={overview} actions={actions} />;
}

function HeroBody({ overview, actions }: { overview: SchoolModeOverview; actions?: ReactNode }) {
  const { t, formatDate } = useI18n();
  const now = useClockNow(15_000);
  const hero = heroOf(overview);
  const text = useHeroText(overview, hero);
  const tone = TONES[hero.kind];
  const Icon = ICONS[hero.kind];
  const live = hero.kind === 'LESSON' || hero.kind === 'BREAK' || hero.kind === 'EMERGENCY';
  const nowMinute = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60;
  const hasFooter = Boolean(hero.shift && live) || overview.shifts.some((s) => s.id !== hero.shift?.id);

  return (
    <section
      className={cn('glass relative mb-6 overflow-hidden rounded-2xl animate-fade-in', hero.kind === 'EMERGENCY' && 'ring-1 ring-destructive/40')}
      aria-live="polite"
    >
      <div aria-hidden className={cn('pointer-events-none absolute inset-0', GLOWS[tone])} />
      <Icon aria-hidden className={cn('pointer-events-none absolute -right-8 -top-10 h-52 w-52 opacity-[0.05]', WATERMARK[tone])} />
      <div className="relative flex flex-col gap-6 p-6 md:p-7 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex min-w-0 items-start gap-4 md:gap-5">
          <span className={cn('relative flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl ring-1 ring-inset md:h-16 md:w-16', TONE_ORB[tone])}>
            {live && <span aria-hidden className="absolute inset-0 animate-pulse-ring rounded-2xl ring-2 ring-current opacity-40" />}
            <Icon className="h-7 w-7 md:h-8 md:w-8" aria-hidden />
          </span>
          <div className="min-w-0 space-y-2.5">
            <p className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">
              <span className={cn('h-1.5 w-1.5 rounded-full', live ? 'animate-pulse bg-success' : 'bg-muted-foreground/50')} aria-hidden />
              {t('schoolMode.hero.now')} · <span className="tabular-nums">{formatDate(now, 'HH:mm')}</span>
            </p>
            <h2 className="font-display text-[1.45rem] font-semibold leading-tight tracking-[-0.02em] sm:text-[1.6rem] md:text-[2.1rem]">
              {/* "1-smena · 3-dars" — qismlar ichida qatorga bo'linmasin (mobil). */}
              {text.headline.split(' · ').map((part, i) => (
                <span key={part}>
                  {i > 0 && ' · '}
                  <span className="whitespace-nowrap">{part}</span>
                </span>
              ))}
            </h2>
            <div className="flex flex-wrap items-center gap-2 text-sm">
              {text.chip && (
                <span className={cn('inline-flex items-center gap-1.5 rounded-full px-3 py-1 font-semibold ring-1 ring-inset', CHIP[tone])}>
                  <ShieldCheck className="h-4 w-4" aria-hidden />
                  {text.chip}
                </span>
              )}
              <span className="text-muted-foreground">{text.sub}</span>
            </div>
          </div>
        </div>
        {actions && <div className="flex shrink-0 flex-wrap items-center gap-2 no-print [&>*]:max-sm:flex-1">{actions}</div>}
      </div>
      {hasFooter && (
        <div className="relative flex flex-wrap items-center gap-x-6 gap-y-3 border-t border-border/50 px-6 py-3.5 dark:border-white/[0.06] md:px-7">
          {hero.shift && <PeriodProgress shift={hero.shift} tone={tone} nowMinute={nowMinute} />}
          <OtherShifts shifts={overview.shifts} featuredId={hero.shift?.id ?? null} />
        </div>
      )}
    </section>
  );
}

/** Sinf bo'yicha favqulodda o'chirish faol bo'lsa — ogohlantirish chizig'i. */
export function ClassEmergencyStrip({ overview }: { overview: SchoolModeOverview | undefined }) {
  const { t, formatDate } = useI18n();
  const e = overview?.emergency;
  if (!e?.active || e.scope !== 'CLASS') return null;
  return (
    <div role="alert" className="glass mb-4 flex flex-wrap items-center gap-3 rounded-2xl px-4 py-3 text-sm ring-1 ring-destructive/40 animate-fade-in">
      <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset', TONE_ORB.destructive)}>
        <Siren className="h-4 w-4" aria-hidden />
      </span>
      <span className="font-semibold text-destructive">{t('schoolMode.hero.emergencyClass', { classes: e.classNames.join(', ') })}</span>
      <span className="text-muted-foreground">
        {t('schoolMode.hero.emergencyMeta', { name: e.byName ?? '—', time: e.at ? formatDate(e.at, 'HH:mm') : '—', reason: e.reason })}
      </span>
    </div>
  );
}
