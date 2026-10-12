'use client';

import { Archive, ArchiveRestore, CalendarDays, Clock, Lock, Pencil, ShieldCheck, Smartphone, UserRound } from 'lucide-react';
import { useSearchParams } from 'next/navigation';
import { Suspense, useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { AttendanceBadge, DeviceModeBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { clockToday } from '@/data/mock/clock';
import { AttendanceCalendar } from '@/features/students/components/attendance-calendar';
import { DeviceIcon } from '@/features/students/components/device-icon';
import { GuardiansCard } from '@/features/students/components/guardians-card';
import { StudentFormDialog } from '@/features/students/components/student-form-dialog';
import { useArchiveStudent, useStudent } from '@/features/students/hooks';
import { useI18n } from '@/i18n';
import { initials } from '@/lib/utils';

function InfoRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-2.5 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right font-medium">{value}</span>
    </div>
  );
}

function ageOf(birthDate: string): number {
  const [y, m, d] = birthDate.split('-').map(Number);
  const today = clockToday();
  const [ty, tm, td] = today.split('-').map(Number);
  let age = (ty ?? 0) - (y ?? 0);
  if ((tm ?? 0) < (m ?? 0) || ((tm ?? 0) === (m ?? 0) && (td ?? 0) < (d ?? 0))) age -= 1;
  return age;
}

function StudentDetail() {
  const { t, formatDate } = useI18n();
  const can = useCan();
  const id = useSearchParams().get('id');
  const student = useStudent(id);
  const archive = useArchiveStudent();
  const [editOpen, setEditOpen] = useState(false);
  const [archiveOpen, setArchiveOpen] = useState(false);
  // Ota-onaga ulash huquqi yo'q rol (psixolog) — faqat ism va sinf.
  const psychologist = !can('guardians.link');

  if (!id) return <EmptyState icon={<UserRound />} title={t('students.detail.notFound')} />;
  if (student.isError) return <ErrorState error={student.error} onRetry={() => void student.refetch()} />;
  const s = student.data;

  return (
    <>
      <PageHeader
        backHref="/students"
        backLabel={t('students.title')}
        title={
          s ? (
            <span className="flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarFallback className="bg-primary/10 font-display text-primary">{initials(`${s.lastName} ${s.firstName}`)}</AvatarFallback>
              </Avatar>
              <span>
                {s.lastName} {s.firstName}
                <span className="mt-1 block font-sans text-sm font-normal text-muted-foreground">{s.middleName}</span>
              </span>
            </span>
          ) : (
            <Skeleton className="h-10 w-72" />
          )
        }
        badge={
          s && (
            <div className="flex gap-2">
              <Badge>{s.className}</Badge>
              <Badge variant="outline" className="font-mono">{s.studentCode}</Badge>
              {s.archived && <Badge variant="secondary">{t('students.archivedBadge')}</Badge>}
            </div>
          )
        }
        actions={
          s && (
            <Can perm="students.manage">
              <Button variant="outline" onClick={() => setEditOpen(true)}>
                <Pencil />
                {t('common.edit')}
              </Button>
              <Button variant="outline" onClick={() => setArchiveOpen(true)}>
                {s.archived ? <ArchiveRestore /> : <Archive />}
                {s.archived ? t('students.restore') : t('students.archive')}
              </Button>
            </Can>
          )
        }
      />

      {psychologist && (
        <div className="mb-6 flex items-start gap-3 rounded-xl border border-info/30 bg-info/5 p-4 text-sm">
          <Lock className="mt-0.5 h-4 w-4 shrink-0 text-info" />
          {t('students.detail.psychologistNote')}
        </div>
      )}

      {!s ? (
        <div className="grid gap-6 lg:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-64 rounded-xl" />
          ))}
        </div>
      ) : (
        <div className="grid gap-6 lg:grid-cols-3">
          <div className="space-y-6 lg:col-span-2">
            <SectionCard title={t('students.detail.profile')}>
              <div className={psychologist ? 'max-w-md' : 'grid gap-x-8 sm:grid-cols-2'}>
                <div className="divide-y">
                  <InfoRow label={t('students.fields.class')} value={s.className} />
                  <InfoRow label={t('students.detail.shift')} value={s.shiftName} />
                  <InfoRow label={t('students.detail.homeroom')} value={s.homeroomName ?? '—'} />
                </div>
                <div className={psychologist ? 'hidden' : 'divide-y'}>
                  <InfoRow label={t('students.fields.gender')} value={t(`enums.gender.${s.gender}`)} />
                  <InfoRow
                    label={t('students.fields.birthDate')}
                    value={`${formatDate(s.birthDate, 'dd.MM.yyyy')} · ${t('students.age', { age: ageOf(s.birthDate) })}`}
                  />
                  <InfoRow label={t('students.fields.device')} value={<DeviceIcon device={s.device} />} />
                </div>
              </div>
            </SectionCard>
            {!psychologist && <GuardiansCard studentId={s.id} guardians={s.guardians} />}
            {!psychologist && (
              <SectionCard title={t('students.detail.calendar')} actions={<CalendarDays className="h-4 w-4 text-muted-foreground" />}>
                <AttendanceCalendar studentId={s.id} initialMonth={clockToday().slice(0, 7)} />
              </SectionCard>
            )}
          </div>

          {!psychologist && (
            <div className="space-y-6">
              <SectionCard title={t('students.detail.today')}>
                <div className="flex items-center justify-between">
                  <AttendanceBadge status={s.today?.status ?? null} />
                  {s.today?.inAt && (
                    <span className="inline-flex items-center gap-1.5 text-sm text-muted-foreground">
                      <Clock className="h-3.5 w-3.5" />
                      {s.today.inAt}
                      {s.today.outAt && ` → ${s.today.outAt}`}
                    </span>
                  )}
                </div>
                {s.today && (
                  <p className="mt-3 text-xs text-muted-foreground">{t(`enums.attendanceSource.${s.today.source}`)}</p>
                )}
              </SectionCard>
              <SectionCard title={t('students.detail.schoolMode')} actions={<Smartphone className="h-4 w-4 text-muted-foreground" />}>
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">{t('students.detail.deviceState')}</p>
                <div className="mt-2 flex items-center justify-between">
                  {s.deviceState && <DeviceModeBadge status={s.deviceState.status} />}
                  {s.deviceState?.lastSeenAt && (
                    <span className="text-xs text-muted-foreground">
                      {t('students.detail.lastSeen', { time: formatDate(s.deviceState.lastSeenAt, 'HH:mm') })}
                    </span>
                  )}
                </div>
                <p className="mb-2 mt-5 text-xs font-medium uppercase tracking-wide text-muted-foreground">{t('students.detail.exceptions')}</p>
                {s.exceptions.filter((e) => !e.revokedAt).length === 0 ? (
                  <p className="text-sm text-muted-foreground">{t('students.detail.noExceptions')}</p>
                ) : (
                  <ul className="space-y-2">
                    {s.exceptions
                      .filter((e) => !e.revokedAt)
                      .map((e) => (
                        <li key={e.id} className="rounded-lg border bg-muted/40 p-3 text-sm">
                          <p className="flex items-center gap-2 font-medium">
                            <ShieldCheck className="h-4 w-4 text-primary" />
                            {formatDate(e.from, 'HH:mm')} – {formatDate(e.until, 'HH:mm')}
                          </p>
                          <p className="mt-1 text-muted-foreground">{e.reason}</p>
                        </li>
                      ))}
                  </ul>
                )}
              </SectionCard>
              <p className="flex items-start gap-2 rounded-xl border border-dashed p-4 text-xs text-muted-foreground">
                <Lock className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                {t('students.detail.privacyNote')}
              </p>
            </div>
          )}
        </div>
      )}

      {s && <StudentFormDialog open={editOpen} onOpenChange={setEditOpen} student={s} />}
      {s && (
        <ConfirmDialog
          open={archiveOpen}
          onOpenChange={setArchiveOpen}
          title={s.archived ? t('students.restore') : t('students.archive')}
          description={s.archived ? undefined : t('students.archiveConfirm', { name: `${s.lastName} ${s.firstName}` })}
          destructive={!s.archived}
          loading={archive.isPending}
          onConfirm={async () => {
            await archive.mutateAsync({ id: s.id, archived: !s.archived });
            setArchiveOpen(false);
          }}
        />
      )}
    </>
  );
}

export default function StudentViewPage() {
  return (
    <Suspense>
      <StudentDetail />
    </Suspense>
  );
}
