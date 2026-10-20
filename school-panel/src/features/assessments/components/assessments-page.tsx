'use client';

import { BarChart3, LibraryBig, Send } from 'lucide-react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useMemo, useState } from 'react';

import { PageHeader } from '@/components/common/page-header';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useI18n } from '@/i18n';
import { useTabParam } from '@/lib/use-tab-param';
import { useTests } from '../hooks';
import { AssignDialog } from './assign-dialog';
import { AssignmentsTab } from './assignments-tab';
import { LibraryTab } from './library-tab';
import { ResultsPanel } from './results-panel';

const TABS = ['library', 'assignments', 'results'] as const;
type Tab = (typeof TABS)[number];

/** URL parametrlarini almashtirish (`?test=`, `?assign=`), qolganlari saqlanadi. */
function useQueryParam(key: string): [string | undefined, (value: string | undefined, extra?: Record<string, string | undefined>) => void] {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const value = params.get(key) ?? undefined;
  const set = useCallback(
    (next: string | undefined, extra: Record<string, string | undefined> = {}) => {
      const q = new URLSearchParams(params.toString());
      for (const [k, v] of Object.entries({ [key]: next, ...extra })) {
        if (v) q.set(k, v);
        else q.delete(k);
      }
      const qs = q.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [key, params, pathname, router],
  );
  return [value, set];
}

export function AssessmentsPage() {
  const { t } = useI18n();
  const [tab, setTab] = useTabParam(TABS, 'library');
  const [testParam, setTestParam] = useQueryParam('test');
  const [assignParam, setAssignParam] = useQueryParam('assign');
  const classParam = useSearchParams().get('classId') ?? undefined;
  const [manualAssign, setManualAssign] = useState(false);
  const tests = useTests();

  /** Natijalar: URL'dagi test, bo'lmasa natijasi bor birinchi test. */
  const resultsTestId = useMemo(() => testParam ?? tests.data?.find((x) => x.resultsCount > 0)?.id, [testParam, tests.data]);
  const assignOpen = manualAssign || Boolean(assignParam);

  const closeAssign = (open: boolean) => {
    if (open) return;
    setManualAssign(false);
    if (assignParam) setAssignParam(undefined, { classId: undefined });
  };

  return (
    <>
      <PageHeader title={t('assessments.title')} subtitle={t('assessments.subtitle')} />
      <Tabs value={tab} onValueChange={(v) => setTab(v as Tab)}>
        <TabsList className="h-auto flex-wrap">
          <TabsTrigger value="library">
            <LibraryBig />
            {t('assessments.tabs.library')}
          </TabsTrigger>
          <TabsTrigger value="assignments">
            <Send />
            {t('assessments.tabs.assignments')}
          </TabsTrigger>
          <TabsTrigger value="results">
            <BarChart3 />
            {t('assessments.tabs.results')}
          </TabsTrigger>
        </TabsList>
        <TabsContent value="library" className="animate-fade-in">
          <LibraryTab onAssign={(id) => setAssignParam(id)} />
        </TabsContent>
        <TabsContent value="assignments" className="animate-fade-in">
          <AssignmentsTab onAssign={() => setManualAssign(true)} />
        </TabsContent>
        <TabsContent value="results" className="animate-fade-in">
          <ResultsPanel testId={resultsTestId} onTestChange={(id) => setTestParam(id)} />
        </TabsContent>
      </Tabs>
      <AssignDialog open={assignOpen} onOpenChange={closeAssign} testId={assignParam} classId={classParam} />
    </>
  );
}
