'use client';

import { Check, Info, Minus, ShieldCheck } from 'lucide-react';
import { Fragment, useMemo } from 'react';

import { PERMISSIONS, type Permission, type RoleDefinition } from '@/auth/permissions';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { useI18n } from '@/i18n';
import type { staff as staffDict } from '@/i18n/uz/staff';
import { cn } from '@/lib/utils';
import { useRoles, useStaffSummary } from '../hooks';
import { ROLE_VARIANT } from './use-staff-columns';

type ModuleKey = keyof typeof staffDict.modules;
type Group = { module: ModuleKey; permissions: Permission[] };

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

function RoleCard({ role, staffCount }: { role: RoleDefinition; staffCount: number | undefined }) {
  const { t } = useI18n();
  return (
    <Card className="card-glow flex flex-col p-5 animate-slide-up">
      <div className="flex items-start justify-between gap-2">
        <Badge variant={ROLE_VARIANT[role.key]} className="text-sm">
          {t(`enums.role.${role.key}`)}
        </Badge>
        <span className="text-2xs font-semibold uppercase tracking-wide text-muted-foreground">{t(`staff.roles.scope.${role.scope}`)}</span>
      </div>
      <p className="mt-3 flex-1 text-sm leading-relaxed text-muted-foreground">{t(`staff.roles.desc.${role.key}`)}</p>
      <div className="mt-4 flex items-center justify-between border-t pt-3 text-xs">
        <span className="font-semibold">{t('staff.roles.permCount', { count: role.permissions.length })}</span>
        {staffCount !== undefined && <span className="text-muted-foreground">{t('staff.roles.staffCount', { count: staffCount })}</span>}
      </div>
    </Card>
  );
}

function Mark({ granted, label }: { granted: boolean; label: string }) {
  return (
    <span
      className={cn(
        'mx-auto flex h-6 w-6 items-center justify-center rounded-full',
        granted ? 'bg-success/15 text-success' : 'text-muted-foreground/40',
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
  const summary = useStaffSummary();
  const groups = useMemo(groupPermissions, []);

  if (roles.isError) return <ErrorState error={roles.error} onRetry={() => void roles.refetch()} />;
  if (!roles.data) return <Skeleton className="h-[480px] rounded-xl" />;

  const list = roles.data;
  return (
    <div className="space-y-6">
      <p className="flex items-start gap-2 rounded-xl border border-primary/20 bg-primary/5 px-4 py-3 text-sm text-muted-foreground">
        <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
        {t('staff.roles.intro')}
      </p>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {list.map((role) => (
          <RoleCard key={role.key} role={role} staffCount={summary.data?.byRole[role.key]} />
        ))}
      </div>
      <SectionCard
        title={
          <span className="flex items-center gap-2">
            <ShieldCheck className="h-4 w-4 text-primary" />
            {t('staff.roles.matrixTitle')}
          </span>
        }
        description={t('staff.roles.matrixHint')}
        bodyClassName="p-0"
      >
        <Table>
          <TableHeader className="sticky top-0 z-10">
            <TableRow className="hover:bg-transparent">
              <TableHead className="min-w-[240px]">{t('staff.roles.permission')}</TableHead>
              {list.map((role) => (
                <TableHead key={role.key} className="text-center">
                  {t(`enums.role.${role.key}`)}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {groups.map((group) => (
              <Fragment key={group.module}>
                <TableRow className="bg-muted/30 hover:bg-muted/30">
                  <TableCell colSpan={list.length + 1} className="py-2 text-2xs font-semibold uppercase tracking-wider text-primary">
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
