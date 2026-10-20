'use client';

import { CalendarDays, History, NotebookPen, Sprout, UserRound, type LucideIcon } from 'lucide-react';
import { useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useMemo, useRef } from 'react';

import { useCan } from '@/auth/use-session';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { DevelopmentTab } from '@/features/development/components/development-tab';
import { StudentAvatar } from '@/features/students/components/student-avatar';
import { StudentHeaderActions } from '@/features/students/components/student-header-actions';
import { StudentHistory } from '@/features/students/components/student-history';
import { StudentNotes } from '@/features/students/components/student-notes';
import { AttendancePanel, ProfilePanel } from '@/features/students/components/student-tab-panels';
import { useStudent } from '@/features/students/hooks';
import { type StudentTab, visibleStudentTabs } from '@/features/students/student-tabs';
import { useI18n } from '@/i18n';
import { useTabParam } from '@/lib/use-tab-param';

const TAB_ICONS: Record<StudentTab, LucideIcon> = {
  profile: UserRound,
  attendance: CalendarDays,
  development: Sprout,
  history: History,
  notes: NotebookPen,
};

function DetailSkeleton() {
  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <Skeleton className="h-64 rounded-2xl lg:col-span-2" />
      <Skeleton className="h-64 rounded-2xl" />
    </div>
  );
}

/** O'quvchi 360° kartasi: `?id=&tab=profile|attendance|development|history|notes` (tablar rol bo'yicha). */
function StudentDetailView() {
  const { t } = useI18n();
  const can = useCan();
  const id = useSearchParams().get('id');
  const student = useStudent(id);
  const tabs = useMemo(() => visibleStudentTabs(can), [can]);
  const [tab, setTab] = useTabParam<StudentTab>(tabs, 'profile');
  // Ota-onaga ulash huquqi yo'q rol (psixolog) — faqat ism va sinf.
  const minimal = !can('guardians.link');
  // Telefonda tablar gorizontal aylanadi — faol tab ko'rinib tursin.
  const tabStrip = useRef<HTMLDivElement>(null);
  const loaded = Boolean(student.data);
  useEffect(() => {
    tabStrip.current?.querySelector<HTMLElement>('[data-state="active"]')?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  }, [tab, loaded]);

  if (!id || student.isError) {
    return (
      <>
        <PageHeader backHref="/students" backLabel={t('students.title')} title={t('students.title')} />
        <Card>
          {id ? <ErrorState error={student.error} onRetry={() => void student.refetch()} /> : <EmptyState icon={<UserRound />} title={t('students.detail.notFound')} />}
        </Card>
      </>
    );
  }
  const s = student.data;

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
        actions={s && <StudentHeaderActions student={s} />}
      />

      {!s ? (
        <DetailSkeleton />
      ) : (
        <Tabs value={tab} onValueChange={(next) => setTab(next as StudentTab)}>
          {tabs.length > 1 && (
            <div ref={tabStrip} className="-mx-4 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
              <TabsList aria-label={t('students.tabs.label')}>
                {tabs.map((key) => {
                  const Icon = TAB_ICONS[key];
                  return (
                    <TabsTrigger key={key} value={key}>
                      <Icon aria-hidden />
                      {t(`students.tabs.${key}`)}
                    </TabsTrigger>
                  );
                })}
              </TabsList>
            </div>
          )}
          <TabsContent value="profile">
            <ProfilePanel student={s} minimal={minimal} />
          </TabsContent>
          {tabs.includes('attendance') && (
            <TabsContent value="attendance">
              <AttendancePanel student={s} />
            </TabsContent>
          )}
          {tabs.includes('development') && (
            <TabsContent value="development">
              <DevelopmentTab studentId={s.id} />
            </TabsContent>
          )}
          {tabs.includes('history') && (
            <TabsContent value="history">
              <StudentHistory studentId={s.id} />
            </TabsContent>
          )}
          {tabs.includes('notes') && (
            <TabsContent value="notes">
              <StudentNotes studentId={s.id} />
            </TabsContent>
          )}
        </Tabs>
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
