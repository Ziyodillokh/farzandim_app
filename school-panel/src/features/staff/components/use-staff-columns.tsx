'use client';

import { KeyRound, Lock, MoreHorizontal, Pencil, Power, PowerOff, ShieldCheck, UserX } from 'lucide-react';
import { useMemo } from 'react';

import type { Column } from '@/components/common/data-table';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { StaffRow } from '@/data/mock/services/staff';
import { isHttpMode } from '@/data/source';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { accountMenu } from '../account';
import { RoleBadge } from './role-badge';

const MAX_CLASS_BADGES = 3;


export type StaffActions = {
  canManage: boolean;
  selfId: string | null;
  onEdit: (row: StaffRow) => void;
  onToggleActive: (row: StaffRow) => void;
  onAccount: (row: StaffRow) => void;
  onRemoveAccount: (row: StaffRow) => void;
};

function RowMenu({ row, actions }: { row: StaffRow; actions: StaffActions }) {
  const { t } = useI18n();
  // Demo hisoblar qat'iy; haqiqiy rejimda faqat o'zini faolsizlantirib bo'lmaydi.
  const self = row.id === actions.selfId;
  const locked = isHttpMode ? self : Boolean(row.username) || self;
  // O'z qatorida: panel hisobi nofaol (izoh bilan), o'chirish yo'q — o'z paroli "Profilim" oynasida.
  const account = accountMenu(row, actions.selfId);
  const AccountIcon = account.note === 'protected' ? ShieldCheck : account.note === 'self' ? Lock : KeyRound;
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
        {isHttpMode && (
          <>
            <DropdownMenuItem disabled={!account.canSet} onClick={() => actions.onAccount(row)} className="items-start">
              <AccountIcon className="mt-0.5 h-4 w-4" />
              <span className="grid">
                {t('staff.account.action')}
                {account.note && (
                  <span className="max-w-[220px] text-2xs font-normal text-muted-foreground">
                    {t(account.note === 'self' ? 'staff.account.selfHint' : 'staff.account.protected')}
                  </span>
                )}
              </span>
            </DropdownMenuItem>
            {account.canRemove && (
              <DropdownMenuItem className="text-destructive focus:text-destructive" onClick={() => actions.onRemoveAccount(row)}>
                <UserX className="h-4 w-4" />
                {t('staff.account.remove')}
              </DropdownMenuItem>
            )}
          </>
        )}
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
                {self ? t('staff.selfLocked') : t('staff.demoLocked')}
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
          <div className={cn('flex items-center gap-3', !r.active && 'opacity-60 grayscale')}>
            <StaffAvatar name={r.fullName} photo={r.photo ?? null} portrait={r.portrait ?? null} size="sm" />
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-1.5 font-medium">
                <span className="truncate">{r.fullName}</span>
                {r.username && (
                  <Badge variant="info" size="sm">
                    {t(isHttpMode ? 'staff.loginBadge' : 'staff.demoBadge', { username: r.username })}
                  </Badge>
                )}
                {r.id === actions.selfId && <Badge size="sm">{t('staff.youBadge')}</Badge>}
              </div>
              <p className="truncate text-xs text-muted-foreground">{r.position}</p>
            </div>
          </div>
        ),
      },
      { key: 'role', header: t('staff.columns.role'), sortKey: 'role', cell: (r) => <RoleBadge role={r.role} /> },
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
