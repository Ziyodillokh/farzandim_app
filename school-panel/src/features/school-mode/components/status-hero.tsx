'use client';

import { CalendarOff, Coffee, MoonStar, PowerOff, ShieldCheck, Siren, Sunrise, type LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';

import { Skeleton } from '@/components/ui/skeleton';
import type { SchoolModeOverview, ShiftNow } from '@/data/mock/services/school-mode';
import { useClockNow } from '@/features/engine/use-clock';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

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

const SURFACE: Record<HeroKind, string> = {
  EMERGENCY: 'border-transparent bg-destructive text-destructive-foreground shadow-soft-xl',
  LESSON: 'border-transparent bg-gradient-to-br from-primary via-primary to-primary-glow text-primary-foreground shadow-primary-glow',
  BREAK: 'border-info/30 bg-info/10',
  BEFORE: 'bg-card',
  AFTER: 'bg-card',
  DAY_OFF: 'bg-card',
  DISABLED: 'bg-card',
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

function OtherShifts({ shifts, featuredId, inverted }: { shifts: ShiftNow[]; featuredId: string | null; inverted: boolean }) {
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
          <span key={s.id} className={cn('rounded-full px-3 py-1 text-xs font-medium', inverted ? 'bg-white/15' : 'bg-muted text-muted-foreground')}>
            {t('schoolMode.hero.otherShift', { shift: s.name, state })}
          </span>
        );
      })}
    </div>
  );
}

type ActionsRender = (inverted: boolean) => ReactNode;

/** Jonli holat banneri — sahifaning yuragi. `actions` — favqulodda tugmalar (rangli fonda `inverted`). */
export function StatusHero({ overview, loading, actions }: { overview: SchoolModeOverview | undefined; loading: boolean; actions?: ActionsRender }) {
  if (loading || !overview) return <Skeleton className="mb-6 h-44 w-full rounded-2xl" />;
  return <HeroBody overview={overview} actions={actions} />;
}

function HeroBody({ overview, actions }: { overview: SchoolModeOverview; actions?: ActionsRender }) {
  const { t, formatDate } = useI18n();
  const now = useClockNow(15_000);
  const hero = heroOf(overview);
  const text = useHeroText(overview, hero);
  const Icon = ICONS[hero.kind];
  const inverted = hero.kind === 'LESSON' || hero.kind === 'EMERGENCY';
  return (
    <section className={cn('relative mb-6 overflow-hidden rounded-2xl border p-6 animate-fade-in md:p-7', SURFACE[hero.kind])} aria-live="polite">
      <Icon className={cn('pointer-events-none absolute -right-6 -top-6 h-44 w-44', inverted ? 'opacity-10' : 'text-primary opacity-[0.06]')} aria-hidden />
      <div className="relative flex flex-wrap items-end justify-between gap-6">
        <div className="min-w-0 max-w-2xl space-y-3">
          <p className={cn('flex items-center gap-2 text-xs font-semibold uppercase tracking-wider', inverted ? 'opacity-85' : 'text-muted-foreground')}>
            <span className="relative flex h-2 w-2">
              <span className={cn('absolute inline-flex h-full w-full animate-pulse-ring rounded-full', inverted ? 'bg-white' : 'bg-primary')} />
              <span className={cn('relative inline-flex h-2 w-2 rounded-full', inverted ? 'bg-white' : 'bg-primary')} />
            </span>
            {t('schoolMode.hero.now')} · {formatDate(now, 'HH:mm')}
          </p>
          <h2 className="font-display text-2xl font-semibold leading-tight tracking-tight md:text-[2rem]">{text.headline}</h2>
          <div className="flex flex-wrap items-center gap-2 text-sm">
            {text.chip && (
              <span className={cn('inline-flex items-center gap-1.5 rounded-full px-3 py-1 font-semibold', inverted ? 'bg-white/20' : 'bg-info/15 text-info')}>
                <ShieldCheck className="h-4 w-4" aria-hidden />
                {text.chip}
              </span>
            )}
            <span className={inverted ? 'opacity-90' : 'text-muted-foreground'}>{text.sub}</span>
          </div>
          <OtherShifts shifts={overview.shifts} featuredId={hero.shift?.id ?? null} inverted={inverted} />
        </div>
        {actions && <div className="flex flex-wrap items-center gap-2 no-print">{actions(inverted)}</div>}
      </div>
    </section>
  );
}

/** Sinf bo'yicha favqulodda o'chirish faol bo'lsa — ogohlantirish chizig'i. */
export function ClassEmergencyStrip({ overview }: { overview: SchoolModeOverview | undefined }) {
  const { t, formatDate } = useI18n();
  const e = overview?.emergency;
  if (!e?.active || e.scope !== 'CLASS') return null;
  return (
    <div role="alert" className="mb-4 flex flex-wrap items-center gap-3 rounded-xl border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm animate-fade-in">
      <Siren className="h-5 w-5 shrink-0 text-destructive" aria-hidden />
      <span className="font-semibold text-destructive">{t('schoolMode.hero.emergencyClass', { classes: e.classNames.join(', ') })}</span>
      <span className="text-muted-foreground">
        {t('schoolMode.hero.emergencyMeta', { name: e.byName ?? '—', time: e.at ? formatDate(e.at, 'HH:mm') : '—', reason: e.reason })}
      </span>
    </div>
  );
}
