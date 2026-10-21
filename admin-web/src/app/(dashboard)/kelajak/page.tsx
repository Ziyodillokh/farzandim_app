'use client';

/**
 * Parvoz Kelajak — savollar banki (docs/KELAJAK-REJA.md §6, §7).
 * O'chirish yo'q: nofaol qilish yumshoq o'chirish o'rnini bosadi.
 */

import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { PageHeader } from '@/components/common/page-header';
import { kelajakApi } from '@/lib/api/admin.api';
import type { KelajakQuestion } from '@/types/api.types';
import { KelajakStatsCards } from '@/components/kelajak/kelajak-stats';
import {
  EMPTY_FILTERS,
  KelajakFilters,
  toListParams,
  type KelajakFilterValues,
} from '@/components/kelajak/kelajak-filters';
import { KelajakTable } from '@/components/kelajak/kelajak-table';
import { QuestionEditDialog } from '@/components/kelajak/question-edit-dialog';
import { QuestionCreateDialog } from '@/components/kelajak/question-create-dialog';
import { kelajakKeys } from '@/components/kelajak/kelajak-keys';
import { useDebouncedValue } from '@/components/kelajak/use-debounced-value';
import { kelajakErrorMessage } from '@/components/kelajak/kelajak-errors';

const PAGE_LIMIT = 20;
const SEARCH_DEBOUNCE_MS = 350;

export default function KelajakQuestionsPage() {
  const [filters, setFilters] = useState<KelajakFilterValues>(EMPTY_FILTERS);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  // `null` — oyna yopiq; aks holda qaysi savol ochilgan.
  const [selected, setSelected] = useState<KelajakQuestion | null>(null);
  const [createOpen, setCreateOpen] = useState(false);

  const q = useDebouncedValue(search.trim(), SEARCH_DEBOUNCE_MS);
  const params = toListParams(filters, q, page, PAGE_LIMIT);

  const list = useQuery({
    queryKey: kelajakKeys.list(params),
    queryFn: () => kelajakApi.list(params),
    placeholderData: (prev) => prev,
  });

  const stats = useQuery({
    queryKey: kelajakKeys.stats,
    queryFn: () => kelajakApi.stats(),
  });

  // Oxirgi sahifadagi oxirgi savol filtrdan chiqib ketsa (masalan, nofaol qilinsa) — mavjud sahifaga qaytamiz.
  const totalPages = list.data?.totalPages;
  useEffect(() => {
    if (totalPages !== undefined && page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  const changeFilter = <K extends keyof KelajakFilterValues>(key: K, value: KelajakFilterValues[K]) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    setPage(1);
  };

  const changeSearch = (value: string) => {
    setSearch(value);
    setPage(1);
  };

  const resetFilters = () => {
    setFilters(EMPTY_FILTERS);
    setSearch('');
    setPage(1);
  };

  return (
    <div className="container mx-auto max-w-screen-2xl px-4 py-6 sm:px-6 sm:py-8">
      <PageHeader
        eyebrow="Parvoz Kelajak savollar banki"
        title="Kelajak savollari"
        count={list.data?.total}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" /> Yangi savol
          </Button>
        }
      />

      <KelajakStatsCards
        stats={stats.data}
        isLoading={stats.isLoading}
        error={stats.isError ? kelajakErrorMessage(stats.error) : null}
      />

      <KelajakFilters
        values={filters}
        onChange={changeFilter}
        search={search}
        onSearchChange={changeSearch}
        onReset={resetFilters}
      />

      <KelajakTable
        data={list.data}
        isLoading={list.isLoading}
        isFetching={list.isFetching}
        error={list.error}
        limit={PAGE_LIMIT}
        onPageChange={setPage}
        onOpen={setSelected}
      />

      <QuestionEditDialog question={selected} onOpenChange={(v) => !v && setSelected(null)} />

      <QuestionCreateDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        defaults={{ category: filters.category, ageGroup: filters.ageGroup }}
      />
    </div>
  );
}
