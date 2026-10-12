'use client';

import { Archive, ArchiveRestore, CalendarDays, Pencil, UserRound } from 'lucide-react';
import { useSearchParams } from 'next/navigation';
import { Suspense, useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { clockToday } from '@/data/mock/clock';
import { AttendanceCalendar } from '@/features/students/components/attendance-calendar';
import { GuardiansCard } from '@/features/students/components/guardians-card';
import { StudentAvatar } from '@/features/students/components/student-avatar';
import { StudentFormDialog } from '@/features/students/components/student-form-dialog';
import { StudentProfileCard } from '@/features/students/components/student-profile-card';
import { PsychologistNote, StudentModeCard, StudentPrivacyNote, StudentTodayCard } from '@/features/students/components/student-side-cards';
import { useArchiveStudent, useStudent } from '@/features/students/hooks';
import { useI18n } from '@/i18n';

function DetailSkeleton() {
  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <Skeleton className="h-64 rounded-2xl lg:col-span-2" />
      <Skeleton className="h-64 rounded-2xl" />
    </div>
  );
}

function StudentDetailView() {
  const { t } = useI18n();
  const can = useCan();
  const id = useSearchParams().get('id');
  const student = useStudent(id);
  const archive = useArchiveStudent();
  const [editOpen, setEditOpen] = useState(false);
  const [archiveOpen, setArchiveOpen] = useState(false);
  // Ota-onaga ulash huquqi yo'q rol (psixolog) — faqat ism va sinf.
  const psychologist = !can('guardians.link');

  if (!id || student.isError) {
    return (
      <>
        <PageHeader backHref="/students" backLabel={t('students.title')} title={t('students.title')} />
        <Card>
          {id ? (
            <ErrorState error={student.error} onRetry={() => void student.refetch()} />
          ) : (
            <EmptyState icon={<UserRound />} title={t('students.detail.notFound')} />
          )}
        </Card>
      </>
    );
  }
  const s = student.data;

  const toggleArchive = async () => {
    if (!s) return;
    try {
      await archive.mutateAsync({ id: s.id, archived: !s.archived });
      setArchiveOpen(false);
    } catch {
      // toast — hooks ichida
    }
  };

  return (
    <>
      <PageHeader
        backHref="/students"
        backLabel={t('students.title')}
        title={
          s ? (
            <span className="flex items-center gap-4">
              <StudentAvatar name={`${s.lastName} ${s.firstName}`} gender={s.gender} size="lg" />
              <span>
                {s.lastName} {s.firstName}
                <span className="mt-1.5 block font-sans text-sm font-normal tracking-normal text-muted-foreground">{s.middleName}</span>
              </span>
            </span>
          ) : (
            <Skeleton className="h-12 w-72" />
          )
        }
        badge={
          s && (
            <div className="flex flex-wrap gap-2">
              <Badge>{s.className}</Badge>
              <Badge variant="outline" className="font-mono">
                {s.studentCode}
              </Badge>
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

      {psychologist && <PsychologistNote />}

      {!s ? (
        <DetailSkeleton />
      ) : (
        <div className="grid items-start gap-6 lg:grid-cols-3">
          <div className={psychologist ? 'min-w-0 space-y-6 lg:col-span-3 xl:col-span-2' : 'min-w-0 space-y-6 lg:col-span-2'}>
            <StudentProfileCard student={s} minimal={psychologist} />
            {!psychologist && <GuardiansCard studentId={s.id} guardians={s.guardians} />}
            {!psychologist && (
              <SectionCard icon={<CalendarDays />} title={t('students.detail.calendar')}>
                <AttendanceCalendar studentId={s.id} initialMonth={clockToday().slice(0, 7)} />
              </SectionCard>
            )}
          </div>
          {!psychologist && (
            <div className="space-y-6">
              <StudentTodayCard student={s} />
              <StudentModeCard student={s} />
              <StudentPrivacyNote />
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
          onConfirm={() => void toggleArchive()}
        />
      )}
    </>
  );
}

export default function StudentViewPage() {
  return (
    <Suspense fallback={<DetailSkeleton />}>
      <StudentDetailView />
    </Suspense>
  );
}
