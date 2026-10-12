'use client';

import { DoorOpen, LayoutGrid, MessageSquarePlus, MessagesSquare, Radio, ShieldAlert, UserPlus } from 'lucide-react';
import Link from 'next/link';

import { useCan } from '@/auth/use-session';
import { Button } from '@/components/ui/button';
import { SchoolLogo } from '@/components/common/school-logo';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { withBase } from '@/lib/base-path';

const MORNING_END = 12 * 60;
const DAY_END = 17 * 60;

export function DashboardHero({ data }: { data: DashboardOverview | undefined }) {
  const { t, formatDate } = useI18n();
  const can = useCan();
  const school = useSchool();
  const minute = data?.minute ?? 0;
  const greeting = minute < MORNING_END ? t('dashboard.greeting.morning') : minute < DAY_END ? t('dashboard.greeting.day') : t('dashboard.greeting.evening');
  const firstName = data?.actorName.split(' ').slice(1, 2).join(' ') || data?.actorName;

  return (
    <section className="relative mb-6 overflow-hidden rounded-2xl bg-hero-gradient p-6 text-white shadow-lg animate-fade-in md:p-8">
      <div className="pointer-events-none absolute -right-16 -top-24 h-72 w-72 rounded-full bg-white/10 blur-2xl" />
      <div className="pointer-events-none absolute -bottom-28 right-40 h-64 w-64 rounded-full bg-white/5 blur-2xl" />
      <div className="relative flex flex-wrap items-end justify-between gap-6">
        <div className="flex min-w-0 items-center gap-4">
          {school.data && <SchoolLogo school={school.data.school} className="hidden h-16 w-16 text-lg ring-4 ring-white/20 sm:flex" />}
          <div className="min-w-0">
            <p className="text-sm text-white/75">{data ? formatDate(`${data.date}T12:00:00`, 'EEEE, d MMMM yyyy') : ' '}</p>
            <h1 className="mt-1 font-display text-2xl font-semibold tracking-tight md:text-3xl">
              {greeting}
              {firstName ? `, ${firstName}` : ''}!
            </h1>
            <div className="mt-3 flex flex-wrap items-center gap-2 text-sm">
              <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 font-medium backdrop-blur">
                <span className="relative flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-300 opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-300" />
                </span>
                {t('dashboard.live')}
              </span>
              {data && !data.schoolDay && <span className="rounded-full bg-white/15 px-3 py-1">{t('dashboard.dayOff')}</span>}
              {data?.schoolMode?.emergency && (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-red-500/90 px-3 py-1 font-medium">
                  <ShieldAlert className="h-3.5 w-3.5" />
                  {t('dashboard.kpi.emergencyOn')}
                </span>
              )}
            </div>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          {can('attendance.kiosk') && (
            <Button asChild variant="secondary" className="bg-white text-primary hover:bg-white/90">
              <a href={withBase('/kiosk/')} target="_blank" rel="noreferrer">
                <DoorOpen />
                {t('dashboard.quick.kiosk')}
              </a>
            </Button>
          )}
          {can('attendance.view') && (
            <HeroLink href="/attendance" icon={<LayoutGrid />} label={t('dashboard.quick.board')} />
          )}
          {(can('messages.sendSchool') || can('messages.sendClass')) && (
            <HeroLink href="/messages/new" icon={<MessageSquarePlus />} label={t('dashboard.quick.message')} />
          )}
          {can('students.manage') && <HeroLink href="/students" icon={<UserPlus />} label={t('dashboard.quick.addStudent')} />}
          {can('care.individual') && <HeroLink href="/care/requests" icon={<MessagesSquare />} label={t('dashboard.quick.requests')} />}
          {can('care.surveys') && <HeroLink href="/care/surveys" icon={<Radio />} label={t('dashboard.quick.survey')} />}
        </div>
      </div>
    </section>
  );
}

function HeroLink({ href, icon, label }: { href: string; icon: React.ReactNode; label: string }) {
  return (
    <Button asChild variant="ghost" className="border border-white/25 bg-white/10 text-white hover:bg-white/20 hover:text-white">
      <Link href={href}>
        {icon}
        {label}
      </Link>
    </Button>
  );
}
