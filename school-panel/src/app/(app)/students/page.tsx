'use client';

import { FileUp, PhoneOff, Plus, UserCheck, Users } from 'lucide-react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { DataTable, type Column, type SortState } from '@/components/common/data-table';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { AttendanceBadge, LinkBadge } from '@/components/common/status-badges';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { api } from '@/data/api';
import type { DeviceOs, ParentLinkStatus } from '@/data/contracts';
import type { StudentFilter, StudentRow } from '@/data/mock/services/students';
import { DeviceIcon } from '@/features/students/components/device-icon';
import { ImportDialog } from '@/features/students/components/import-dialog';
import { StudentAvatar } from '@/features/students/components/student-avatar';
import { StudentFormDialog } from '@/features/students/components/student-form-dialog';
import { useClassOptions, useStudents } from '@/features/students/hooks';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';

/**
 * Chuqur havola: `/students?new=1&classId=cls-7a` — yaratish oynasi shu sinf bilan ochiladi
 * (`students.manage` bo'lsa), `classId` doiradagi sinf bo'lsa ro'yxat ham shu sinfga filtrlanadi.
 */
function useCreateDeepLink(
  classIds: readonly string[] | undefined,
  canCreate: boolean,
  onClass: (classId: string) => void,
): { open: boolean; classId: string | undefined; close: () => void } {
  const params = useSearchParams();
  const router = useRouter();
  const wantsNew = params.get('new') === '1';
  const requested = params.get('classId');
  const handled = useRef(false);
  const [state, setState] = useState<{ open: boolean; classId: string | undefined }>({ open: false, classId: undefined });

  useEffect(() => {
    if (handled.current || !classIds || (!wantsNew && !requested)) return;
    handled.current = true;
    const classId = requested && classIds.includes(requested) ? requested : undefined;
    if (classId) onClass(classId);
    if (wantsNew && canCreate) setState({ open: true, classId });
  }, [classIds, wantsNew, requested, canCreate, onClass]);

  const close = () => {
    setState({ open: false, classId: undefined });
    if (wantsNew) router.replace(state.classId ? `/students?classId=${state.classId}` : '/students', { scroll: false });
  };
  return { ...state, close };
}

function StudentsView() {
  const { t, formatDate, formatNumber } = useI18n();
  const router = useRouter();
  const [filter, setFilter] = useState<StudentFilter>({ page: 1, limit: 20, sortBy: 'name', sortDir: 'asc' });
  const [createOpen, setCreateOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const students = useStudents(filter);
  const classes = useClassOptions();
  const all = useStudents({ limit: 1 });
  const linked = useStudents({ limit: 1, linkStatus: 'LINKED' });
  const noPhone = useStudents({ limit: 1, device: 'NONE' });

  const can = useCan();
  const classIds = useMemo(() => classes.data?.map((c) => c.id), [classes.data]);
  const applyClass = useCallback((classId: string) => setFilter((f) => ({ ...f, page: 1, classId })), []);
  const deepLink = useCreateDeepLink(classIds, can('students.manage'), applyClass);
  // Psixolog: faqat ism va sinf (servis ham qolganini yashiradi).
  const minimal = !can('guardians.link');
  const update = (patch: Partial<StudentFilter>) => setFilter((f) => ({ ...f, page: 1, ...patch }));

  const columns = useMemo<Column<StudentRow>[]>(() => {
    const list: Column<StudentRow>[] = [
      {
        key: 'name',
        header: t('students.columns.name'),
        sortKey: 'name',
        cell: (r) => (
          <div className="flex items-center gap-3">
            <StudentAvatar name={`${r.lastName} ${r.firstName}`} gender={r.gender} />
            <div className="min-w-0">
              <div className="flex min-w-0 items-center gap-2">
                <span className="truncate font-medium">
                  {r.lastName} {r.firstName}
                </span>
                {r.archived && (
                  <Badge variant="secondary" size="sm">
                    {t('students.archivedBadge')}
                  </Badge>
                )}
              </div>
              <p className="truncate text-xs text-muted-foreground">
                {r.middleName} · <span className="font-mono">{r.studentCode}</span>
              </p>
            </div>
          </div>
        ),
      },
      { key: 'class', header: t('students.columns.class'), sortKey: 'class', cell: (r) => <Badge variant="outline">{r.className}</Badge> },
      {
        key: 'birth',
        header: t('students.columns.birthDate'),
        sortKey: 'birthDate',
        className: 'whitespace-nowrap text-muted-foreground',
        cell: (r) => formatDate(r.birthDate, 'dd.MM.yyyy'),
      },
      { key: 'link', header: t('students.columns.guardians'), sortKey: 'link', cell: (r) => <LinkBadge status={r.linkStatus} /> },
      { key: 'device', header: t('students.columns.device'), cell: (r) => <DeviceIcon device={r.device} /> },
      { key: 'today', header: t('students.columns.today'), cell: (r) => <AttendanceBadge status={r.todayStatus} /> },
    ];
    return minimal ? list.filter((c) => c.key === 'name' || c.key === 'class') : list;
  }, [t, formatDate, minimal]);

  const exportCsv = async () => {
    const rows = await api.students.exportRows(filter);
    downloadCsv(t('students.exportFile'), rows, [
      { header: t('students.fields.lastName'), value: (r) => r.lastName },
      { header: t('students.fields.firstName'), value: (r) => r.firstName },
      { header: t('students.fields.middleName'), value: (r) => r.middleName },
      { header: t('students.columns.class'), value: (r) => r.className },
      { header: t('students.columns.birthDate'), value: (r) => r.birthDate },
      { header: t('students.code'), value: (r) => r.studentCode },
      { header: t('students.columns.guardians'), value: (r) => r.guardianNames.join(', ') },
      { header: t('students.filters.link'), value: (r) => t(`enums.linkStatus.${r.linkStatus}`) },
      { header: t('students.columns.device'), value: (r) => t(`enums.device.${r.device}`) },
    ]);
  };

  const total = all.data?.pagination.total ?? 0;
  const linkedCount = linked.data?.pagination.total ?? 0;

  return (
    <>
      <PageHeader
        title={t('students.title')}
        subtitle={t('students.subtitle')}
        actions={
          <>
            {!minimal && <ExportMenu onCsv={exportCsv} />}
            <Can perm="students.manage">
              <Button variant="outline" onClick={() => setImportOpen(true)}>
                <FileUp />
                {t('common.import')}
              </Button>
              <Button onClick={() => setCreateOpen(true)}>
                <Plus />
                {t('students.add')}
              </Button>
            </Can>
          </>
        }
      />

      <div className={minimal ? 'hidden' : 'mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3'}>
        <StatCard icon={<Users />} label={t('students.stats.total')} value={formatNumber(total)} loading={all.isLoading} />
        <StatCard
          icon={<UserCheck />}
          tone="success"
          label={t('students.stats.linked')}
          value={`${total ? Math.round((linkedCount / total) * 100) : 0}%`}
          hint={`${formatNumber(linkedCount)} / ${formatNumber(total)}`}
          loading={linked.isLoading}
        />
        <StatCard
          icon={<PhoneOff />}
          tone="muted"
          label={t('students.stats.noPhone')}
          value={formatNumber(noPhone.data?.pagination.total ?? 0)}
          loading={noPhone.isLoading}
        />
      </div>

      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={(search) => update({ search })} placeholder={t('students.searchPlaceholder')} />
        <FilterSelect
          value={filter.classId}
          onChange={(classId) => update({ classId })}
          options={(classes.data ?? []).map((c) => ({ value: c.id, label: c.name }))}
          allLabel={`${t('students.filters.class')}: ${t('common.all')}`}
          className="sm:w-40"
        />
        {!minimal && (
          <>
            <FilterSelect
              value={filter.linkStatus}
              onChange={(v) => update({ linkStatus: v as ParentLinkStatus | undefined })}
              options={(['LINKED', 'INVITED', 'NOT_INVITED'] as const).map((s) => ({ value: s, label: t(`enums.linkStatus.${s}`) }))}
              allLabel={`${t('students.filters.link')}: ${t('common.all')}`}
              className="sm:w-56"
            />
            <FilterSelect
              value={filter.device}
              onChange={(v) => update({ device: v as DeviceOs | undefined })}
              options={(['IOS', 'ANDROID', 'NONE'] as const).map((d) => ({ value: d, label: t(`enums.device.${d}`) }))}
              allLabel={`${t('students.filters.device')}: ${t('common.all')}`}
            />
          </>
        )}
      </Toolbar>

      <DataTable
        columns={columns}
        rows={students.data?.items}
        rowKey={(r) => r.id}
        loading={students.isLoading}
        pagination={students.data?.pagination}
        onPageChange={(page) => setFilter((f) => ({ ...f, page }))}
        sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
        onSortChange={(sort: SortState) => setFilter((f) => ({ ...f, ...sort, page: 1 }))}
        onRowClick={(r) => router.push(`/students/view?id=${r.id}`)}
      />

      <StudentFormDialog
        open={createOpen || deepLink.open}
        onOpenChange={(open) => {
          setCreateOpen(open);
          if (!open && deepLink.open) deepLink.close();
        }}
        defaultClassId={deepLink.classId ?? filter.classId}
      />
      <ImportDialog open={importOpen} onOpenChange={setImportOpen} />
    </>
  );
}

export default function StudentsPage() {
  return (
    <Suspense fallback={<Skeleton className="h-[600px] w-full rounded-2xl" />}>
      <StudentsView />
    </Suspense>
  );
}
