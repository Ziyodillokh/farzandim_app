'use client';

import { School, UserRoundSearch, Users } from 'lucide-react';
import { Suspense } from 'react';

import { useCan } from '@/auth/use-session';
import { PageHeader } from '@/components/common/page-header';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { AttentionList } from '@/features/development/components/attention-list';
import { ClassView } from '@/features/development/components/class-view';
import { DevPrivacyBanner, SchoolView } from '@/features/development/components/school-view';
import { useI18n } from '@/i18n';
import { useTabParam } from '@/lib/use-tab-param';

const PSYCH_TABS = ['school', 'classes', 'attention'] as const;
type PsychTab = (typeof PSYCH_TABS)[number];

function PsychologistView() {
  const { t } = useI18n();
  const [tab, setTab] = useTabParam<PsychTab>(PSYCH_TABS, 'school');
  return (
    <Tabs value={tab} onValueChange={(v) => setTab(v as PsychTab)}>
      <TabsList className="h-auto w-full flex-wrap justify-start sm:w-auto">
        <TabsTrigger value="school"><School />{t('development.tabs.school')}</TabsTrigger>
        <TabsTrigger value="classes"><Users />{t('development.tabs.classes')}</TabsTrigger>
        <TabsTrigger value="attention"><UserRoundSearch />{t('development.tabs.attention')}</TabsTrigger>
      </TabsList>
      <TabsContent value="school" className="mt-6"><SchoolView /></TabsContent>
      <TabsContent value="classes" className="mt-6"><ClassView psychologist /></TabsContent>
      <TabsContent value="attention" className="mt-6"><AttentionList /></TabsContent>
    </Tabs>
  );
}

function DevelopmentContent() {
  const can = useCan();
  if (can('assessments.manage')) return <PsychologistView />;
  if (can('development.individual')) return <ClassView psychologist={false} />;
  return (
    <div className="space-y-6">
      <DevPrivacyBanner />
      <SchoolView />
    </div>
  );
}

export default function DevelopmentPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('development.title')} subtitle={t('development.subtitle')} />
      <ScreeningDisclaimer variant="banner" withIq className="mb-6" />
      <Suspense fallback={<Skeleton className="h-96 w-full rounded-2xl" />}>
        <DevelopmentContent />
      </Suspense>
    </>
  );
}
