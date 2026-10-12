'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import { DataTable, type Column, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { AttendanceBadge, LinkBadge } from '@/components/common/status-badges';
import { SearchInput } from '@/components/common/toolbar';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import type { StudentFilter, StudentRow } from '@/data/mock/services/students';
import { DeviceIcon } from '@/features/students/components/device-icon';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';
import { useClassStudents } from '../hooks';

const PAGE_SIZE = 10;

export function ClassStudentsCard({ classId }: { classId: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const [filter, setFilter] = useState<StudentFilter>({ classId, page: 1, limit: PAGE_SIZE, sortBy: 'name', sortDir: 'asc' });
  const students = useClassStudents(filter, Boolean(classId));

  const columns = useMemo<Column<StudentRow>[]>(
    () => [
      {
        key: 'name',
        header: t('students.columns.name'),
        sortKey: 'name',
        cell: (r) => (
          <div className="flex items-center gap-3">
            <Avatar className="h-8 w-8">
              <AvatarFallback
                className={cn('text-2xs font-semibold', r.gender === 'FEMALE' ? 'bg-pink-500/10 text-pink-600' : 'bg-primary/10 text-primary')}
              >
                {initials(`${r.lastName} ${r.firstName}`)}
              </AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <p className="truncate font-medium">
                {r.lastName} {r.firstName}
              </p>
              <p className="truncate text-xs text-muted-foreground">{r.studentCode}</p>
            </div>
          </div>
        ),
      },
      { key: 'link', header: t('students.columns.guardians'), sortKey: 'link', cell: (r) => <LinkBadge status={r.linkStatus} /> },
      { key: 'device', header: t('students.columns.device'), cell: (r) => <DeviceIcon device={r.device} /> },
      { key: 'today', header: t('students.columns.today'), cell: (r) => <AttendanceBadge status={r.todayStatus} /> },
    ],
    [t],
  );

  return (
    <SectionCard
      title={t('classes.view.students')}
      description={t('classes.view.studentsHint')}
      actions={
        <SearchInput
          value={filter.search ?? ''}
          onChange={(search) => setFilter((f) => ({ ...f, search, page: 1 }))}
          placeholder={t('students.searchPlaceholder')}
          className="sm:w-60"
        />
      }
      bodyClassName="p-0"
    >
      {students.isError ? (
        <ErrorState error={students.error} onRetry={() => void students.refetch()} />
      ) : (
        <DataTable
          className="rounded-none border-0"
          columns={columns}
          rows={students.data?.items}
          rowKey={(r) => r.id}
          loading={students.isLoading}
          skeletonRows={PAGE_SIZE}
          pagination={students.data?.pagination}
          onPageChange={(page) => setFilter((f) => ({ ...f, page }))}
          sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
          onSortChange={(sort: SortState) => setFilter((f) => ({ ...f, ...sort, page: 1 }))}
          onRowClick={(r) => router.push(`/students/view?id=${r.id}`)}
        />
      )}
    </SectionCard>
  );
}
