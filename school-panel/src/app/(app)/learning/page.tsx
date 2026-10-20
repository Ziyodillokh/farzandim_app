'use client';

import { BarChart3, BookOpen, ClipboardList, Info } from 'lucide-react';
import { useState } from 'react';

import { useSession } from '@/auth/use-session';
import { PageHeader } from '@/components/common/page-header';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { ActivityTab } from '@/features/learning/components/activity-tab';
import { AssignmentsTab } from '@/features/learning/components/assignments-tab';
import { MaterialsTab } from '@/features/learning/components/materials-tab';
import { useI18n } from '@/i18n';

type Tab = 'activity' | 'materials' | 'assignments';

export default function LearningPage() {
  const { t } = useI18n();
  const session = useSession();
  const [tab, setTab] = useState<Tab>('activity');
  const ownClass = session?.role === 'HOMEROOM';

  return (
    <>
      <PageHeader
        title={t('learning.title')}
        subtitle={t('learning.subtitle')}
        badge={ownClass && <Badge variant="info">{t('learning.scopeNote')}</Badge>}
      />
      <Card className="mb-5 flex items-center gap-3 px-4 py-3 text-sm text-foreground/80">
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
          <Info className="h-4 w-4" />
        </span>
        {t('learning.privacyNote')}
      </Card>
      <Tabs value={tab} onValueChange={(v) => setTab(v as Tab)}>
        <TabsList>
          <TabsTrigger value="activity">
            <BarChart3 />
            {t('learning.tabs.activity')}
          </TabsTrigger>
          <TabsTrigger value="materials">
            <BookOpen />
            {t('learning.tabs.materials')}
          </TabsTrigger>
          <TabsTrigger value="assignments">
            <ClipboardList />
            {t('learning.tabs.assignments')}
          </TabsTrigger>
        </TabsList>
        <TabsContent value="activity" className="animate-fade-in">
          <ActivityTab />
        </TabsContent>
        <TabsContent value="materials" className="animate-fade-in">
          <MaterialsTab />
        </TabsContent>
        <TabsContent value="assignments" className="animate-fade-in">
          <AssignmentsTab />
        </TabsContent>
      </Tabs>
    </>
  );
}
