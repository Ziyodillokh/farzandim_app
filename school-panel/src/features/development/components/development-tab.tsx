'use client';

import { Activity, Briefcase, ClipboardList, Compass, LineChart as LineIcon, Radar, ShieldCheck, Sprout } from 'lucide-react';
import Link from 'next/link';

import { useCan } from '@/auth/use-session';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { StudentDevProfile } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useDevClassOptions, useDevProfile } from '../hooks';
import { CareerBars, careerTitleCodes } from './career-bars';
import { ContextCard } from './context-card';
import { DomainCards } from './domain-cards';
import { DomainRadar } from './domain-radar';
import { ResultsTable } from './results-table';
import { ScoreTimeline } from './score-timeline';

const MIN_GRADE = 3;
const CAREER_MIN_GRADE = 8;

function TabSkeleton() {
  return (
    <div className="grid gap-6 xl:grid-cols-5">
      <Skeleton className="h-80 rounded-2xl xl:col-span-2" />
      <Skeleton className="h-80 rounded-2xl xl:col-span-3" />
      <Skeleton className="h-64 rounded-2xl xl:col-span-5" />
    </div>
  );
}

/** Natija yo'q: 1–2-sinf — "3-sinfdan boshlab"; psixologga — test tayinlash tugmasi. */
function NoResults({ profile }: { profile: StudentDevProfile }) {
  const { t } = useI18n();
  const can = useCan();
  const manage = can('assessments.manage');
  const classes = useDevClassOptions(manage);
  const classId = classes.data?.find((c) => c.name === profile.student.className)?.id;
  if (profile.student.grade < MIN_GRADE) {
    return (
      <Card>
        <EmptyState icon={<Sprout />} title={t('development.empty.fromGrade3')} description={t('development.empty.fromGrade3Hint')} />
      </Card>
    );
  }
  return (
    <Card>
      <EmptyState
        icon={<ClipboardList />}
        title={t('development.empty.noResults')}
        description={t('development.empty.noResultsHint')}
        action={
          manage && classId ? (
            <Button asChild>
              <Link href={`/assessments?assign=tpl-logic&classId=${classId}`}>{t('development.empty.assignCta')}</Link>
            </Button>
          ) : undefined
        }
      />
    </Card>
  );
}

function Profile({ profile }: { profile: StudentDevProfile }) {
  const { t } = useI18n();
  const career = profile.student.grade >= CAREER_MIN_GRADE ? profile.career : null;
  const hasContext = Boolean(profile.context.attendance30 || profile.context.classLearning);
  return (
    <div className="space-y-6">
      <ScreeningDisclaimer variant="inline" withIq />
      <div className="grid items-start gap-6 xl:grid-cols-5">
        <div className="space-y-6 xl:col-span-2">
          <SectionCard title={t('development.profile.radarTitle')} description={t('development.profile.radarHint')} icon={<Radar />}>
            <DomainRadar latest={profile.latest} classAverage={profile.classAverage} />
          </SectionCard>
          {hasContext && (
            <SectionCard title={t('development.profile.contextTitle')} icon={<Activity />}>
              <ContextCard context={profile.context} />
            </SectionCard>
          )}
        </div>
        <SectionCard className="xl:col-span-3" title={t('development.profile.domainsTitle')} description={t('development.profile.domainsHint')} icon={<Compass />}>
          <DomainCards profile={profile} />
        </SectionCard>
      </div>
      {(profile.timeline.length > 0 || career) && (
        <div className="grid items-start gap-6 xl:grid-cols-5">
          {profile.timeline.length > 0 && (
            <SectionCard className={career ? 'xl:col-span-3' : 'xl:col-span-5'} title={t('development.profile.timelineTitle')} description={t('development.profile.timelineHint')} icon={<LineIcon />}>
              <ScoreTimeline timeline={profile.timeline} />
            </SectionCard>
          )}
          {career && (
            <SectionCard className="xl:col-span-2" title={t('development.profile.careerTitle')} description={t('development.profile.careerHint', { codes: careerTitleCodes(career, t) })} icon={<Briefcase />}>
              <CareerBars career={career} />
            </SectionCard>
          )}
        </div>
      )}
      {profile.canSeeRaw ? (
        <SectionCard title={t('development.profile.resultsTitle')} description={t('development.profile.resultsHint')} icon={<ClipboardList />}>
          <ResultsTable results={profile.results} />
        </SectionCard>
      ) : (
        <p className="flex items-center gap-2 text-xs text-muted-foreground">
          <ShieldCheck className="h-3.5 w-3.5 shrink-0" />
          {t('development.profile.protectedNote')}
        </p>
      )}
    </div>
  );
}

/** O'quvchi kartasidagi "Rivojlanish" tabi (psixolog va o'z sinfi uchun sinf rahbari). */
export function DevelopmentTab({ studentId }: { studentId: string }) {
  const profile = useDevProfile(studentId);
  if (profile.error) {
    return (
      <Card>
        <ErrorState error={profile.error} onRetry={() => void profile.refetch()} />
      </Card>
    );
  }
  if (!profile.data) return <TabSkeleton />;
  return profile.data.results.length === 0 ? <NoResults profile={profile.data} /> : <Profile profile={profile.data} />;
}
