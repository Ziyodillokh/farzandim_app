'use client';

/**
 * Parvoz maktablari: yangi maktab va direktorini ochish, direktor / psixolog
 * hisoblari va parolni tiklash. Qolganini (sinflar, o'quvchilar, xodimlar)
 * direktor maktab panelida o'zi to'ldiradi.
 */

import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Plus, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { PageHeader } from '@/components/common/page-header';
import { useDebouncedValue } from '@/components/kelajak/use-debounced-value';
import { CredentialsDialog, type ShownCredentials } from '@/components/schools/credentials-dialog';
import { SchoolCreateDialog } from '@/components/schools/school-create-dialog';
import { SchoolSheet } from '@/components/schools/school-sheet';
import { SchoolsTable } from '@/components/schools/schools-table';
import { schoolsKeys } from '@/components/schools/schools-keys';
import { schoolsApi } from '@/lib/api/admin.api';
import type { AdminSchool } from '@/types/api.types';

const PAGE_LIMIT = 20;
const SEARCH_DEBOUNCE_MS = 350;

export default function SchoolsPage() {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [createOpen, setCreateOpen] = useState(false);
  const [selected, setSelected] = useState<AdminSchool | null>(null);
  const [credentials, setCredentials] = useState<ShownCredentials | null>(null);

  const q = useDebouncedValue(search.trim(), SEARCH_DEBOUNCE_MS);
  const params = { q: q || undefined, page, limit: PAGE_LIMIT };
  const list = useQuery({
    queryKey: schoolsKeys.list(params),
    queryFn: () => schoolsApi.list(params),
    placeholderData: (prev) => prev,
  });

  const totalPages = list.data?.totalPages;
  useEffect(() => {
    if (totalPages !== undefined && page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  return (
    <div className="container mx-auto max-w-screen-2xl px-4 py-6 sm:px-6 sm:py-8">
      <PageHeader
        eyebrow="Parvoz maktab paneli"
        title="Maktablar"
        count={list.data?.total}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" /> Yangi maktab
          </Button>
        }
      />

      <div className="mb-4 max-w-md">
        <Input
          icon={<Search />}
          value={search}
          placeholder="Nom, kod yoki shahar bo'yicha qidirish"
          aria-label="Maktablarni qidirish"
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
      </div>

      <SchoolsTable
        data={list.data}
        isLoading={list.isLoading}
        isFetching={list.isFetching}
        error={list.error}
        limit={PAGE_LIMIT}
        onPageChange={setPage}
        onOpen={setSelected}
      />

      <SchoolCreateDialog open={createOpen} onOpenChange={setCreateOpen} onCreated={setCredentials} />
      <SchoolSheet school={selected} onOpenChange={(v) => !v && setSelected(null)} onCredentials={setCredentials} />
      <CredentialsDialog credentials={credentials} onClose={() => setCredentials(null)} />
    </div>
  );
}
