'use client';

import { Check, Info, Minus, ShieldCheck } from 'lucide-react';
import { Fragment, useMemo } from 'react';

import { PERMISSIONS, type Permission } from '@/auth/permissions';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import type { RoleKey } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import { INNER_TILE } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import type { staff as staffDict } from '@/i18n/uz/staff';
import { cn } from '@/lib/utils';
import { useRoles, useStaffList } from '../hooks';
import { RoleCard } from './role-card';
import { ROLE_DOT } from './role-badge';

type ModuleKey = keyof typeof staffDict.modules;
type Group = { module: ModuleKey; permissions: Permission[] };

const PEOPLE_LIMIT = 200;

function moduleOf(permission: Permission): ModuleKey {
  return permission.split('.')[0] as ModuleKey;
}

/** PERMISSIONS tartibida modul bo'yicha guruhlash. */
function groupPermissions(): Group[] {
  const groups: Group[] = [];
  for (const p of PERMISSIONS) {
    const key = moduleOf(p);
    const last = groups.at(-1);
    if (last?.module === key) last.permissions.push(p);
    else groups.push({ module: key, permissions: [p] });
  }
  return groups;
}

function Mark({ granted, label }: { granted: boolean; label: string }) {
  return (
    <span
      className={cn(
        'mx-auto flex h-6 w-6 items-center justify-center rounded-full',
        granted ? 'bg-primary/10 text-primary ring-1 ring-inset ring-primary/20' : 'text-muted-foreground/35',
      )}
      title={label}
      aria-label={label}
      role="img"
    >
      {granted ? <Check className="h-3.5 w-3.5" strokeWidth={3} /> : <Minus className="h-3.5 w-3.5" />}
    </span>
  );
}

export function RolesTab() {
  const { t } = useI18n();
  const roles = useRoles();
  const staff = useStaffList({ limit: PEOPLE_LIMIT, active: true, sortBy: 'name', sortDir: 'asc' });
  const groups = useMemo(groupPermissions, []);
  const byRole = useMemo(() => {
    const map = new Map<RoleKey, StaffRow[]>();
    for (const s of staff.data?.items ?? []) map.set(s.role, [...(map.get(s.role) ?? []), s]);
    return map;
  }, [staff.data]);

  if (roles.isError) {
    return (
      <Card>
        <ErrorState error={roles.error} onRetry={() => void roles.refetch()} />
      </Card>
    );
  }
  if (!roles.data) return <Skeleton className="h-[480px] rounded-2xl" />;

  const list = roles.data;
  return (
    <div className="space-y-6">
      <p className={cn('flex items-start gap-2.5 px-4 py-3 text-sm text-muted-foreground', INNER_TILE)}>
        <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
        {t('staff.roles.intro')}
      </p>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {list.map((role) => (
          <RoleCard key={role.key} role={role} people={staff.data ? (byRole.get(role.key) ?? []) : undefined} />
        ))}
      </div>
      <SectionCard icon={<ShieldCheck />} title={t('staff.roles.matrixTitle')} description={t('staff.roles.matrixHint')} bodyClassName="p-0">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead className="min-w-[240px]">{t('staff.roles.permission')}</TableHead>
              {list.map((role) => (
                <TableHead key={role.key} className="text-center">
                  <span className="inline-flex items-center gap-1.5">
                    <span className={cn('h-1.5 w-1.5 rounded-full', ROLE_DOT[role.key])} aria-hidden />
                    {t(`enums.role.${role.key}`)}
                  </span>
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {groups.map((group) => (
              <Fragment key={group.module}>
                <TableRow className="bg-primary/[0.035] hover:bg-primary/[0.035] dark:bg-white/[0.02] dark:hover:bg-white/[0.02]">
                  <TableCell colSpan={list.length + 1} className="py-2 text-2xs font-semibold uppercase tracking-[0.1em] text-primary">
                    {t(`staff.modules.${group.module}`)}
                  </TableCell>
                </TableRow>
                {group.permissions.map((p) => (
                  <TableRow key={p}>
                    <TableCell className="py-2.5 font-medium">{t(`staff.perm.${p}`)}</TableCell>
                    {list.map((role) => {
                      const granted = role.permissions.includes(p);
                      return (
                        <TableCell key={role.key} className="py-2.5 text-center">
                          <Mark granted={granted} label={t(granted ? 'staff.roles.granted' : 'staff.roles.denied')} />
                        </TableCell>
                      );
                    })}
                  </TableRow>
                ))}
              </Fragment>
            ))}
          </TableBody>
        </Table>
      </SectionCard>
    </div>
  );
}
