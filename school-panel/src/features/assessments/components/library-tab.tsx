'use client';

import { FileJson, FlaskConical, Plus, SearchX } from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { PsychTestKind } from '@/data/contracts';
import type { PsychTestRow } from '@/data/mock/services/assessments';
import { PSYCH_KINDS } from '@/data/schemas/assessments';
import { useI18n } from '@/i18n';
import { useDuplicateTest, useExportTest, useTests } from '../hooks';
import { JsonImportDialog } from './json-import-dialog';
import { NewTestDialog } from './new-test-dialog';
import { TestCard } from './test-card';

function Section({ title, hint, count, children }: { title: string; hint: string; count: number; children: ReactNode }) {
  return (
    <section className="space-y-3">
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <h2 className="font-display text-lg font-semibold tracking-[-0.01em]">
          {title} <span className="ml-1 text-sm font-medium tabular-nums text-muted-foreground">{count}</span>
        </h2>
        <p className="text-sm text-muted-foreground">{hint}</p>
      </div>
      {children}
    </section>
  );
}

const GRID = 'grid gap-4 sm:grid-cols-2 xl:grid-cols-3';

/** Testlar kutubxonasi: shablonlar va maktabning o'z testlari. */
export function LibraryTab({ onAssign }: { onAssign: (testId: string) => void }) {
  const { t } = useI18n();
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState<PsychTestKind | undefined>();
  const [newOpen, setNewOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const tests = useTests({ kind, search: search || undefined });
  const duplicate = useDuplicateTest();
  const exportTest = useExportTest();

  const rows = tests.data ?? [];
  const templates = rows.filter((x) => x.source === 'TEMPLATE');
  const own = rows.filter((x) => x.source !== 'TEMPLATE');
  const filtered = Boolean(search || kind);

  const card = (x: PsychTestRow) => (
    <TestCard key={x.id} test={x} onAssign={(test) => onAssign(test.id)} onDuplicate={(id) => duplicate.mutate(id)} onExport={(id) => exportTest.mutate(id)} />
  );

  const body = () => {
    if (tests.error) return <ErrorState error={tests.error} onRetry={() => void tests.refetch()} />;
    if (tests.isLoading) {
      return (
        <div className={GRID}>
          {Array.from({ length: 6 }, (_, i) => (
            <Skeleton key={i} className="h-64 rounded-2xl" />
          ))}
        </div>
      );
    }
    if (rows.length === 0) {
      return (
        <Card>
          <EmptyState icon={<SearchX />} title={t('assessments.library.empty')} description={t('assessments.library.emptyHint')} />
        </Card>
      );
    }
    return (
      <div className="space-y-8">
        {templates.length > 0 && (
          <Section title={t('assessments.library.templates')} hint={t('assessments.library.templatesHint')} count={templates.length}>
            <div className={GRID}>{templates.map(card)}</div>
          </Section>
        )}
        {(own.length > 0 || !filtered) && (
          <Section title={t('assessments.library.own')} hint={t('assessments.library.ownHint')} count={own.length}>
            {own.length > 0 ? (
              <div className={GRID}>{own.map(card)}</div>
            ) : (
              <Card>
                <EmptyState
                  icon={<FlaskConical />}
                  title={t('assessments.library.ownEmpty')}
                  description={t('assessments.library.ownEmptyHint')}
                  action={
                    <Button variant="soft" onClick={() => setNewOpen(true)}>
                      <Plus />
                      {t('assessments.library.newTest')}
                    </Button>
                  }
                />
              </Card>
            )}
          </Section>
        )}
      </div>
    );
  };

  return (
    <>
      <Toolbar>
        <SearchInput value={search} onChange={setSearch} placeholder={t('assessments.library.search')} />
        <FilterSelect
          value={kind}
          onChange={(v) => setKind(v as PsychTestKind | undefined)}
          options={PSYCH_KINDS.map((k) => ({ value: k, label: t(`enums.psychKind.${k}`) }))}
          allLabel={`${t('assessments.library.kindFilter')}: ${t('common.all')}`}
          className="sm:w-60"
        />
        <div className="flex w-full gap-2 sm:ml-auto sm:w-auto">
          <Button variant="outline" className="flex-1 sm:flex-none" onClick={() => setImportOpen(true)}>
            <FileJson />
            {t('assessments.library.importJson')}
          </Button>
          <Button className="flex-1 sm:flex-none" onClick={() => setNewOpen(true)}>
            <Plus />
            {t('assessments.library.newTest')}
          </Button>
        </div>
      </Toolbar>
      {body()}
      <NewTestDialog open={newOpen} onOpenChange={setNewOpen} />
      <JsonImportDialog open={importOpen} onOpenChange={setImportOpen} />
    </>
  );
}
