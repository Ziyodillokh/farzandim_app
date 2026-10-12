'use client';

import { CalendarCheck2, GraduationCap, Pencil, Send, Smartphone, UsersRound } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassDetail } from '@/data/mock/services/classes';
import { useI18n } from '@/i18n';
import { useClassDetail, useClassMode, useInviteClassGuardians, useTodayBoard } from '../hooks';
import { ClassAttendanceCard } from './class-attendance-card';
import { ClassFormDialog } from './class-form-dialog';
import { ClassModeCard } from './class-mode-card';
import { ClassStudentsCard } from './class-students-card';
import { HomeroomCard } from './homeroom-card';
import { ModeChip } from './mode-chip';

export function ClassDetailSkeleton() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-16 w-72" />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-28 rounded-xl" />
        ))}
      </div>
      <Skeleton className="h-96 rounded-xl" />
    </div>
  );
}

export function ClassDetailView({ id }: { id: string | null }) {
  const { t, tc, formatNumber } = useI18n();
  const can = useCan();
  const canSeeAttendance = can('attendance.view');
  const detail = useClassDetail(id);
  const mode = useClassMode(id);
  const board = useTodayBoard(canSeeAttendance && Boolean(id));
  const invite = useInviteClassGuardians();
  const [editing, setEditing] = useState<ClassDetail | null>(null);
  const [inviteOpen, setInviteOpen] = useState(false);

  if (!id || detail.isError) {
    return (
      <div className="rounded-xl border bg-card">
        <EmptyState
          icon={<GraduationCap />}
          title={t('classes.view.notFound')}
          action={
            <Button asChild variant="outline">
              <Link href="/classes">{t('classes.view.back')}</Link>
            </Button>
          }
        />
      </div>
    );
  }
  if (!detail.data) return <ClassDetailSkeleton />;

  const c = detail.data;
  const today = board.data?.rows.find((r) => r.classId === c.id);
  const subtitle = [c.shiftName, c.room ? t('classes.card.room', { room: c.room }) : null, tc('common.studentsCount', c.size)].filter(Boolean).join(' · ');

  const sendInvites = async () => {
    try {
      await invite.mutateAsync({ classId: c.id });
      setInviteOpen(false);
    } catch {
      // toast — hooks ichida
    }
  };

  return (
    <>
      <PageHeader
        backHref="/classes"
        backLabel={t('classes.view.back')}
        title={t('classes.view.title', { name: c.name })}
        badge={mode.data && <ModeChip state={mode.data.state} />}
        subtitle={subtitle}
        actions={
          <>
            {canSeeAttendance && (
              <Button asChild variant="outline">
                <Link href={`/attendance/class?id=${c.id}`}>
                  <CalendarCheck2 />
                  {t('classes.view.openAttendance')}
                </Link>
              </Button>
            )}
            <Can perm="guardians.link">
              {c.notInvitedGuardians > 0 && (
                <Button variant="soft" onClick={() => setInviteOpen(true)}>
                  <Send />
                  {t('classes.view.inviteParents')} ({formatNumber(c.notInvitedGuardians)})
                </Button>
              )}
            </Can>
            <Can perm="classes.manage">
              <Button onClick={() => setEditing(c)}>
                <Pencil />
                {t('common.edit')}
              </Button>
            </Can>
          </>
        }
      />

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard icon={<GraduationCap />} label={t('classes.stats.students')} value={formatNumber(c.size)} hint={c.homeroomName ?? t('classes.card.noHomeroom')} />
        <StatCard
          icon={<UsersRound />}
          tone="success"
          label={t('classes.card.parentsLinked')}
          value={`${c.linkedRate}%`}
          footer={<Progress value={c.linkedRate} className="h-1.5" indicatorClassName="bg-success" />}
        />
        <StatCard
          icon={<Smartphone />}
          tone="info"
          label={t('classes.card.phones')}
          value={`${c.phoneRate}%`}
          footer={<Progress value={c.phoneRate} className="h-1.5" indicatorClassName="bg-info" />}
        />
        {canSeeAttendance && (
          <StatCard
            icon={<CalendarCheck2 />}
            tone="warning"
            label={t('classes.stats.attendance')}
            value={today?.schoolDay ? `${today.rate}%` : '—'}
            hint={today?.schoolDay ? t('classes.stats.attendanceHint', { present: today.counts.present + today.counts.late, absent: today.counts.absent }) : t('classes.card.notSchoolDay')}
            loading={board.isLoading}
          />
        )}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="min-w-0 lg:col-span-2">
          <ClassStudentsCard classId={c.id} />
        </div>
        <div className="space-y-6">
          <ClassModeCard classId={c.id} shift={c.shift} />
          {canSeeAttendance && <ClassAttendanceCard row={today} loading={board.isLoading} />}
          <HomeroomCard homeroom={c.homeroom} />
        </div>
      </div>

      <ClassFormDialog open={Boolean(editing)} onOpenChange={(open) => !open && setEditing(null)} row={editing ?? undefined} />
      <ConfirmDialog
        open={inviteOpen}
        onOpenChange={setInviteOpen}
        title={t('classes.view.inviteTitle')}
        description={t('classes.view.inviteText', { name: c.name, count: c.notInvitedGuardians })}
        confirmLabel={t('classes.view.inviteConfirm')}
        loading={invite.isPending}
        onConfirm={() => void sendInvites()}
      />
    </>
  );
}
