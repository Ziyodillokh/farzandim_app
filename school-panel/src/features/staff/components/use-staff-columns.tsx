'use client';

import { Lock, MoreHorizontal, Pencil, Power, PowerOff } from 'lucide-react';
import { useMemo } from 'react';

import type { Column } from '@/components/common/data-table';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge, type BadgeProps } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { RoleKey } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';

const MAX_CLASS_BADGES = 3;

export const ROLE_VARIANT: Record<RoleKey, NonNullable<BadgeProps['variant']>> = {
  DIRECTOR: 'default',
  ADMIN: 'info',
  HOMEROOM: 'success',
  PSYCHOLOGIST: 'warning',
  DUTY: 'secondary',
  TEACHER: 'outline',
};

export type StaffActions = {
  canManage: boolean;
  selfId: string | null;
  onEdit: (row: StaffRow) => void;
  onToggleActive: (row: StaffRow) => void;
};

function RowMenu({ row, actions }: { row: StaffRow; actions: StaffActions }) {
  const { t } = useI18n();
  const locked = Boolean(row.username) || row.id === actions.selfId;
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-sm" aria-label={t('staff.actions.menu')} onClick={(e) => e.stopPropagation()}>
          <MoreHorizontal />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
        <DropdownMenuItem onClick={() => actions.onEdit(row)}>
          <Pencil className="h-4 w-4" />
          {t('common.edit')}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          disabled={locked}
          onClick={() => actions.onToggleActive(row)}
          className={cn('items-start', row.active && 'text-destructive focus:text-destructive')}
        >
          {locked ? <Lock className="mt-0.5 h-4 w-4" /> : row.active ? <PowerOff className="mt-0.5 h-4 w-4" /> : <Power className="mt-0.5 h-4 w-4" />}
          <span className="grid">
            {row.active ? t('staff.actions.deactivate') : t('staff.actions.activate')}
            {locked && (
              <span className="max-w-[220px] text-2xs font-normal text-muted-foreground">
                {row.username ? t('staff.demoLocked') : t('staff.selfLocked')}
              </span>
            )}
          </span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

export function useStaffColumns(actions: StaffActions): Column<StaffRow>[] {
  const { t } = useI18n();
  return useMemo<Column<StaffRow>[]>(() => {
    const cols: Column<StaffRow>[] = [
      {
        key: 'name',
        header: t('staff.columns.name'),
        sortKey: 'name',
        cell: (r) => (
          <div className={cn('flex items-center gap-3', !r.active && 'opacity-60')}>
            <Avatar className="h-9 w-9">
              <AvatarFallback className="bg-primary/10 text-xs font-semibold text-primary">{initials(r.fullName)}</AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <p className="flex flex-wrap items-center gap-1.5 font-medium">
                <span className="truncate">{r.fullName}</span>
                {r.username && (
                  <Badge variant="warning" size="sm">
                    {t('staff.demoBadge', { username: r.username })}
                  </Badge>
                )}
                {r.id === actions.selfId && <Badge size="sm">{t('staff.youBadge')}</Badge>}
              </p>
              <p className="truncate text-xs text-muted-foreground">{r.position}</p>
            </div>
          </div>
        ),
      },
      { key: 'role', header: t('staff.columns.role'), sortKey: 'role', cell: (r) => <Badge variant={ROLE_VARIANT[r.role]}>{t(`enums.role.${r.role}`)}</Badge> },
      {
        key: 'classes',
        header: t('staff.columns.classes'),
        cell: (r) =>
          r.classNames.length === 0 ? (
            <span className="text-muted-foreground">—</span>
          ) : (
            <div className="flex flex-wrap gap-1">
              {r.classNames.slice(0, MAX_CLASS_BADGES).map((name) => (
                <Badge key={name} variant="outline">
                  {name}
                </Badge>
              ))}
              {r.classNames.length > MAX_CLASS_BADGES && <Badge variant="secondary">+{r.classNames.length - MAX_CLASS_BADGES}</Badge>}
            </div>
          ),
      },
      {
        key: 'contact',
        header: t('staff.columns.contact'),
        cell: (r) => (
          <div className="min-w-0 text-sm">
            <p className="whitespace-nowrap tabular-nums">{r.phone}</p>
            {r.email && <p className="truncate text-xs text-muted-foreground">{r.email}</p>}
          </div>
        ),
      },
      {
        key: 'status',
        header: t('staff.columns.status'),
        cell: (r) => (
          <Badge variant={r.active ? 'success' : 'secondary'}>
            <span className="h-1.5 w-1.5 rounded-full bg-current" aria-hidden />
            {r.active ? t('staff.status.active') : t('staff.status.inactive')}
          </Badge>
        ),
      },
    ];
    if (actions.canManage) {
      cols.push({ key: 'actions', header: '', className: 'w-12 text-right', cell: (r) => <RowMenu row={r} actions={actions} /> });
    }
    return cols;
  }, [t, actions]);
}
