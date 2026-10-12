'use client';

import { BarChart3, FileQuestion, ListChecks, Ruler, Smartphone, SquareStack } from 'lucide-react';
import { useSearchParams } from 'next/navigation';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useI18n } from '@/i18n';
import { useTabParam } from '@/lib/use-tab-param';
import { useTest } from '../../hooks';
import { gradesLabel } from '../../lib/labels';
import { ResultsPanel } from '../results-panel';
import { KindIcon, SourceBadge, StatusBadge } from '../test-badges';
import { ItemsList } from './items-list';
import { NormsTable } from './norms-table';
import { OverviewPanel } from './overview-panel';
import { PreviewPanel } from './preview-panel';
import { TestActions } from './test-actions';
import { TestBuilder } from './test-builder';

const TABS = ['overview', 'items', 'norms', 'results', 'preview'] as const;
type Tab = (typeof TABS)[number];

const ICONS: Record<Tab, typeof ListChecks> = { overview: SquareStack, items: ListChecks, norms: Ruler, results: BarChart3, preview: Smartphone };

/** Test sahifasi: umumiy, savollar (konstruktor), me'yorlar, natijalar, ilova ko'rinishi. */
export function TestView() {
  const { t, tc, locale } = useI18n();
  const id = useSearchParams().get('id');
  const [tab, setTab] = useTabParam(TABS, 'overview');
  const query = useTest(id);
  const test = query.data;

  if (!id || query.isError) {
    return (
      <>
        <PageHeader backHref="/assessments" backLabel={t('assessments.title')} title={t('assessments.title')} />
        <Card>
          {id ? <ErrorState error={query.error} onRetry={() => void query.refetch()} /> : <EmptyState icon={<FileQuestion />} title={t('assessments.view.notFound')} />}
        </Card>
      </>
    );
  }

  const editable = test && !test.readOnly;
  const cognitive = test?.kind === 'COGNITIVE';

  return (
    <>
      <PageHeader
        backHref="/assessments"
        backLabel={t('assessments.title')}
        title={
          test ? (
            <span className="flex items-center gap-3">
              <KindIcon kind={test.kind} className="h-11 w-11" />
              <span>{test.title[locale]}</span>
            </span>
          ) : (
            <Skeleton className="h-10 w-72" />
          )
        }
        subtitle={
          test &&
          [cognitive ? t('assessments.view.cognitiveTitle') : t(`enums.psychKind.${test.kind}`), gradesLabel(t, test.grades), tc('assessments.itemsCount', test.itemCount)].join(' · ')
        }
        badge={
          test && (
            <div className="flex flex-wrap items-center gap-1.5">
              <SourceBadge source={test.source} />
              <StatusBadge status={test.status} />
              <Badge variant="outline" size="sm">
                {t('assessments.view.version', { version: test.version })}
              </Badge>
            </div>
          )
        }
        actions={test && <TestActions test={test} />}
      />

      {cognitive && <ScreeningDisclaimer variant="banner" withIq className="mb-6" />}

      {!test ? (
        <Skeleton className="h-96 rounded-2xl" />
      ) : (
        <Tabs value={tab} onValueChange={(v) => setTab(v as Tab)}>
          <div className="-mx-1 overflow-x-auto px-1 pb-1">
            <TabsList>
              {TABS.map((key) => {
                const Icon = ICONS[key];
                return (
                  <TabsTrigger key={key} value={key}>
                    <Icon />
                    {t(`assessments.view.tabs.${key}`)}
                  </TabsTrigger>
                );
              })}
            </TabsList>
          </div>
          <TabsContent value="overview" className="animate-fade-in">
            <OverviewPanel test={test} />
          </TabsContent>
          <TabsContent value="items" className="animate-fade-in">
            {editable ? <TestBuilder test={test} /> : <ItemsList test={test} />}
          </TabsContent>
          <TabsContent value="norms" className="animate-fade-in">
            <NormsTable test={test} />
          </TabsContent>
          <TabsContent value="results" className="animate-fade-in">
            <ResultsPanel testId={test.id} showDisclaimer={!cognitive} />
          </TabsContent>
          <TabsContent value="preview" className="animate-fade-in">
            <PreviewPanel test={test} />
          </TabsContent>
        </Tabs>
      )}
    </>
  );
}
