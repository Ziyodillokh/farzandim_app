'use client';

import { DoorOpen, LayoutGrid, MessageSquarePlus, MessagesSquare, Radio, ShieldAlert, UserPlus } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { useCan } from '@/auth/use-session';
import { SchoolLogo } from '@/components/common/school-logo';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Button } from '@/components/ui/button';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useMe } from '@/features/profile/hooks';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { withBase } from '@/lib/base-path';
import { cn } from '@/lib/utils';

const MORNING_END = 12 * 60;
const DAY_END = 17 * 60;

type HeroAction = { key: string; href: string; label: string; icon: ReactNode; external?: boolean };

const PRIMARY = 'bg-white text-brand-900 shadow-[0_12px_28px_-12px_rgba(255,255,255,0.55)] hover:bg-white/90 dark:hover:bg-white/90';
const GHOST =
  'border border-white/15 bg-white/[0.07] text-white backdrop-blur-sm hover:bg-white/[0.14] hover:text-white dark:hover:bg-white/[0.14]';
const CHIP = 'inline-flex items-center gap-1.5 rounded-full bg-white/[0.08] px-3 py-1 ring-1 ring-inset ring-white/10';

/** Bosh sahifa banneri: "aurora navy" ustidagi shisha — joriy xodim portreti, salomlashuv, tezkor amallar. */
export function DashboardHero({ data }: { data: DashboardOverview | undefined }) {
  const { t, formatDate } = useI18n();
  const can = useCan();
  const school = useSchool();
  const me = useMe();
  const minute = data?.minute ?? 0;
  const greeting = minute < MORNING_END ? t('dashboard.greeting.morning') : minute < DAY_END ? t('dashboard.greeting.day') : t('dashboard.greeting.evening');
  const firstName = data?.actorName.split(' ').slice(1, 2).join(' ') || data?.actorName;

  const candidates: Array<HeroAction | false> = [
    can('attendance.kiosk') && { key: 'kiosk', href: withBase('/kiosk/'), label: t('dashboard.quick.kiosk'), icon: <DoorOpen />, external: true },
    can('attendance.view') && { key: 'board', href: '/attendance', label: t('dashboard.quick.board'), icon: <LayoutGrid /> },
    (can('messages.sendSchool') || can('messages.sendClass')) && { key: 'msg', href: '/messages/new', label: t('dashboard.quick.message'), icon: <MessageSquarePlus /> },
    can('students.manage') && { key: 'student', href: '/students', label: t('dashboard.quick.addStudent'), icon: <UserPlus /> },
    can('care.individual') && { key: 'requests', href: '/care/requests', label: t('dashboard.quick.requests'), icon: <MessagesSquare /> },
    can('care.surveys') && { key: 'survey', href: '/care/surveys', label: t('dashboard.quick.survey'), icon: <Radio /> },
  ];
  const actions = candidates.filter((a): a is HeroAction => a !== false);

  return (
    <section className="relative mb-6 overflow-hidden rounded-[1.75rem] bg-hero-gradient text-white shadow-glass-lg ring-1 ring-inset ring-white/10 animate-fade-in">
      <div aria-hidden className="pointer-events-none absolute inset-0">
        <div className="absolute -left-24 -top-40 h-96 w-96 rounded-full bg-[radial-gradient(circle,hsl(221_100%_62%/0.32),transparent_65%)]" />
        <div className="absolute -bottom-48 -right-24 h-[28rem] w-[28rem] rounded-full bg-[radial-gradient(circle,hsl(192_95%_55%/0.2),transparent_65%)]" />
        <div className="absolute inset-0 bg-[linear-gradient(hsl(0_0%_100%/0.035)_1px,transparent_1px),linear-gradient(90deg,hsl(0_0%_100%/0.035)_1px,transparent_1px)] bg-[size:36px_36px] [mask-image:radial-gradient(ellipse_at_75%_0%,black,transparent_65%)]" />
        <div className="absolute inset-x-10 top-0 h-px bg-gradient-to-r from-transparent via-white/45 to-transparent" />
      </div>

      <div className="relative flex flex-col gap-6 p-6 md:p-8 lg:flex-row lg:items-end lg:justify-between">
        <div className="flex min-w-0 items-center gap-4 sm:gap-6">
          <div className="relative shrink-0">
            <StaffAvatar
              name={me.data?.fullName ?? data?.actorName ?? ''}
              photo={me.data?.photo ?? null}
              portrait={me.data?.portrait ?? null}
              size="xl"
              className="shadow-[0_20px_44px_-14px_rgba(0,0,0,0.7)] ring-4 ring-white/20 max-sm:h-16 max-sm:w-16"
            />
            <span className="absolute -bottom-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-[hsl(223_62%_8%)]" aria-hidden>
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-400 shadow-[0_0_10px_rgba(52,211,153,0.8)]" />
            </span>
          </div>
          <div className="min-w-0">
            <p className="text-sm text-white/60">{data ? formatDate(`${data.date}T12:00:00`, 'EEEE, d MMMM yyyy') : ' '}</p>
            <h1 className="mt-1 font-display text-2xl font-semibold tracking-[-0.02em] md:text-[2rem] md:leading-tight">
              {greeting}
              {firstName ? (
                <>
                  , <span className="text-gradient-brand">{firstName}</span>
                </>
              ) : null}
              !
            </h1>
            <div className="mt-3 flex flex-wrap items-center gap-2 text-xs font-medium text-white/85">
              <span className={CHIP}>
                <span className="relative flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-300 opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-300" />
                </span>
                {t('dashboard.live')}
              </span>
              {school.data && (
                <span className={cn(CHIP, 'max-w-[16rem] py-0.5 pl-1')}>
                  <SchoolLogo school={school.data.school} className="h-5 w-5 rounded-full text-[0.45rem] shadow-none" />
                  <span className="truncate">{school.data.school.name}</span>
                </span>
              )}
              {data && !data.schoolDay && <span className={CHIP}>{t('dashboard.dayOff')}</span>}
              {data?.schoolMode?.emergency && (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-red-500/90 px-3 py-1 text-white">
                  <ShieldAlert className="h-3.5 w-3.5" />
                  {t('dashboard.kpi.emergencyOn')}
                </span>
              )}
            </div>
          </div>
        </div>

        {actions.length > 0 && (
          <div className="flex flex-wrap gap-2 lg:max-w-[52%] lg:justify-end">
            {actions.map((a, i) => (
              <Button key={a.key} asChild variant={i === 0 ? 'secondary' : 'ghost'} className={i === 0 ? PRIMARY : GHOST}>
                {a.external ? (
                  <a href={a.href} target="_blank" rel="noreferrer">
                    {a.icon}
                    {a.label}
                  </a>
                ) : (
                  <Link href={a.href}>
                    {a.icon}
                    {a.label}
                  </Link>
                )}
              </Button>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
