'use client';

import { UsersRound } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import { DataTable, type Column, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { AttendanceBadge, LinkBadge } from '@/components/common/status-badges';
import { SearchInput } from '@/components/common/toolbar';
import type { StudentFilter, StudentRow } from '@/data/mock/services/students';
import { DeviceIcon } from '@/features/students/components/device-icon';
import { StudentAvatar } from '@/features/students/components/student-avatar';
import { useI18n } from '@/i18n';
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
            <StudentAvatar name={`${r.lastName} ${r.firstName}`} gender={r.gender} size="sm" />
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
      icon={<UsersRound />}
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
